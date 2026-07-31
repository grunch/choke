import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock the share_plus platform channel; records the shared text, or throws
/// when [fail] is set.
///
/// Shared by every screen that opens the share sheet, so how the plugin is
/// driven is asserted in one place rather than drifting between the account
/// screen's tests and the scoreboard's.
List<Map<Object?, Object?>> mockShareChannel(
  WidgetTester tester, {
  bool fail = false,
}) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <Map<Object?, Object?>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      if (fail) {
        throw PlatformException(code: 'no-share-target');
      }
      calls.add((call.arguments as Map).cast<Object?, Object?>());
      return 'dev.fluttercommunity.plus/share/success';
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return calls;
}
