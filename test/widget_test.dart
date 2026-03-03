import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:choke/main.dart';

void main() {
  testWidgets('App loads with bottom navigation', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ChokeApp()));

    // Verify that bottom navigation items exist.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify app title in header.
    expect(find.text('Choke'), findsOneWidget);
  });

  testWidgets('Can navigate to different tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChokeApp()));

    // Tap on Match tab.
    await tester.tap(find.text('Match'));
    await tester.pump();

    // Verify Match screen content.
    expect(find.text('Create a match from the Home screen'), findsOneWidget);

    // Tap on Account tab.
    await tester.tap(find.text('Account'));
    await tester.pump();

    // Verify Account screen content.
    expect(find.text('Account'), findsWidgets);
  });
}
