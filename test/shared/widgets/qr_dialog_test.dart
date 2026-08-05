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
  Future<void> pumpDialog(
    WidgetTester tester, {
    String? copyLabel,
    ({String label, VoidCallback onTap})? share,
  }) async {
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
                    share: share,
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

  /// A code reaches the room; the share sheet reaches everyone who is not in
  /// it. Both are ways off this screen, so both live next to the link.
  group('the share control', () {
    testWidgets('hands the caller the tap, rather than acting on its own',
        (tester) async {
      // Arrange — the dialog knows nothing about what sharing a link means;
      // each screen owns its own message, subject and log tag
      var taps = 0;
      await pumpDialog(
        tester,
        copyLabel: 'Link',
        share: (label: 'Share live board', onTap: () => taps++),
      );

      // Act
      await tester.tap(find.byTooltip('Share live board'));
      await tester.pumpAndSettle();

      // Assert
      expect(taps, 1);
    });

    testWidgets('is absent when no share was offered', (tester) async {
      // Arrange — the account screen's code carries a raw public key, not a
      // link, and handing that to a share sheet is a different act entirely
      await pumpDialog(tester, copyLabel: 'Link');

      // Act — nothing; the absence IS the behaviour

      // Assert
      expect(find.byIcon(Icons.ios_share), findsNothing);
    });

    testWidgets('is reachable without sight, which an icon alone is not',
        (tester) async {
      // Arrange — an unlabelled icon button announces nothing to a screen
      // reader, and this one is the only way to send the link onward
      await pumpDialog(
        tester,
        copyLabel: 'Link',
        share: (label: 'Share live board', onTap: () {}),
      );

      // Act — none

      // Assert
      // The name rides on the semantics `tooltip` field rather than `label` —
      // that is where IconButton puts it, and what TalkBack and VoiceOver read
      // out for a button carrying no text.
      expect(
        tester.getSemantics(find.byTooltip('Share live board')),
        matchesSemantics(
          tooltip: 'Share live board',
          isButton: true,
          isEnabled: true,
          isFocusable: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('is big enough to hit, however small it looks', (tester) async {
      // Arrange — the icon is deliberately 18px so it reads as a hint beside
      // the link, and it would be easy to shrink the box to match. The box is
      // not the icon: this is the only way to send the link onward, and a
      // target under the platform minimum is one that misses.
      await pumpDialog(
        tester,
        copyLabel: 'Link',
        share: (label: 'Share live board', onTap: () {}),
      );

      // Act — none

      // Assert — that the button carries no size overrides, so IconButton's own
      // padded tap target applies.
      //
      // Not a measurement: getSize on the button reports Material 3's inner
      // 40x40 box, while the tappable area Flutter adds around it via
      // MaterialTapTargetSize.padded is the 48 that matters and is not what
      // that finder returns. And not meetsGuideline either — it walks the whole
      // tree and trips on the link above, a 24px-tall target that predates this
      // button, which would say nothing about whether this one regressed.
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.ios_share),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.constraints, isNull);
      expect(button.visualDensity, isNull);
      expect((button.icon as Icon).size, 18);
    });

    testWidgets('leaves the dialog open, so the code can still be scanned',
        (tester) async {
      // Arrange — same reason copying does: sharing the link does not finish
      // the person across the room who is still pointing a camera at the code
      await pumpDialog(
        tester,
        copyLabel: 'Link',
        share: (label: 'Share live board', onTap: () {}),
      );

      // Act
      await tester.tap(find.byTooltip('Share live board'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(QrDialog), findsOneWidget);
    });
  });
}
