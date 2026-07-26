import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../match/models/match.dart';
import '../../../services/nostr/nostr_service.dart';

/// Status filter: which statuses to show on the home screen.
/// Only active matches (waiting + in progress) are shown by default; the user
/// can reveal finished and canceled matches by tapping their filter chips.
final statusFilterProvider = StateProvider<Set<MatchStatus>>((ref) {
  return {
    MatchStatus.waiting,
    MatchStatus.inProgress,
  };
});

/// Collects matches from Nostr events + locally created matches.
/// Deduplicates by match ID (latest created_at wins).
class MatchFeedNotifier extends StateNotifier<List<Match>> {
  final NostrService _nostrService;
  StreamSubscription<NostrEvent>? _subscription;
  final Map<String, int> _createdAtMap = {};

  MatchFeedNotifier(this._nostrService) : super([]) {
    _subscription = _nostrService.eventStream.listen(_onEvent);
  }

  void _onEvent(NostrEvent event) {
    if (event.kind != 31415) return;

    // This feed is *my* matches. The event stream is shared by every
    // subscription and says nothing about which filter matched, so without this
    // the scoreboard section — which subscribes to whatever pubkey the user
    // pastes, on purpose — would file other people's matches in here.
    //
    // A null pubkey means the app has not looked itself up yet, which only
    // happens before `subscribeToUserEvents`, when this user's is the only
    // subscription there is. Accepting during that window is safe; dropping
    // would throw away the user's own opening events, because a relay does not
    // send them again.
    final me = _nostrService.userPubkey;
    if (me != null && event.pubkey != me) return;

    try {
      final match = Match.fromNostrEvent(event);
      _upsert(match, event.createdAt);
    } catch (e) {
      debugPrint('MatchFeed: failed to parse event: $e');
    }
  }

  /// Add or update a match. Only replaces if createdAt is newer.
  void _upsert(Match match, int createdAt) {
    final existingCreatedAt = _createdAtMap[match.id];
    if (existingCreatedAt != null && createdAt < existingCreatedAt) {
      // Stale event, ignore
      return;
    }

    _createdAtMap[match.id] = createdAt;

    final existingIdx = state.indexWhere((m) => m.id == match.id);
    if (existingIdx >= 0) {
      final newState = List<Match>.from(state);
      newState[existingIdx] = match;
      state = newState;
    } else {
      state = [match, ...state];
    }
  }

  /// Get the event created_at for a match ID
  int? getCreatedAt(String matchId) => _createdAtMap[matchId];

  /// Add or update a locally-authored match (creation or control screen).
  ///
  /// The local state is authoritative on this device: it is at least as new
  /// as anything published or echoed back so far. Published events carry a
  /// per-match monotonic created_at that can run ahead of the wall clock
  /// (rapid same-second actions), so stamping with the clock alone could
  /// lose against the echo of our own earlier publish.
  void addLocal(Match match) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final existing = _createdAtMap[match.id] ?? 0;
    _upsert(match, now > existing ? now : existing + 1);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for the match feed (Nostr events + local)
final matchFeedProvider =
    StateNotifierProvider<MatchFeedNotifier, List<Match>>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  return MatchFeedNotifier(nostrService);
});

/// Matches from the last 24 hours regardless of status.
/// Uses the Nostr event created_at (not match.startAt) for the time filter.
/// This is the base set the home screen displays and counts from.
final recentMatchListProvider = Provider<List<Match>>((ref) {
  final feedNotifier = ref.watch(matchFeedProvider.notifier);
  final matches = ref.watch(matchFeedProvider);

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final cutoff = now - 86400; // 24 hours ago

  return matches.where((m) {
    final createdAt = feedNotifier.getCreatedAt(m.id);
    return createdAt == null || createdAt >= cutoff;
  }).toList();
});

/// Recent matches narrowed by the selected status filter.
final filteredMatchListProvider = Provider<List<Match>>((ref) {
  final matches = ref.watch(recentMatchListProvider);
  final statusFilter = ref.watch(statusFilterProvider);
  return matches.where((m) => statusFilter.contains(m.status)).toList();
});
