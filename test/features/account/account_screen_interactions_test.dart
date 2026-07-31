import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:choke/features/account/account_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/services/deep_links/share_link.dart';
import 'package:choke/services/key_management/key_manager.dart';

import '../../support/nostr_fakes.dart';
import '../../support/share_channel.dart';

const _npub = 'npub1testpublickey';
const _nsec = 'nsec1testprivatekey';

/// A KeyManager whose answers a test can script, never touching secure
/// storage or real crypto.
class _StubKeyManager extends KeyManager {
  _StubKeyManager() : super(crypto: FakeNostrCrypto());

  String? npub = _npub;
  String? nsec = _nsec;

  /// When set, key lookups await this, holding the screen in its loading
  /// state until a test releases it.
  Completer<void>? loadGate;
  Object? npubError;
  Object? nsecError;
  bool importResult = true;
  final importedNsecs = <String>[];
  bool generateThrows = false;
  int generateCalls = 0;

  @override
  Future<String?> getNpub() async {
    await loadGate?.future;
    final error = npubError;
    if (error != null) throw error;
    return npub;
  }

  @override
  Future<String?> getNsec() async {
    await loadGate?.future;
    final error = nsecError;
    if (error != null) throw error;
    return nsec;
  }

  @override
  Future<bool> importFromNsec(String nsec) async {
    importedNsecs.add(nsec);
    return importResult;
  }

  @override
  Future<void> generateNewKeypair() async {
    generateCalls++;
    if (generateThrows) throw Exception('keystore unavailable');
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpAccountScreen(
    WidgetTester tester,
    _StubKeyManager keyManager, {
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyManagerProvider.overrideWithValue(keyManager),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: AccountScreen(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  /// Capture every Clipboard.setData call the screen makes.
  List<String> mockClipboard(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    return copied;
  }

  test('liveBoardShareUrl carries the npub in the query string', () {
    // Act
    final url = liveBoardShareUrl(_npub);

    // Assert — must match the reader in choke-scoreboard
    expect(url, 'https://bjjscore.live/?npub=$_npub');
  });

  group('npub section', () {
    testWidgets('shows the npub and copies it to the clipboard',
        (tester) async {
      // Arrange
      final copied = mockClipboard(tester);
      await pumpAccountScreen(tester, _StubKeyManager());
      expect(find.text(_npub), findsOneWidget);

      // Act
      await tester.tap(find.text(l10n.copy));
      await tester.pumpAndSettle();

      // Assert — the exact npub went to the clipboard, and the user was told
      expect(copied, [_npub]);
      expect(
        find.text(l10n.copiedToClipboard(l10n.publicKey)),
        findsOneWidget,
      );
    });

    testWidgets('shows a placeholder when no key is available yet',
        (tester) async {
      // Arrange — a key manager with nothing stored
      final keyManager = _StubKeyManager()
        ..npub = null
        ..nsec = null;

      // Act
      await pumpAccountScreen(tester, keyManager);

      // Assert — no copy/QR/share affordances for a key that does not exist
      expect(find.text(l10n.keyUnavailable), findsOneWidget);
      expect(find.text(l10n.copy), findsNothing);
    });

    testWidgets('reports an error when the key cannot be loaded',
        (tester) async {
      // Arrange
      final keyManager = _StubKeyManager()
        ..npubError = Exception('keystore locked');

      // Act
      await pumpAccountScreen(tester, keyManager);

      // Assert
      expect(find.text(l10n.errorLoadingKey), findsOneWidget);
    });

    testWidgets('shows progress while keys are still loading', (tester) async {
      // Arrange — hold the key lookups open so the loading state is visible
      final keyManager = _StubKeyManager()..loadGate = Completer<void>();

      // Act — first frames only: the key futures are still pending
      await pumpAccountScreen(tester, keyManager, settle: false);
      await tester.pump();

      // Assert — both the npub and nsec sections show a spinner
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      // Release the gate and let the identity land
      keyManager.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(_npub), findsOneWidget);
    });
  });

  group('QR dialog', () {
    testWidgets('renders the npub as a QR code with the raw text under it',
        (tester) async {
      // Arrange
      await pumpAccountScreen(tester, _StubKeyManager());

      // Act
      await tester.tap(find.text(l10n.showQr));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.yourPublicKey), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(l10n.scanQrToShare), findsOneWidget);
      // The npub appears twice now: on the screen and inside the dialog
      expect(find.text(_npub), findsNWidgets(2));

      // Act — close it
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(QrImageView), findsNothing);
    });
  });

  group('share live board', () {
    testWidgets('opens the share sheet with the live board link',
        (tester) async {
      // Arrange
      final calls = mockShareChannel(tester);
      await pumpAccountScreen(tester, _StubKeyManager());

      // Act
      await tester.tap(find.text(l10n.shareLiveBoard));
      await tester.pumpAndSettle();

      // Assert — the shared text carries the spectator link, not the raw key
      expect(calls, hasLength(1));
      final sharedText = calls.single['text'] as String;
      expect(sharedText, contains(liveBoardShareUrl(_npub)));
      expect(sharedText, contains(l10n.shareLiveBoardMessage));
    });

    testWidgets('surfaces a share sheet failure instead of crashing',
        (tester) async {
      // Arrange — the platform has no handler for the share intent
      mockShareChannel(tester, fail: true);
      await pumpAccountScreen(tester, _StubKeyManager());

      // Act
      await tester.tap(find.text(l10n.shareLiveBoard));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.shareFailed), findsOneWidget);
    });
  });

  group('nsec section', () {
    testWidgets('hides the nsec until tapped, then reveals and copies it',
        (tester) async {
      // Arrange
      final copied = mockClipboard(tester);
      await pumpAccountScreen(tester, _StubKeyManager());

      // Assert — masked at rest, with no copy affordance
      expect(find.text(_nsec), findsNothing);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.text(l10n.copyToClipboard), findsNothing);

      // Act — reveal
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      // Assert — visible, with the eye now offering to hide it again
      expect(find.text(_nsec), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Act — copy it
      await tester.tap(find.text(l10n.copyToClipboard));
      await tester.pumpAndSettle();

      // Assert
      expect(copied, [_nsec]);
      expect(
        find.text(l10n.copiedToClipboard(l10n.privateKey)),
        findsOneWidget,
      );

      // Act — hide it again
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(find.text(_nsec), findsNothing);
    });

    testWidgets('reports an error when the nsec cannot be loaded',
        (tester) async {
      // Arrange
      final keyManager = _StubKeyManager()
        ..nsecError = Exception('keystore locked');

      // Act
      await pumpAccountScreen(tester, keyManager);

      // Assert
      expect(find.text(l10n.errorLoadingKey), findsOneWidget);
    });
  });

  group('import dialog', () {
    Future<void> openImportDialog(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(find.text(l10n.importPrivateKey), findsOneWidget);
    }

    testWidgets('rejects an empty nsec', (tester) async {
      // Arrange
      final keyManager = _StubKeyManager();
      await pumpAccountScreen(tester, keyManager);
      await openImportDialog(tester);

      // Act — import with nothing typed
      await tester.tap(find.text(l10n.import));
      await tester.pumpAndSettle();

      // Assert — validation stops it before the key manager is asked
      expect(find.text(l10n.pleaseEnterNsec), findsOneWidget);
      expect(keyManager.importedNsecs, isEmpty);
    });

    testWidgets('rejects input that is not an nsec', (tester) async {
      // Arrange
      final keyManager = _StubKeyManager();
      await pumpAccountScreen(tester, keyManager);
      await openImportDialog(tester);

      // Act — an npub pasted by mistake
      await tester.enterText(find.byType(TextField), 'npub1notasecret');
      await tester.tap(find.text(l10n.import));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.invalidNsecFormat), findsOneWidget);
      expect(keyManager.importedNsecs, isEmpty);
    });

    testWidgets('reports a failed import and keeps the dialog open',
        (tester) async {
      // Arrange — a well-formed nsec the key manager cannot decode
      final keyManager = _StubKeyManager()..importResult = false;
      await pumpAccountScreen(tester, keyManager);
      await openImportDialog(tester);

      // Act
      await tester.enterText(find.byType(TextField), 'nsec1badchecksum');
      await tester.tap(find.text(l10n.import));
      await tester.pumpAndSettle();

      // Assert — the user can correct the input rather than starting over
      expect(keyManager.importedNsecs, ['nsec1badchecksum']);
      expect(find.text(l10n.failedToImportKey), findsOneWidget);
      expect(find.text(l10n.importPrivateKey), findsOneWidget);
    });

    testWidgets('imports a valid nsec, closes the dialog and confirms',
        (tester) async {
      // Arrange
      final keyManager = _StubKeyManager();
      await pumpAccountScreen(tester, keyManager);
      await openImportDialog(tester);

      // Act
      await tester.enterText(find.byType(TextField), ' nsec1valid ');
      await tester.tap(find.text(l10n.import));
      await tester.pumpAndSettle();

      // Assert — whitespace trimmed, dialog gone, success reported
      expect(keyManager.importedNsecs, ['nsec1valid']);
      expect(find.text(l10n.importPrivateKey), findsNothing);
      expect(find.text(l10n.keyImportedSuccessfully), findsOneWidget);
    });

    testWidgets('cancel closes the dialog without importing', (tester) async {
      // Arrange
      final keyManager = _StubKeyManager();
      await pumpAccountScreen(tester, keyManager);
      await openImportDialog(tester);
      await tester.enterText(find.byType(TextField), 'nsec1typed');

      // Act
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.importPrivateKey), findsNothing);
      expect(keyManager.importedNsecs, isEmpty);
    });
  });

  group('generate key dialog', () {
    testWidgets('reports a generation failure and lets the user retry',
        (tester) async {
      // Arrange — the keystore refuses to store a new keypair
      final keyManager = _StubKeyManager()..generateThrows = true;
      await pumpAccountScreen(tester, keyManager);
      await tester.tap(find.byIcon(Icons.autorenew));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text(l10n.generate));
      await tester.pumpAndSettle();

      // Assert — failure surfaced, dialog still open for a retry
      expect(keyManager.generateCalls, 1);
      expect(find.text(l10n.failedToGenerateKey), findsOneWidget);
      expect(find.text(l10n.generateNewKeyTitle), findsOneWidget);
    });
  });
}
