import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../match/models/match.dart';
import '../../match/providers/match_providers.dart';
import '../../../services/nostr/nostr_service.dart';

/// Status filter: which statuses to show on the home screen
final statusFilterProvider = StateProvider<Set<MatchStatus>>((ref) {
  return {MatchStatus.waiting, MatchStatus.inProgress};
});

/// Collects matches from Nostr events + locally created matches.
/// Deduplicates by match ID (latest created_at wins).
class MatchFeedNotifier extends StateNotifier<List<Match>> {
  final NostrService _nostrService;
  StreamSubscription<NostrEvent>? _subscription;

  MatchFeedNotifier(this._nostrService) : super([]) {
    _subscription = _nostrService.eventStream.listen(_onEvent);
  }

  void _onEvent(NostrEvent event) {
    if (event.kind != 31415) return;

    try {
      final match = Match.fromNostrEvent(event);
      _upsert(match, event.createdAt);
    } catch (e) {
      debugPrint('MatchFeed: failed to parse event: $e');
    }
  }

  /// Add or update a match. If existing match has older created_at, replace it.
  void _upsert(Match match, int createdAt) {
    final existing = state.indexWhere((m) => m.id == match.id);
    if (existing >= 0) {
      // Replace with newer version
      final newState = List<Match>.from(state);
      newState[existing] = match;
      state = newState;
    } else {
      state = [match, ...state];
    }
  }

  /// Add a locally created match (from CreateMatchScreen)
  void addLocal(Match match) {
    _upsert(match, DateTime.now().millisecondsSinceEpoch ~/ 1000);
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

/// Filtered match list based on status filter and 24h window
final filteredMatchListProvider = Provider<List<Match>>((ref) {
  final matches = ref.watch(matchFeedProvider);
  final statusFilter = ref.watch(statusFilterProvider);

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final cutoff = now - 86400; // 24 hours ago

  return matches.where((m) {
    // Filter by status
    if (!statusFilter.contains(m.status)) return false;
    // Filter by 24h window (use startAt if available, otherwise allow waiting matches)
    if (m.startAt != null && m.startAt! > 0 && m.startAt! < cutoff) {
      return false;
    }
    return true;
  }).toList();
});
