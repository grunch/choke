@Tags(['rust'])
library;

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/announcements/announcement_publishers.dart';
import 'package:choke/services/nostr/crypto/rust_nostr_crypto.dart';
import 'package:choke/src/rust/frb_generated.dart';

/// The shipped allowlist, put through the decoder that actually runs.
///
/// `announcement_publishers_test.dart` covers the decoding *rules* against a
/// fake, which is the right shape for testing behaviour but cannot say whether
/// the npubs in the constant are real bech32. Only the crate can, and the
/// consequence of them not being is invisible: an entry that fails to decode is
/// dropped with a `debugPrint` and the channel comes up one publisher short,
/// with nothing on any screen to say so (§3.1).
///
/// A typo here is not a crash and not a test failure anywhere else — it is a key
/// that quietly cannot speak until someone notices an announcement never
/// arrived. Hence the hex: it pins each npub to the key it is meant to be, so a
/// mistyped-but-still-valid bech32 string fails here rather than in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final libraryPath = _findNativeLibrary();
  if (libraryPath == null) {
    group('the shipped allowlist', skip: 'native library not built', () {
      test('needs cargo build --manifest-path rust/Cargo.toml', () {});
    });
    return;
  }

  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(libraryPath));
  });

  test('every shipped publisher decodes, to the key it says it is', () {
    // Act — the same call announcementPublishersProvider makes at startup
    final hex = decodeAnnouncementPublishers(RustNostrCrypto());

    // Assert — nothing silently dropped on the way through
    expect(hex, hasLength(kAnnouncementPublishers.length));
    expect(hex, [
      'c5df6c89ab5bd2728528e800412a713673195ab6f4bd71bb780fe9cec4adecc1',
      'afb8fe8d6825e9290da89267bbfe828f6a2196aa528fc7af899f4e06202ab077',
      'c5df6014c19fdda51a52c0d0406135d687d968bfe19a700468e00a15d757e946',
    ]);
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
