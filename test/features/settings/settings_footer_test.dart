import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:choke/features/settings/settings_screen.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

void main() {
  group('Settings footer', () {
    testWidgets('shows belt badge, creator credit, and version',
        (WidgetTester tester) async {
      // Override packageInfoProvider with a resolved value
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWith(
            (ref) => Future.value(PackageInfo(
              appName: 'Choke',
              packageName: 'com.example.choke',
              version: '1.2.3',
              buildNumber: '42',
            )),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SettingsScreen(),
          ),
        ),
      );

      // Let the FutureProvider resolve
      await tester.pumpAndSettle();

      // Scroll to the bottom to find the footer
      await tester.scrollUntilVisible(
        find.text('⬛⬛⬛🟥⬛'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Black belt badge
      expect(find.text('⬛⬛⬛🟥⬛'), findsOneWidget);

      // Creator credit (localized)
      expect(find.text('Built by Pana'), findsOneWidget);

      // Version from packageInfoProvider
      expect(find.text('v1.2.3'), findsOneWidget);
    });

    testWidgets('shows fallback when packageInfo fails',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWith(
            (ref) => Future<PackageInfo>.error('Platform error'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('⬛⬛⬛🟥⬛'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Belt badge and credit still show
      expect(find.text('⬛⬛⬛🟥⬛'), findsOneWidget);
      expect(find.text('Built by Pana'), findsOneWidget);

      // Error fallback
      expect(find.text('—'), findsOneWidget);
    });
  });
}
