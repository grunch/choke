import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../models/match_outcome.dart';
import '../../../services/audio/match_sounds.dart';
import '../../../services/nostr/nostr_service.dart';
import '../../home/providers/home_providers.dart';

/// State for the match control screen
class MatchControlState {
  final Match match;
  final int remainingSeconds;
  final bool isPublishing;
  final List<_UndoEntry> undoStack;

  /// The clock has run out, and the match cannot be finished without asking.
  ///
  /// Either the fighters are level — a level scoreboard is a question, not an
  /// answer — or someone has four penalties, and only a referee may call a
  /// disqualification. The match stays [MatchStatus.inProgress] until they say
  /// how it ended, because it genuinely has not been decided yet.
  final bool awaitsOutcome;

  MatchControlState({
    required this.match,
    required this.remainingSeconds,
    this.isPublishing = false,
    this.undoStack = const [],
    this.awaitsOutcome = false,
  });

  bool get isWaiting => match.status == MatchStatus.waiting;
  bool get isRunning => match.status == MatchStatus.inProgress;
  bool get isFinished =>
      match.status == MatchStatus.finished ||
      match.status == MatchStatus.canceled;
  bool get canUndo => undoStack.isNotEmpty && isRunning;

  /// The match is under way but its clock is stopped (fighters off the mat).
  bool get isPaused => isRunning && match.pausedAt != null;

  /// What the scoreboard already says, or null when it says nothing — level, and
  /// the referees' to call.
  MatchOutcome? get suggestedOutcome => MatchOutcome.suggestedFor(match);

  MatchControlState copyWith({
    Match? match,
    int? remainingSeconds,
    bool? isPublishing,
    List<_UndoEntry>? undoStack,
    bool? awaitsOutcome,
  }) {
    return MatchControlState(
      match: match ?? this.match,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPublishing: isPublishing ?? this.isPublishing,
      undoStack: undoStack ?? this.undoStack,
      awaitsOutcome: awaitsOutcome ?? this.awaitsOutcome,
    );
  }
}

/// Tracks which field was changed for undo
class _UndoEntry {
  /// 1 = fighter 1, 2 = fighter 2
  final int fighter;

  /// Field name: 'pt2', 'pt3', 'pt4', 'adv', 'pen'
  final String field;

  /// Applied change: +1 for an add, -1 for a subtract
  final int delta;

  _UndoEntry(this.fighter, this.field, [this.delta = 1]);
}

/// Manages match control: timer, scoring, publishing
class MatchControlNotifier extends StateNotifier<MatchControlState> {
  static const _retryBaseDelay = Duration(seconds: 2);
  static const _retryMaxDelay = Duration(seconds: 30);

  final NostrService _nostrService;
  final MatchFeedNotifier? _feedNotifier;

  /// The bell and the horn. Silent by default so that constructing a notifier
  /// — which every test does — never reaches for a platform channel.
  final MatchSounds _sounds;

  Timer? _timer;

  /// Latest match state no relay has confirmed yet. Rapid actions coalesce
  /// here: the event is addressable (one per match), so only the newest
  /// state matters and anything older is superseded before it is sent.
  Match? _outbox;
  bool _sending = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  StreamSubscription<String>? _relayConnectedSub;

  MatchControlNotifier(
    Match match,
    this._nostrService, [
    this._feedNotifier,
    this._sounds = const SilentMatchSounds(),
  ]) : super(MatchControlState(
          match: match,
          remainingSeconds: _calculateRemaining(match),
        )) {
    // Load the cues now, while the referee is still reading the fighters'
    // names. Doing it when they press start would put the asset decode between
    // the press and the bell.
    unawaited(_sounds.warmUp());

    // A relay that just (re)connected can take the pending state right now —
    // waiting out a backoff scheduled against its dead predecessor would
    // leave the remote board stale for up to 30 extra seconds.
    _relayConnectedSub = _nostrService.onRelayConnected.listen((_) {
      if (_outbox == null) return;
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
      _drainOutbox();
    });

    if (match.status == MatchStatus.inProgress) {
      if (match.pausedAt != null) {
        // A paused clock stays paused, however long the app was away.
        return;
      }
      // The clock may have run out while the app was closed — a match is
      // never left in progress past its own duration. It ran out unwatched,
      // though, so it is settled in silence: sounding the horn here would
      // announce the end of a match that finished while the phone was in
      // somebody's bag.
      if (state.remainingSeconds <= 0) {
        _onTimeUp(announce: false);
      } else {
        _startTimer();
      }
    }
  }

  static int _calculateRemaining(Match match) {
    if (match.status == MatchStatus.waiting) {
      return match.duration;
    }
    if (match.startAt == null || match.startAt == 0) {
      return match.duration;
    }
    // While paused the clock reads as it did at the moment it was stopped.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = (match.pausedAt ?? now) - match.startAt!;
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

    // The bell only ever marks the opening of a fight, which is why it lives
    // here and not in resumeMatch: restarting a stopped clock is the same
    // match carrying on, and a second bell would read as a second match.
    unawaited(_sounds.playStart());

    _startTimer();
    _publishState();
  }

  /// Stop the clock without ending the match — fighters left the mat, a
  /// grip needs resetting, the referee is conferring. Scoring stays open.
  void pauseMatch() {
    if (!state.isRunning || state.isPaused) return;

    _timer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paused = state.match.copyWith(pausedAt: now);

    // Freeze the clock at what it actually reads now, not at the last tick:
    // the timer may have been throttled (app backgrounded, busy UI thread),
    // and a stale value would put seconds back on the clock.
    final remaining = _calculateRemaining(paused);
    if (remaining <= 0) {
      // Time ran out while the timer was stalled — the clock is done, and a
      // match whose clock is done cannot be paused.
      _onTimeUp();
      return;
    }

    state = state.copyWith(match: paused, remainingSeconds: remaining);
    _publishState();
  }

  /// Restart the clock with the time that was left when it stopped.
  ///
  /// The stoppage is charged to [Match.startAt], not to the fighters: moving
  /// the start forward by the length of the pause leaves the remaining time
  /// exactly where it was.
  void resumeMatch() {
    if (!state.isPaused) return;

    final match = state.match;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final stoppage = now - match.pausedAt!;

    final resumed = match.copyWith(
      startAt: match.startAt! + stoppage,
      pausedAt: null,
    );

    state = state.copyWith(
      match: resumed,
      remainingSeconds: _calculateRemaining(resumed),
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

  /// Subtract: -2 (takedown/sweep count)
  void subtractPt2(int fighter) => _subtract(fighter, 'pt2');

  /// Subtract: -3 (guard pass count)
  void subtractPt3(int fighter) => _subtract(fighter, 'pt3');

  /// Subtract: -4 (mount/back take count)
  void subtractPt4(int fighter) => _subtract(fighter, 'pt4');

  /// Remove advantage
  void subtractAdv(int fighter) => _subtract(fighter, 'adv');

  /// Remove penalty
  void subtractPen(int fighter) => _subtract(fighter, 'pen');

  void _score(int fighter, String field) {
    if (!state.isRunning) return;

    state = state.copyWith(
      match: _applyDelta(state.match, fighter, field, 1),
      undoStack: [...state.undoStack, _UndoEntry(fighter, field, 1)],
    );

    _publishState();
  }

  void _subtract(int fighter, String field) {
    if (!state.isRunning) return;
    if (_count(state.match, fighter, field) <= 0) return;

    state = state.copyWith(
      match: _applyDelta(state.match, fighter, field, -1),
      undoStack: [...state.undoStack, _UndoEntry(fighter, field, -1)],
    );

    _publishState();
  }

  /// Undo last scoring action (reverts adds and subtracts alike)
  void undo() {
    if (!state.canUndo) return;

    final stack = List<_UndoEntry>.from(state.undoStack);
    final entry = stack.removeLast();

    state = state.copyWith(
      match: _applyDelta(state.match, entry.fighter, entry.field, -entry.delta),
      undoStack: stack,
    );
    _publishState();
  }

  static int _count(Match m, int fighter, String field) {
    if (fighter == 1) {
      return switch (field) {
        'pt2' => m.f1Pt2,
        'pt3' => m.f1Pt3,
        'pt4' => m.f1Pt4,
        'adv' => m.f1Adv,
        'pen' => m.f1Pen,
        _ => 0,
      };
    }
    return switch (field) {
      'pt2' => m.f2Pt2,
      'pt3' => m.f2Pt3,
      'pt4' => m.f2Pt4,
      'adv' => m.f2Adv,
      'pen' => m.f2Pen,
      _ => 0,
    };
  }

  static Match _applyDelta(Match m, int fighter, String field, int delta) {
    int next(int v) => (v + delta).clamp(0, 999);

    if (fighter == 1) {
      return switch (field) {
        'pt2' => m.copyWith(f1Pt2: next(m.f1Pt2)),
        'pt3' => m.copyWith(f1Pt3: next(m.f1Pt3)),
        'pt4' => m.copyWith(f1Pt4: next(m.f1Pt4)),
        'adv' => m.copyWith(f1Adv: next(m.f1Adv)),
        'pen' => m.copyWith(f1Pen: next(m.f1Pen)),
        _ => m,
      };
    }
    return switch (field) {
      'pt2' => m.copyWith(f2Pt2: next(m.f2Pt2)),
      'pt3' => m.copyWith(f2Pt3: next(m.f2Pt3)),
      'pt4' => m.copyWith(f2Pt4: next(m.f2Pt4)),
      'adv' => m.copyWith(f2Adv: next(m.f2Adv)),
      'pen' => m.copyWith(f2Pen: next(m.f2Pen)),
      _ => m,
    };
  }

  /// End the match with the outcome the referee chose.
  ///
  /// There is no way to finish a match without saying how it ended. That is the
  /// whole point: a match that stops with only a status publishes a scoreboard
  /// that can name the wrong fighter.
  /// [endedAt] defaults to now, which is right for a referee ending a match in
  /// front of them. It is *not* right for a match the clock ended while the app
  /// was closed: that one ended when regulation time ran out, not when someone
  /// happened to reopen it — see [_onTimeUp].
  void finishWith(MatchOutcome outcome, {int? endedAt}) {
    if (state.isFinished) return;
    _setOutcome(outcome, endedAt: endedAt);
  }

  /// Correct a result that is already published.
  ///
  /// A match the clock closed with the wrong winner — a penalty entered against
  /// the wrong fighter, say — would otherwise stay wrong forever: a finished
  /// match is read-only, and the event is out on the relays. The event is
  /// addressable, so republishing it replaces the old one, and the monotonic
  /// created_at makes sure the correction wins.
  void amendOutcome(MatchOutcome outcome) {
    // Keep the time the *match* ended. A correction is not an ending: the event
    // is republished, and its Nostr created_at already records when the fix went
    // out. Stamping the amendment over endedAt would tell every consumer that a
    // match from yesterday ended the moment somebody edited it.
    //
    // A legacy result has no endedAt to keep, so it gets one now — which is the
    // best available answer, and better than none.
    _setOutcome(outcome, endedAt: state.match.endedAt);
  }

  /// [endedAt] defaults to now, which is what a referee ending a match in front
  /// of them means. It is *not* what the clock means: a match whose time ran out
  /// while the app was closed ended then, not when someone reopened it.
  void _setOutcome(MatchOutcome outcome, {int? endedAt}) {
    _timer?.cancel();
    final match = state.match;

    final updated = match.copyWith(
      status: MatchStatus.finished,
      pausedAt: null,
      winner: outcome.winner,
      method: outcome.method,
      submission: outcome.submission,
      dqReason: outcome.dqReason,
      dqDetail: outcome.dqDetail,
      endedAt: endedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    state = state.copyWith(
      match: updated,
      remainingSeconds: 0,
      awaitsOutcome: false,
    );
    _publishState();
  }

  /// The clock has reached zero. Whether that ends the match depends on what
  /// the scoreboard says — and sometimes it says nothing.
  ///
  /// [announce] sounds the horn. It is true for a clock that runs out with
  /// somebody watching, and false for one whose time expired while the app was
  /// closed — that match was over long before this code ran, and a horn would
  /// be announcing history.
  void _onTimeUp({bool announce = true}) {
    _timer?.cancel();

    // Before anything else: the horn marks the end of regulation time, which
    // has happened whether or not the scoreboard can name a winner. Waiting to
    // see if an outcome comes out of it would leave a level match ending in
    // silence — the one case where everyone on the mat most needs telling.
    if (announce) unawaited(_sounds.playEnd());

    final outcome = state.suggestedOutcome;

    // The match ended when regulation time ran out — not when the app noticed.
    // Reopening a match whose clock expired yesterday must not stamp today.
    // (startAt is moved forward by any stoppage, so this is the real expiry.)
    final match = state.match;
    final expiry = match.startAt != null
        ? match.startAt! + match.duration
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // A fighter on four penalties, or a level scoreboard: neither is the app's
    // to decide. Stop the clock, keep the match open, and ask. Closing it "on
    // points" would swallow a disqualification whole, or invent a winner the
    // data does not have.
    if (outcome == null || match.hasDisqualifyingPenalties) {
      state = state.copyWith(remainingSeconds: 0, awaitsOutcome: true);
      _publishState();
      return;
    }

    finishWith(outcome, endedAt: expiry);
  }

  /// Cancel the match
  void cancelMatch() {
    if (state.isFinished) return;

    _timer?.cancel();
    final updated = state.match.copyWith(
      status: MatchStatus.canceled,
      pausedAt: null,
    );
    state = state.copyWith(match: updated, awaitsOutcome: false);
    _publishState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _calculateRemaining(state.match);
      state = state.copyWith(remainingSeconds: remaining);

      // Regulation time is over.
      if (remaining <= 0) {
        _onTimeUp();
      }
    });
  }

  /// Queue the current match state for publishing to Nostr.
  ///
  /// The remote board must always converge to what this screen shows, so
  /// this never drops a state: it lands in the outbox (superseding anything
  /// older, which no longer matters) and stays there until a relay accepts
  /// it — failures are retried with backoff, on their own.
  void _publishState() {
    _outbox = state.match;

    // Update home feed immediately (don't wait for relay round-trip)
    _feedNotifier?.addLocal(state.match);

    // A fresh action beats waiting out a backoff — try again right away.
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;

    _drainOutbox();
  }

  Future<void> _drainOutbox() async {
    if (_sending) return;
    _sending = true;
    if (mounted) state = state.copyWith(isPublishing: true);

    while (_outbox != null) {
      final match = _outbox!;
      try {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _nostrService.publishAddressableEvent(
          dTag: match.id,
          content: match.toJsonString(),
          additionalTags: [
            ['expiration', '${now + 604800}'], // 1 week
          ],
        );

        _retryAttempt = 0;
        // A newer state may have landed while this one was in flight; if
        // so, loop and send it too. Otherwise the outbox is drained.
        if (identical(_outbox, match)) _outbox = null;
        debugPrint(
            'MatchControl: published match ${match.id} (${match.status.name})');
      } catch (e) {
        debugPrint(
            'MatchControl: publish failed (attempt ${_retryAttempt + 1}): $e');
        _retryAttempt++;
        final delay = _retryBaseDelay * (1 << (_retryAttempt - 1).clamp(0, 4));
        _retryTimer = Timer(
          delay > _retryMaxDelay ? _retryMaxDelay : delay,
          _drainOutbox,
        );
        break;
      }
    }

    _sending = false;
    if (mounted) state = state.copyWith(isPublishing: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    _relayConnectedSub?.cancel();
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
    throw StateError(
        'activeMatchProvider must be set before using matchControlProvider');
  }
  final nostrService = ref.watch(nostrServiceProvider);
  final feedNotifier = ref.read(matchFeedProvider.notifier);
  final sounds = ref.watch(matchSoundsProvider);
  return MatchControlNotifier(match, nostrService, feedNotifier, sounds);
});
