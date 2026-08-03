import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import 'package:choke/shared/widgets/qr_dialog.dart';

/// The link under a QR code is there because codes fail to scan — bad light, an
/// angle, cracked glass. Reading it out loud is the fallback, and copying it is
/// the other half of the same idea: the two ways to move a link off a screen
/// when the camera will not.
void main() {
  const url = 'https://bjjscore.live/?npub=npub1fake';

  late AppLocalizations l10n;

  /// Capture every Clipboard.setData the dialog makes.
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

  /// The dialog on screen, over a Scaffold so a SnackBar has somewhere to go.
  Future<void> pumpDialog(WidgetTester tester, {String? copyLabel}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: Builder(
                builder: (inner) => ElevatedButton(
                  onPressed: () => showQrDialog(
                    inner,
                    title: 'Scan to watch live',
                    data: url,
                    caption: 'Point a camera at this',
                    copyLabel: copyLabel,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the link under the code', () {
    testWidgets('copies what the code encodes when tapped', (tester) async {
      // Arrange
      final copied = mockClipboard(tester);
      await pumpDialog(tester, copyLabel: 'Link');

      // Act
      await tester.tap(find.text(url));
      await tester.pumpAndSettle();

      // Assert — the same string the QR carries, not a re-derived one
      expect(copied, [url]);
    });

    testWidgets(
        'says so, because a silent copy is indistinguishable from a tap that '
        'did nothing', (tester) async {
      // Arrange
      mockClipboard(tester);
      await pumpDialog(tester, copyLabel: 'Link');

      // Act
      await tester.tap(find.text(url));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(l10n.copiedToClipboard('Link')), findsOneWidget);
    });

    testWidgets('stays put when the dialog did not ask to be copyable',
        (tester) async {
      // Arrange — the account screen's QR carries a public key and offers its
      // own copy control; a second, invisible one under the code is not it
      final copied = mockClipboard(tester);
      await pumpDialog(tester);

      // Act
      await tester.tap(find.text(url));
      await tester.pumpAndSettle();

      // Assert — nothing copied, and the link is still just text
      expect(copied, isEmpty);
      expect(find.text(url), findsOneWidget);
    });

    testWidgets('leaves the dialog open, so the code can still be scanned',
        (tester) async {
      // Arrange — copying a link is not finishing with the dialog: the person
      // across the room is still pointing a camera at it
      mockClipboard(tester);
      await pumpDialog(tester, copyLabel: 'Link');

      // Act
      await tester.tap(find.text(url));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(QrDialog), findsOneWidget);
    });
  });
}
