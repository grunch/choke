import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';

/// Manages the list of matches (created locally + received from relays)
class MatchListNotifier extends StateNotifier<List<Match>> {
  MatchListNotifier() : super([]);

  /// Add a new match to the top of the list
  void addMatch(Match match) {
    // Prevent duplicates
    if (state.any((m) => m.id == match.id)) return;
    state = [match, ...state];
  }

  /// Remove a match by ID
  void removeMatch(String matchId) {
    state = state.where((m) => m.id != matchId).toList();
  }

  /// Update an existing match (replaces by ID)
  void updateMatch(Match updated) {
    state = state.map((m) => m.id == updated.id ? updated : m).toList();
  }

  /// Get a match by ID
  Match? getMatch(String matchId) {
    try {
      return state.firstWhere((m) => m.id == matchId);
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the match list
final matchListProvider =
    StateNotifierProvider<MatchListNotifier, List<Match>>((ref) {
  return MatchListNotifier();
});
