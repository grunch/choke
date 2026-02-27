import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../../../services/nostr/nostr_service.dart';
import '../../home/providers/home_providers.dart';

/// State for the match control screen
class MatchControlState {
  final Match match;
  final int remainingSeconds;
  final bool isPublishing;
  final List<_UndoEntry> undoStack;

  MatchControlState({
    required this.match,
    required this.remainingSeconds,
    this.isPublishing = false,
    this.undoStack = const [],
  });

  bool get isWaiting => match.status == MatchStatus.waiting;
  bool get isRunning => match.status == MatchStatus.inProgress;
  bool get isFinished =>
      match.status == MatchStatus.finished ||
      match.status == MatchStatus.canceled;
  bool get canUndo => undoStack.isNotEmpty && isRunning;

  MatchControlState copyWith({
    Match? match,
    int? remainingSeconds,
    bool? isPublishing,
    List<_UndoEntry>? undoStack,
  }) {
    return MatchControlState(
      match: match ?? this.match,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPublishing: isPublishing ?? this.isPublishing,
      undoStack: undoStack ?? this.undoStack,
    );
  }
}

/// Tracks which field was changed for undo
class _UndoEntry {
  /// 1 = fighter 1, 2 = fighter 2
  final int fighter;

  /// Field name: 'pt2', 'pt3', 'pt4', 'adv', 'pen'
  final String field;

  _UndoEntry(this.fighter, this.field);
}

/// Manages match control: timer, scoring, publishing
class MatchControlNotifier extends StateNotifier<MatchControlState> {
  final NostrService _nostrService;
  final MatchFeedNotifier? _feedNotifier;
  Timer? _timer;
  bool _pendingPublish = false;

  MatchControlNotifier(Match match, this._nostrService, [this._feedNotifier])
      : super(MatchControlState(
          match: match,
          remainingSeconds: _calculateRemaining(match),
        )) {
    // If match is already in progress, resume timer
    if (match.status == MatchStatus.inProgress) {
      _startTimer();
    }
  }

  static int _calculateRemaining(Match match) {
    if (match.status == MatchStatus.waiting) {
      return match.duration;
    }
    if (match.startAt == null || match.startAt == 0) {
      return match.duration;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = now - match.startAt!;
    return (match.duration - elapsed).clamp(0, match.duration);
  }

  /// Start the match: set status to inProgress, set startAt, start timer
  void startMatch() {
    if (!state.isWaiting) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final updated = state.match.copyWith(
      status: MatchStatus.inProgress,
      startAt: now,
    );

    state = state.copyWith(
      match: updated,
      remainingSeconds: updated.duration,
    );

    _startTimer();
    _publishState();
  }

  /// Score: +2 (takedown/sweep)
  void scorePt2(int fighter) => _score(fighter, 'pt2');

  /// Score: +3 (guard pass)
  void scorePt3(int fighter) => _score(fighter, 'pt3');

  /// Score: +4 (mount/back take)
  void scorePt4(int fighter) => _score(fighter, 'pt4');

  /// Add advantage
  void scoreAdv(int fighter) => _score(fighter, 'adv');

  /// Add penalty
  void scorePen(int fighter) => _score(fighter, 'pen');

  void _score(int fighter, String field) {
    if (!state.isRunning) return;

    final m = state.match;
    Match updated;

    if (fighter == 1) {
      updated = switch (field) {
        'pt2' => m.copyWith(f1Pt2: m.f1Pt2 + 1),
        'pt3' => m.copyWith(f1Pt3: m.f1Pt3 + 1),
        'pt4' => m.copyWith(f1Pt4: m.f1Pt4 + 1),
        'adv' => m.copyWith(f1Adv: m.f1Adv + 1),
        'pen' => m.copyWith(f1Pen: m.f1Pen + 1),
        _ => m,
      };
    } else {
      updated = switch (field) {
        'pt2' => m.copyWith(f2Pt2: m.f2Pt2 + 1),
        'pt3' => m.copyWith(f2Pt3: m.f2Pt3 + 1),
        'pt4' => m.copyWith(f2Pt4: m.f2Pt4 + 1),
        'adv' => m.copyWith(f2Adv: m.f2Adv + 1),
        'pen' => m.copyWith(f2Pen: m.f2Pen + 1),
        _ => m,
      };
    }

    state = state.copyWith(
      match: updated,
      undoStack: [...state.undoStack, _UndoEntry(fighter, field)],
    );

    _publishState();
  }

  /// Undo last scoring action
  void undo() {
    if (!state.canUndo) return;

    final stack = List<_UndoEntry>.from(state.undoStack);
    final entry = stack.removeLast();
    final m = state.match;

    Match updated;
    if (entry.fighter == 1) {
      updated = switch (entry.field) {
        'pt2' => m.copyWith(f1Pt2: (m.f1Pt2 - 1).clamp(0, 999)),
        'pt3' => m.copyWith(f1Pt3: (m.f1Pt3 - 1).clamp(0, 999)),
        'pt4' => m.copyWith(f1Pt4: (m.f1Pt4 - 1).clamp(0, 999)),
        'adv' => m.copyWith(f1Adv: (m.f1Adv - 1).clamp(0, 999)),
        'pen' => m.copyWith(f1Pen: (m.f1Pen - 1).clamp(0, 999)),
        _ => m,
      };
    } else {
      updated = switch (entry.field) {
        'pt2' => m.copyWith(f2Pt2: (m.f2Pt2 - 1).clamp(0, 999)),
        'pt3' => m.copyWith(f2Pt3: (m.f2Pt3 - 1).clamp(0, 999)),
        'pt4' => m.copyWith(f2Pt4: (m.f2Pt4 - 1).clamp(0, 999)),
        'adv' => m.copyWith(f2Adv: (m.f2Adv - 1).clamp(0, 999)),
        'pen' => m.copyWith(f2Pen: (m.f2Pen - 1).clamp(0, 999)),
        _ => m,
      };
    }

    state = state.copyWith(match: updated, undoStack: stack);
    _publishState();
  }

  /// Finish the match
  void finishMatch() {
    if (state.isFinished) return;

    _timer?.cancel();
    final updated = state.match.copyWith(status: MatchStatus.finished);
    state = state.copyWith(match: updated, remainingSeconds: 0);
    _publishState();
  }

  /// Cancel the match
  void cancelMatch() {
    if (state.isFinished) return;

    _timer?.cancel();
    final updated = state.match.copyWith(status: MatchStatus.canceled);
    state = state.copyWith(match: updated);
    _publishState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _calculateRemaining(state.match);
      state = state.copyWith(remainingSeconds: remaining);

      if (remaining <= 0) {
        _timer?.cancel();
      }
    });
  }

  /// Publish current match state to Nostr
  Future<void> _publishState() async {
    if (state.isPublishing) {
      _pendingPublish = true;
      return;
    }

    state = state.copyWith(isPublishing: true);

    try {
      final match = state.match;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Update home feed immediately (don't wait for relay round-trip)
      _feedNotifier?.addLocal(match);
      final expiration = now + 604800; // 1 week

      await _nostrService.publishAddressableEvent(
        dTag: match.id,
        content: match.toJsonString(),
        additionalTags: [
          ['expiration', expiration.toString()],
        ],
      );

      debugPrint('MatchControl: published match ${match.id} (${match.status.name})');
    } catch (e) {
      debugPrint('MatchControl: publish failed: $e');
    } finally {
      state = state.copyWith(isPublishing: false);

      // If there was a queued publish, do it now
      if (_pendingPublish) {
        _pendingPublish = false;
        _publishState();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for the currently active match being controlled.
/// Set this before navigating to MatchControlScreen.
final activeMatchProvider = StateProvider<Match?>((ref) => null);

/// Provider for the match control notifier.
/// Reads the active match from [activeMatchProvider].
final matchControlProvider =
    StateNotifierProvider<MatchControlNotifier, MatchControlState>((ref) {
  final match = ref.read(activeMatchProvider);
  if (match == null) {
    throw StateError('activeMatchProvider must be set before using matchControlProvider');
  }
  final nostrService = ref.watch(nostrServiceProvider);
  final feedNotifier = ref.read(matchFeedProvider.notifier);
  return MatchControlNotifier(match, nostrService, feedNotifier);
});
