import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/nostr/crypto/nostr_crypto.dart';
import '../../../services/nostr/nostr_service.dart';
import '../../match/models/match.dart';

const _kScoreboardPubkeyKey = 'choke:scoreboard-pubkey';

/// How old a match may be and still be worth showing, matching the home feed.
///
/// A scoreboard is about what is happening on the mats now. Yesterday's matches
/// are history, and history belongs to whoever refereed it.
const scoreboardMaxAgeSeconds = 86400;

/// The pubkey whose matches the scoreboard is watching, in hex, or null when the
/// user has not named one yet.
///
/// Persisted, because someone watching a tournament reopens the app between
/// matches and should not have to paste the same key again.
final watchedPubkeyProvider =
    StateNotifierProvider<WatchedPubkeyNotifier, String?>((ref) {
  return WatchedPubkeyNotifier();
});

/// Holds the watched pubkey and remembers it across launches.
class WatchedPubkeyNotifier extends StateNotifier<String?> {
  WatchedPubkeyNotifier() : super(null) {
    unawaited(_restore());
  }

  /// Whether the user has chosen anything yet — including choosing to stop.
  ///
  /// Tracked rather than inferred from [state] being null, because "nobody has
  /// chosen" and "somebody chose to stop watching" are both null, and a restore
  /// still in flight would read the second as the first and put the board they
  /// just closed back on the screen.
  bool _userHasChosen = false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kScoreboardPubkeyKey);
      // Only if nothing has been chosen in the meantime: restoring asynchronously
      // must never overwrite a key the user pasted while it was in flight.
      if (saved != null && saved.isNotEmpty && !_userHasChosen) {
        state = saved;
      }
    } catch (e) {
      // A device whose preferences cannot be read still watches matches; it just
      // starts by asking for the pubkey again.
      debugPrint('Scoreboard: could not restore the watched pubkey: $e');
    }
  }

  /// Watch [hexPubkey]. Pass null to stop watching and forget it.
  Future<void> watch(String? hexPubkey) async {
    _userHasChosen = true;
    state = hexPubkey;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hexPubkey == null) {
        await prefs.remove(_kScoreboardPubkeyKey);
      } else {
        await prefs.setString(_kScoreboardPubkeyKey, hexPubkey);
      }
    } catch (e) {
      debugPrint('Scoreboard: could not save the watched pubkey: $e');
    }
  }
}

/// Whether [value] is a bare 64-character hex key.
bool isHexPubkey(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim());

/// The hex pubkey [input] names, whether the user pasted hex or an `npub1…`, or
/// null if it is neither.
///
/// Hex is checked first, and by shape. The shape is the only thing that tells
/// the two forms apart, which is why [NostrCrypto.npubDecode] refuses to guess
/// and this function has to decide before asking it.
String? parsePubkey(String input, NostrCrypto crypto) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (isHexPubkey(trimmed)) return trimmed.toLowerCase();
  return crypto.npubDecode(trimmed);
}

/// Matches published by the watched pubkey, newest first.
///
/// Read-only by construction: this notifier subscribes and parses, and has no
/// way to change a match. The scoreboard is for watching somebody else's mats.
class ScoreboardFeedNotifier extends StateNotifier<List<Match>> {
  ScoreboardFeedNotifier(this._nostrService, this._pubkey) : super([]) {
    if (_pubkey == null) return;

    _subscription = _nostrService.eventStream.listen(_onEvent);
    _nostrService.subscribeToAuthor(_pubkey, subscriptionId: _subscriptionId);

    // Start from what the app has already seen of this author.
    //
    // Watching someone, leaving, and watching them again used to show an empty
    // board forever: the relay replays their latest state, but the service has
    // it cached and drops a replay it considers no newer, so nothing reached a
    // feed that had just started from nothing. It would stay empty until that
    // author happened to score again.
    for (final event in _nostrService.cachedEventsOf(31415, _pubkey)) {
      _onEvent(event);
    }
  }

  final NostrService _nostrService;

  /// The author being watched, in hex. Null means nothing is being watched and
  /// this notifier does nothing at all.
  final String? _pubkey;

  StreamSubscription<NostrEvent>? _subscription;

  /// A NIP-01 subscription id is capped at 64 characters, and a relay that gets
  /// a longer one rejects the whole REQ — nos.lol answers
  /// `CLOSED … "ERROR: bad req: invalid subscription id"` and sends nothing.
  /// `scoreboard_` plus a 64-character pubkey is 75, which is how this shipped
  /// broken: publishing worked, the app's own `user_events` worked, and the
  /// scoreboard silently received nothing at all.
  ///
  /// Still derived from the pubkey rather than a constant, so that a departing
  /// feed cannot close the subscription an arriving one just opened. Sixteen hex
  /// characters is 64 bits of the key — far more than enough to tell two watched
  /// authors apart.
  static const _idPrefix = 'sb_';
  static const _idKeyChars = 16;

  String get _subscriptionId {
    final key = _pubkey ?? '';
    final short =
        key.length <= _idKeyChars ? key : key.substring(0, _idKeyChars);
    return '$_idPrefix$short';
  }

  /// Newest event seen per match, so a relay replaying an older revision of an
  /// addressable event cannot undo a newer one.
  final Map<String, int> _createdAt = {};

  void _onEvent(NostrEvent event) {
    if (event.kind != 31415) return;

    // The stream is shared with the user's own subscription and with any other
    // author, and carries no hint of which filter matched. Without this the
    // user's own matches would appear as though the watched pubkey had refereed
    // them.
    if (event.pubkey != _pubkey) return;

    try {
      _upsert(Match.fromNostrEvent(event), event.createdAt);
    } catch (e) {
      debugPrint('Scoreboard: failed to parse event: $e');
    }
  }

  void _upsert(Match match, int createdAt) {
    final seen = _createdAt[match.id];
    if (seen != null && createdAt < seen) return;
    _createdAt[match.id] = createdAt;

    final index = state.indexWhere((m) => m.id == match.id);
    if (index >= 0) {
      final next = List<Match>.from(state);
      next[index] = match;
      state = next;
    } else {
      state = [match, ...state];
    }
  }

  /// When the event carrying [matchId] was published, or null if unseen.
  int? createdAtOf(String matchId) => _createdAt[matchId];

  @override
  void dispose() {
    _subscription?.cancel();
    // Leave the relays alone about an author nobody is watching any more. Without
    // this, every pubkey the user ever tried keeps streaming for the rest of the
    // session.
    if (_pubkey != null) _nostrService.unsubscribe(_subscriptionId);
    super.dispose();
  }
}

/// The live feed for whichever pubkey is being watched.
///
/// Rebuilt when the pubkey changes, which is what tears down the old
/// subscription and opens the new one.
final scoreboardFeedProvider =
    StateNotifierProvider<ScoreboardFeedNotifier, List<Match>>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final pubkey = ref.watch(watchedPubkeyProvider);
  return ScoreboardFeedNotifier(nostrService, pubkey);
});

/// The watched pubkey's recent matches, live ones first.
///
/// Ordered here rather than by arrival: relays return events in whatever order
/// they please, and a board that reshuffles itself as it loads cannot be read.
final scoreboardMatchesProvider = Provider<List<Match>>((ref) {
  final feed = ref.watch(scoreboardFeedProvider.notifier);
  final matches = ref.watch(scoreboardFeedProvider);

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final cutoff = now - scoreboardMaxAgeSeconds;

  final fresh = matches.where((m) {
    final createdAt = feed.createdAtOf(m.id);
    return createdAt == null || createdAt >= cutoff;
  }).toList();

  fresh.sort((a, b) {
    // Live matches first: on a board, the fight in progress is the point.
    final aLive = a.status == MatchStatus.inProgress;
    final bLive = b.status == MatchStatus.inProgress;
    if (aLive != bLive) return aLive ? -1 : 1;

    final aAt = feed.createdAtOf(a.id) ?? 0;
    final bAt = feed.createdAtOf(b.id) ?? 0;
    return bAt.compareTo(aAt);
  });

  return fresh;
});

/// Which statuses the scoreboard shows.
///
/// Its own, not the home feed's: hiding finished matches while watching
/// somebody else's mats should not hide them on your own.
///
/// Defaults to what is happening now, the same as home — a board is about the
/// mats in front of you, and yesterday's results are one tap away.
final scoreboardStatusFilterProvider = StateProvider<Set<MatchStatus>>((ref) {
  return {
    MatchStatus.waiting,
    MatchStatus.inProgress,
  };
});

/// What the list actually shows: recent matches, minus the statuses filtered
/// out.
///
/// Kept apart from [scoreboardMatchesProvider] because the chips count from
/// *that* one. Counting from this would make every hidden status read zero,
/// which is exactly the number that would talk the user out of tapping it.
final scoreboardFilteredMatchesProvider = Provider<List<Match>>((ref) {
  final matches = ref.watch(scoreboardMatchesProvider);
  final allowed = ref.watch(scoreboardStatusFilterProvider);
  return matches.where((m) => allowed.contains(m.status)).toList();
});
