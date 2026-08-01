import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/settings/providers/relay_config_provider.dart';

import '../../../support/relay_fakes.dart';

void main() {
  group('RelayConfig model', () {
    test('copyWith replaces only the given fields', () {
      // Arrange
      const relay = RelayConfig(url: 'wss://a', isEnabled: true);

      // Act
      final copy = relay.copyWith(isConnected: true);
      final renamed = relay.copyWith(url: 'wss://b', isEnabled: false);

      // Assert — untouched fields survive the copy
      expect(copy.url, 'wss://a');
      expect(copy.isEnabled, isTrue);
      expect(copy.isConnected, isTrue);
      expect(renamed.url, 'wss://b');
      expect(renamed.isEnabled, isFalse);
    });

    test('round-trips through JSON, defaulting isEnabled to true', () {
      // Arrange
      const relay = RelayConfig(url: 'wss://a', isEnabled: false);

      // Act
      final json = relay.toJson();
      final back = RelayConfig.fromJson(json);
      // isConnected is runtime state and must not be persisted
      final legacy = RelayConfig.fromJson({'url': 'wss://old'});

      // Assert
      expect(json, {'url': 'wss://a', 'isEnabled': false});
      expect(back.url, 'wss://a');
      expect(back.isEnabled, isFalse);
      expect(back.isConnected, isFalse);
      expect(legacy.isEnabled, isTrue,
          reason: 'a saved entry without the flag means enabled');
    });
  });

  group('RelayConfigService', () {
    late InMemorySecureStorage storage;
    late RelayConfigService service;

    setUp(() {
      storage = InMemorySecureStorage();
      service = RelayConfigService(secureStorage: storage);
    });

    test('returns the default relays when nothing is stored', () async {
      // Arrange — empty storage from setUp

      // Act
      final relays = await service.loadRelays();

      // Assert
      expect(relays.map((r) => r.url), RelayConfigService.defaultRelays);
      expect(relays.every((r) => r.isEnabled), isTrue);
    });

    test('returns the default relays when the stored value is empty', () async {
      // Arrange
      storage.store['nostr_relays'] = '';

      // Act
      final relays = await service.loadRelays();

      // Assert
      expect(relays.map((r) => r.url), RelayConfigService.defaultRelays);
    });

    test('loads previously saved relays', () async {
      // Arrange
      storage.store['nostr_relays'] = jsonEncode([
        {'url': 'wss://custom.example', 'isEnabled': false},
      ]);

      // Act
      final relays = await service.loadRelays();

      // Assert
      expect(relays, hasLength(1));
      expect(relays.single.url, 'wss://custom.example');
      expect(relays.single.isEnabled, isFalse);
    });

    test('falls back to defaults when the stored JSON is corrupt', () async {
      // Arrange — a half-written or hand-edited value must not brick the app
      storage.store['nostr_relays'] = '{not json';

      // Act
      final relays = await service.loadRelays();

      // Assert
      expect(relays.map((r) => r.url), RelayConfigService.defaultRelays);
    });

    test('falls back to defaults when storage read throws', () async {
      // Arrange
      storage.throwOnRead = true;

      // Act
      final relays = await service.loadRelays();

      // Assert
      expect(relays.map((r) => r.url), RelayConfigService.defaultRelays);
    });

    test('saveRelays persists the list as JSON', () async {
      // Arrange
      const relays = [
        RelayConfig(url: 'wss://a'),
        RelayConfig(url: 'wss://b', isEnabled: false),
      ];

      // Act
      await service.saveRelays(relays);

      // Assert — what the next launch will read back
      final decoded = jsonDecode(storage.store['nostr_relays']!) as List;
      expect(decoded, [
        {'url': 'wss://a', 'isEnabled': true},
        {'url': 'wss://b', 'isEnabled': false},
      ]);
    });

    test('saveRelays surfaces a storage failure as an exception', () async {
      // Arrange
      storage.throwOnWrite = true;

      // Act + Assert — callers rely on the throw to roll their state back
      expect(
        () => service.saveRelays(const [RelayConfig(url: 'wss://a')]),
        throwsException,
      );
    });

    test('resetToDefaults saves and returns the default set', () async {
      // Arrange
      storage.store['nostr_relays'] =
          jsonEncode([RelayConfig(url: 'wss://other').toJson()]);

      // Act
      final defaults = await service.resetToDefaults();

      // Assert
      expect(defaults.map((r) => r.url), RelayConfigService.defaultRelays);
      final persisted = jsonDecode(storage.store['nostr_relays']!) as List;
      expect(persisted, hasLength(RelayConfigService.defaultRelays.length));
    });
  });

  group('RelayConfigState', () {
    test('copyWith keeps the existing error unless one is passed', () {
      // Arrange — the sentinel default means "no change", not "clear"
      const state = RelayConfigState(error: RelayError.addFailed);

      // Act
      final untouched = state.copyWith(isLoading: true);
      final cleared = state.copyWith(error: null);
      final replaced = state.copyWith(error: RelayError.invalidUrl);

      // Assert
      expect(untouched.error, RelayError.addFailed);
      expect(cleared.error, isNull);
      expect(replaced.error, RelayError.invalidUrl);
    });

    test('exposes enabled relays and duplicate detection', () {
      // Arrange
      const state = RelayConfigState(relays: [
        RelayConfig(url: 'wss://a', isEnabled: true),
        RelayConfig(url: 'wss://b', isEnabled: false),
      ]);

      // Act + Assert
      expect(state.enabledRelays.map((r) => r.url), ['wss://a']);
      expect(state.hasEnabledRelay, isTrue);
      // containsUrl normalizes case and whitespace before comparing
      expect(state.containsUrl('  WSS://A '), isTrue);
      expect(state.containsUrl('wss://c'), isFalse);
    });

    test('reports no enabled relay when every relay is disabled', () {
      // Arrange
      const state = RelayConfigState(
        relays: [RelayConfig(url: 'wss://a', isEnabled: false)],
      );

      // Act + Assert
      expect(state.hasEnabledRelay, isFalse);
      expect(state.enabledRelays, isEmpty);
    });
  });

  group('RelayConfigNotifier', () {
    late InMemorySecureStorage storage;
    late RelayConfigService service;
    late TestableRelayConfigNotifier notifier;

    /// Builds a notifier over in-memory storage and waits for its async
    /// initialize to finish, so tests start from a settled state.
    Future<void> build(
        {List<RelayConfig>? initial, bool reachable = true}) async {
      storage = InMemorySecureStorage();
      if (initial != null) {
        storage.store['nostr_relays'] =
            jsonEncode(initial.map((r) => r.toJson()).toList());
      }
      service = RelayConfigService(secureStorage: storage);
      notifier = TestableRelayConfigNotifier(service, reachable: reachable);
      await pumpEventQueue();
    }

    test('initializes with the loaded relays', () async {
      // Arrange + Act
      await build();

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.relays.map((r) => r.url),
          RelayConfigService.defaultRelays);
      expect(notifier.state.error, isNull);
    });

    test('reports loadFailed when the service itself throws', () async {
      // Arrange + Act — the real service swallows storage errors, so only a
      // throwing service reaches this branch
      final failing = RelayConfigNotifier(ThrowingLoadRelayConfigService());
      await pumpEventQueue();

      // Assert
      expect(failing.state.isLoading, isFalse);
      expect(failing.state.error, RelayError.loadFailed);
    });

    test('refresh reloads what is on disk', () async {
      // Arrange — storage changes behind the notifier's back
      await build();
      storage.store['nostr_relays'] =
          jsonEncode([RelayConfig(url: 'wss://fresh').toJson()]);

      // Act
      await notifier.refresh();

      // Assert
      expect(notifier.state.relays.single.url, 'wss://fresh');
    });

    group('addRelay', () {
      test('rejects a URL that is not wss://', () async {
        // Arrange
        await build();

        // Act
        final added = await notifier.addRelay('ws://insecure.example');

        // Assert — refused before any connectivity probe
        expect(added, isFalse);
        expect(notifier.state.error, RelayError.invalidUrl);
        expect(notifier.connectivityChecks, 0);
      });

      test('rejects a duplicate URL regardless of surrounding whitespace',
          () async {
        // Arrange — the scheme check is case-sensitive (wss:// only), so the
        // duplicate probe varies whitespace, which containsUrl does normalize
        await build();

        // Act
        final added = await notifier.addRelay('  wss://relay.primal.net ');

        // Assert
        expect(added, isFalse);
        expect(notifier.state.error, RelayError.alreadyExists);
        expect(notifier.connectivityChecks, 0);
      });

      test('rejects an unreachable relay without persisting it', () async {
        // Arrange
        await build(reachable: false);
        final before = notifier.state.relays.length;

        // Act
        final added = await notifier.addRelay('wss://dead.example');

        // Assert
        expect(added, isFalse);
        expect(notifier.state.error, RelayError.unreachable);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.relays, hasLength(before));
      });

      test('adds a reachable relay and persists the new list', () async {
        // Arrange
        await build();

        // Act
        final added = await notifier.addRelay('wss://new.example');

        // Assert
        expect(added, isTrue);
        expect(notifier.state.relays.map((r) => r.url),
            contains('wss://new.example'));
        expect(notifier.state.error, isNull);
        final persisted = jsonDecode(storage.store['nostr_relays']!) as List;
        expect(persisted, hasLength(3));
      });

      test('reports addFailed when saving throws', () async {
        // Arrange
        await build();
        storage.throwOnWrite = true;

        // Act
        final added = await notifier.addRelay('wss://new.example');

        // Assert — state rolls back to not-loading with an error, list intact
        expect(added, isFalse);
        expect(notifier.state.error, RelayError.addFailed);
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.relays, hasLength(2));
      });
    });

    group('removeRelay', () {
      test('returns false for a URL that is not configured', () async {
        // Arrange
        await build();

        // Act
        final removed = await notifier.removeRelay('wss://ghost.example');

        // Assert
        expect(removed, isFalse);
        expect(notifier.state.relays, hasLength(2));
      });

      test('refuses to remove the last enabled relay', () async {
        // Arrange — one enabled, one disabled: the enabled one is untouchable
        await build(initial: const [
          RelayConfig(url: 'wss://only.example', isEnabled: true),
          RelayConfig(url: 'wss://off.example', isEnabled: false),
        ]);

        // Act
        final removed = await notifier.removeRelay('wss://only.example');

        // Assert
        expect(removed, isFalse);
        expect(notifier.state.error, RelayError.cannotRemoveLast);
        expect(notifier.state.relays, hasLength(2));
      });

      test('removes a relay and persists the shorter list', () async {
        // Arrange
        await build();

        // Act
        final removed = await notifier.removeRelay('wss://nos.lol');

        // Assert
        expect(removed, isTrue);
        expect(notifier.state.relays.map((r) => r.url),
            isNot(contains('wss://nos.lol')));
        final persisted = jsonDecode(storage.store['nostr_relays']!) as List;
        expect(persisted, hasLength(1));
      });

      test('a disabled relay can be removed even when it is the only spare',
          () async {
        // Arrange
        await build(initial: const [
          RelayConfig(url: 'wss://on.example', isEnabled: true),
          RelayConfig(url: 'wss://off.example', isEnabled: false),
        ]);

        // Act
        final removed = await notifier.removeRelay('wss://off.example');

        // Assert
        expect(removed, isTrue);
        expect(notifier.state.relays.single.url, 'wss://on.example');
      });

      test('reports removeFailed when saving throws', () async {
        // Arrange
        await build();
        storage.throwOnWrite = true;

        // Act
        final removed = await notifier.removeRelay('wss://nos.lol');

        // Assert
        expect(removed, isFalse);
        expect(notifier.state.error, RelayError.removeFailed);
        expect(notifier.state.relays, hasLength(2));
      });
    });

    group('toggleRelay', () {
      test('returns false for a URL that is not configured', () async {
        // Arrange
        await build();

        // Act
        final toggled = await notifier.toggleRelay('wss://ghost.example');

        // Assert
        expect(toggled, isFalse);
      });

      test('refuses to disable the last enabled relay', () async {
        // Arrange
        await build(initial: const [
          RelayConfig(url: 'wss://only.example', isEnabled: true),
        ]);

        // Act
        final toggled = await notifier.toggleRelay('wss://only.example');

        // Assert
        expect(toggled, isFalse);
        expect(notifier.state.error, RelayError.cannotDisableLast);
        expect(notifier.state.relays.single.isEnabled, isTrue);
      });

      test('disables one of several enabled relays and persists it', () async {
        // Arrange
        await build();

        // Act
        final toggled = await notifier.toggleRelay('wss://nos.lol');

        // Assert
        expect(toggled, isTrue);
        final nosLol =
            notifier.state.relays.firstWhere((r) => r.url == 'wss://nos.lol');
        expect(nosLol.isEnabled, isFalse);
        final persisted = (jsonDecode(storage.store['nostr_relays']!) as List)
            .cast<Map<String, dynamic>>();
        expect(
          persisted.firstWhere((r) => r['url'] == 'wss://nos.lol')['isEnabled'],
          isFalse,
        );
      });

      test('re-enables a disabled relay', () async {
        // Arrange
        await build(initial: const [
          RelayConfig(url: 'wss://on.example', isEnabled: true),
          RelayConfig(url: 'wss://off.example', isEnabled: false),
        ]);

        // Act
        final toggled = await notifier.toggleRelay('wss://off.example');

        // Assert
        expect(toggled, isTrue);
        expect(notifier.state.relays.every((r) => r.isEnabled), isTrue);
      });

      test('reports toggleFailed when saving throws', () async {
        // Arrange
        await build();
        storage.throwOnWrite = true;

        // Act
        final toggled = await notifier.toggleRelay('wss://nos.lol');

        // Assert
        expect(toggled, isFalse);
        expect(notifier.state.error, RelayError.toggleFailed);
      });
    });

    group('updateConnectionStatus', () {
      test('flips the flag for a known relay', () async {
        // Arrange
        await build();

        // Act
        notifier.updateConnectionStatus('WSS://NOS.LOL', true);

        // Assert — matching is case-insensitive, like every other lookup
        final nosLol =
            notifier.state.relays.firstWhere((r) => r.url == 'wss://nos.lol');
        expect(nosLol.isConnected, isTrue);
      });

      test('ignores a relay it does not know', () async {
        // Arrange
        await build();
        final before = notifier.state;

        // Act
        notifier.updateConnectionStatus('wss://ghost.example', true);

        // Assert
        expect(notifier.state, same(before));
      });
    });

    test('clearError wipes the error and nothing else', () async {
      // Arrange
      await build();
      await notifier.addRelay('not-a-url');
      expect(notifier.state.error, RelayError.invalidUrl);

      // Act
      notifier.clearError();

      // Assert
      expect(notifier.state.error, isNull);
      expect(notifier.state.relays, hasLength(2));
    });
  });

  // The real connectivity probe lives in the Rust crate now (`relay_probe`,
  // reached through RustRelayBackend.probe) and needs the native library, so
  // its socket-level tests — live endpoint, garbage URL, refused port, silent
  // socket — live in test/services/nostr/relay/rust_relay_probe_test.dart,
  // tagged 'rust'. What stays here is everything above the seam: addRelay
  // consults testRelayConnectivity, and the fakes override it.

  group('a probe that cannot run', () {
    // This file never calls `RustLib.init`, so the binding underneath the
    // probe is not loaded — which is exactly the shape of every way the call
    // itself can fail, a panic out of the crate included. No native library
    // needed to test it, and none wanted: the point is what happens when the
    // crate is not reachable.

    test('reports unreachable instead of throwing', () async {
      // Arrange
      final notifier = RelayConfigNotifier(
        RelayConfigService(secureStorage: InMemorySecureStorage()),
      );
      await pumpEventQueue();

      // Act + Assert — the caller awaits this outside its own try, so an
      // escaping exception would strand the sheet on "Adding…"
      await expectLater(
        notifier.testRelayConnectivity('wss://relay.example'),
        completion(isFalse),
      );
    });

    test('leaves addRelay saying unreachable, not spinning', () async {
      // Arrange
      final storage = InMemorySecureStorage();
      final notifier = RelayConfigNotifier(
        RelayConfigService(secureStorage: storage),
      );
      await pumpEventQueue();
      final before = storage.writeCount;

      // Act
      final added = await notifier.addRelay('wss://relay.example');

      // Assert — refused, said so, and finished: isLoading back to false is
      // the whole regression this guards
      expect(added, isFalse);
      expect(notifier.state.error, RelayError.unreachable);
      expect(notifier.state.isLoading, isFalse);
      expect(storage.writeCount, before);
    });
  });

  group('providers', () {
    test('relayConfigServiceProvider builds a service', () {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Act + Assert
      expect(container.read(relayConfigServiceProvider),
          isA<RelayConfigService>());
    });

    test('relayConfigProvider wires the notifier to the service', () async {
      // Arrange — the real service's secure-storage plugin is missing on the
      // test host; loadRelays swallows that and falls back to defaults, so
      // reading the provider is still hermetic
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Act
      final state = container.read(relayConfigProvider);
      await pumpEventQueue();

      // Assert
      expect(state.isLoading, isTrue, reason: 'initial state is loading');
      expect(container.read(relayConfigProvider).relays.map((r) => r.url),
          RelayConfigService.defaultRelays);
    });
  });
}
