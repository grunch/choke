import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/nostr/crypto/nostr_crypto.dart';
import '../../services/nostr/nostr_service.dart';
import 'announcement_inbox.dart';
import 'announcement_publishers.dart';
import 'models/app_version.dart';

/// The version this build reports, from `package_info_plus`.
///
/// Overridden in `main.dart`, like the crypto and the relay backend: reading a
/// plugin is an async call, and version targeting has to answer synchronously
/// for every event that arrives.
final appVersionProvider = Provider<AppVersion>((ref) {
  throw UnimplementedError(
    'appVersionProvider must be overridden with the running app version',
  );
});

/// The allowlist of §3.1, decoded to the hex a subscription filter needs.
final announcementPublishersProvider = Provider<List<String>>((ref) {
  return decodeAnnouncementPublishers(ref.watch(nostrCryptoProvider));
});

/// The announcement channel.
final announcementInboxProvider =
    StateNotifierProvider<AnnouncementInbox, AnnouncementInboxState>((ref) {
  final inbox = AnnouncementInbox(
    service: ref.watch(nostrServiceProvider),
    crypto: ref.watch(nostrCryptoProvider),
    appVersion: ref.watch(appVersionProvider),
    publishers: ref.watch(announcementPublishersProvider),
  );
  ref.onDispose(inbox.close);
  return inbox;
});
