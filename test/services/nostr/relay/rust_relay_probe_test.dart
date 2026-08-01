@Tags(['rust'])
library;

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/settings/providers/relay_config_provider.dart';
import 'package:choke/services/nostr/relay/rust_relay_backend.dart';
import 'package:choke/src/rust/frb_generated.dart';

import '../../../support/relay_fakes.dart';

/// The connectivity probe Settings runs before saving a relay URL.
///
/// The handshake lives in the Rust crate (`relay_probe`), so these are the
/// socket-level tests that used to sit next to RelayConfigNotifier when the
/// probe was a Dart WebSocket. Same cases, same loopback-only rule: nothing
/// here leaves the machine. The Rust crate's own tests cover the failure
/// paths too; what only this side can supply is a live WebSocket endpoint.
void main() {
  final libraryPath = _findNativeLibrary();
  if (libraryPath == null) {
    group('relay probe', skip: 'native library not built', () {
      test('needs cargo build --manifest-path rust/Cargo.toml', () {});
    });
    return;
  }

  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(libraryPath));
  });

  group('RustRelayBackend.probe', () {
    test('succeeds against a live local WebSocket endpoint', () async {
      // Arrange — a WebSocket server on 127.0.0.1; the probe does not care
      // about the scheme, only the notifier's validator does, so ws:// keeps
      // TLS out of the test.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        sockets.add(ws);
        ws.listen((_) {});
      });
      addTearDown(() async {
        for (final ws in sockets) {
          await ws.close();
        }
        await server.close(force: true);
      });

      // Act
      final reachable = await RustRelayBackend.probe(
        'ws://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 5),
      );

      // Assert
      expect(reachable, isTrue);
    });

    test('returns false when the URL cannot even be parsed', () async {
      // Act — unterminated IPv6 literal: rejected before any socket exists
      final reachable = await RustRelayBackend.probe(
        'ws://[::1',
        timeout: const Duration(seconds: 5),
      );

      // Assert
      expect(reachable, isFalse);
    });

    test('reports a refused connection as unreachable, promptly', () async {
      // Arrange — port 1 on loopback: privileged, nothing listens there.
      // Regression guard inherited from the Dart-era probe: this path used to
      // hang forever behind the "Adding…" spinner. The probe must return
      // false on its own; if a hang comes back, the test-level timeout fails.
      final reachable = await RustRelayBackend.probe(
        'ws://127.0.0.1:1',
        timeout: const Duration(seconds: 5),
      );

      // Assert
      expect(reachable, isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('times out against a socket that never completes the handshake',
        () async {
      // Arrange — a TCP listener nobody accepts from: the kernel completes
      // the TCP handshake out of the backlog and the WebSocket upgrade is
      // never answered, so the probe's own timeout is the only way out. A
      // short timeout keeps the test cheap; the production value is the
      // notifier's business, not the probe's.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add);
      addTearDown(() async {
        for (final socket in held) {
          socket.destroy();
        }
        await server.close();
      });

      // Act
      final reachable = await RustRelayBackend.probe(
        'ws://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 2),
      );

      // Assert
      expect(reachable, isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('RelayConfigNotifier.testRelayConnectivity', () {
    test('reaches the Rust probe end to end', () async {
      // Arrange — the notifier's seam, unfaked: the same call addRelay makes
      // must land in the crate and come back true against a live endpoint.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        sockets.add(ws);
        ws.listen((_) {});
      });
      addTearDown(() async {
        for (final ws in sockets) {
          await ws.close();
        }
        await server.close(force: true);
      });
      final notifier = RelayConfigNotifier(
          RelayConfigService(secureStorage: InMemorySecureStorage()));
      await pumpEventQueue();

      // Act
      final reachable =
          await notifier.testRelayConnectivity('ws://127.0.0.1:${server.port}');

      // Assert
      expect(reachable, isTrue);
    });
  });
}

String? _findNativeLibrary() {
  final name = Platform.isMacOS
      ? 'librust_lib_choke.dylib'
      : Platform.isWindows
          ? 'rust_lib_choke.dll'
          : 'librust_lib_choke.so';

  for (final profile in ['debug', 'release']) {
    final path = 'rust/target/$profile/$name';
    if (File(path).existsSync()) return path;
  }
  return null;
}
