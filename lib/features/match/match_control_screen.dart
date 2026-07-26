import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../services/wakelock/screen_wakelock.dart';
import '../../shared/theme/app_theme.dart';
import 'models/match.dart';
import 'providers/match_control_provider.dart';
import 'widgets/hold_button.dart';
import 'widgets/match_outcome_sheet.dart';
import 'widgets/outcome_label.dart';

/// Parse hex color string (#RRGGBB) to Color with fallback
Color _hexToColor(String hex, Color fallback) {
  try {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return fallback;
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Format seconds as mm:ss
String _formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Landscape "thumb rails" match control screen.
///
/// Each fighter owns a side rail with their scoring buttons, so every
/// action is a single tap — no fighter selector. Holding a scoring button
/// for one second subtracts that score instead of adding it.
class MatchControlScreen extends ConsumerStatefulWidget {
  final Match match;

  const MatchControlScreen({super.key, required this.match});

  @override
  ConsumerState<MatchControlScreen> createState() => _MatchControlScreenState();
}

class _MatchControlScreenState extends ConsumerState<MatchControlScreen> {
  /// Held onto from [initState] because [dispose] runs once `ref` is no longer
  /// usable, and releasing the screen is the one thing that must still happen.
  late final ScreenWakelock _wakelock;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _wakelock = ref.read(screenWakelockProvider);
    _syncWakelock(ref.read(matchControlProvider));

    // A match whose clock expired while the app was closed arrives here already
    // waiting: the notifier settles that in its constructor, before this widget
    // exists. `ref.listen` only reports *changes*, so it would never fire for
    // that, and the match would sit dead at 00:00 until someone thought to hold
    // Finish. Ask on the first frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(matchControlProvider);
      if (state.awaitsOutcome) _askOutcome(state);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    unawaited(_wakelock.keepAwake(false));
    super.dispose();
  }

  /// Keep the screen on for as long as this match could still be scored.
  ///
  /// A fight can go a minute with nothing to award, which is longer than most
  /// phones wait before locking — and a referee should never have to unlock a
  /// phone to score the takedown that ends it. A decided match releases the
  /// screen again, so the result can sit on the scorer's table without holding
  /// the display on.
  void _syncWakelock(MatchControlState state) {
    unawaited(_wakelock.keepAwake(!state.isFinished));
  }

  /// Guards against re-opening the sheet on every rebuild while it is already
  /// up: `awaitsOutcome` stays true until the referee answers.
  bool _askingOutcome = false;

  /// Ask the referee how it ended, and end it with what they say.
  ///
  /// Dismissing the sheet leaves the match open — which is the honest state of
  /// a match nobody has decided, and lets them go back and fix the scoreboard
  /// before committing to a result.
  Future<void> _askOutcome(MatchControlState state) async {
    if (_askingOutcome) return;
    _askingOutcome = true;
    try {
      final outcome = await showMatchOutcomeSheet(
        context,
        match: state.match,
        suggested: state.suggestedOutcome,
      );
      if (outcome == null || !mounted) return;

      // Re-read the state: the clock can run out while the sheet is open, and
      // the match may have finished itself behind it. Deciding from the state
      // this sheet was *opened* with would call finishWith on an
      // already-finished match — a silent no-op — and the referee's answer
      // would simply vanish.
      final notifier = ref.read(matchControlProvider.notifier);
      if (ref.read(matchControlProvider).isFinished) {
        notifier.amendOutcome(outcome);
      } else {
        notifier.finishWith(outcome);
      }
    } finally {
      _askingOutcome = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControlProvider);
    final notifier = ref.read(matchControlProvider.notifier);

    // The clock ran out on a match the scoreboard cannot decide — a level
    // score, or a fighter on four penalties. Ask, rather than invent a winner.
    ref.listen(matchControlProvider, (previous, next) {
      if (next.awaitsOutcome && !(previous?.awaitsOutcome ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _askOutcome(next));
      }

      // Re-asserted on every change, not just when the match is decided. The
      // clock ticks this listener once a second, and that is what turns a
      // request the platform dropped into one that gets made again — asking
      // only at the two moments the answer changes would mean a hold that
      // failed on the way in stayed failed for the whole match. Repeats cost
      // nothing: the service only reaches for the platform when the state it
      // has differs from the state asked for.
      _syncWakelock(next);
    });
    final match = state.match;
    final colors = Theme.of(context).colorScheme;
    final f1Color = _hexToColor(match.f1Color, colors.outline);
    final f2Color = _hexToColor(match.f2Color, colors.outline);

    return PopScope(
      canPop: !state.isRunning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final railWidth =
                  (constraints.maxWidth * 0.18).clamp(96.0, 160.0);
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: railWidth,
                          child: _buildRail(
                            context,
                            state,
                            notifier,
                            fighter: 1,
                            color: f1Color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCenter(
                              context, state, notifier, f1Color, f2Color),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: railWidth,
                          child: _buildRail(
                            context,
                            state,
                            notifier,
                            fighter: 2,
                            color: f2Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Side rails ────────────────────────────────────────────────────────

  Widget _buildRail(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier, {
    required int fighter,
    required Color color,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final tk = ChokeTokens.of(context);
    final enabled = state.isRunning;

    return Column(
      children: [
        Expanded(
          flex: 13,
          child: _railButton(
            context,
            fighter: fighter,
            accent: color,
            enabled: enabled,
            points: '+2',
            label: l10n.takedownSweep,
            onTap: () => notifier.scorePt2(fighter),
            onHold: () => notifier.subtractPt2(fighter),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 13,
          child: _railButton(
            context,
            fighter: fighter,
            accent: color,
            enabled: enabled,
            points: '+3',
            label: l10n.guardPass,
            onTap: () => notifier.scorePt3(fighter),
            onHold: () => notifier.subtractPt3(fighter),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 13,
          child: _railButton(
            context,
            fighter: fighter,
            accent: color,
            enabled: enabled,
            points: '+4',
            label: l10n.mountBackTake,
            onTap: () => notifier.scorePt4(fighter),
            onHold: () => notifier.subtractPt4(fighter),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 10,
          child: _railButton(
            context,
            fighter: fighter,
            accent: tk.goldFg,
            enabled: enabled,
            label: l10n.advantage,
            onTap: () => notifier.scoreAdv(fighter),
            onHold: () => notifier.subtractAdv(fighter),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 10,
          child: _railButton(
            context,
            fighter: fighter,
            accent: colors.error,
            enabled: enabled,
            label: l10n.penalty,
            onTap: () => notifier.scorePen(fighter),
            onHold: () => notifier.subtractPen(fighter),
          ),
        ),
      ],
    );
  }

  Widget _railButton(
    BuildContext context, {
    required int fighter,
    required Color accent,
    required bool enabled,
    String? points,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onHold,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accentSide = BorderSide(color: accent, width: 4);
    // Accent bar faces the screen edge, where the operator's thumb rests
    final border =
        fighter == 1 ? Border(left: accentSide) : Border(right: accentSide);

    return HoldButton(
      enabled: enabled,
      accentColor: accent,
      holdFillColor: colors.error.withOpacity(.35),
      border: border,
      onTap: onTap,
      onHoldComplete: onHold,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (points != null)
              Text(
                points,
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    points != null ? colors.onSurface.withOpacity(.6) : accent,
                fontSize: points != null ? 9 : 13,
                fontWeight: points != null ? FontWeight.w500 : FontWeight.w600,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Center column ─────────────────────────────────────────────────────

  Widget _buildCenter(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier,
    Color f1Color,
    Color f2Color,
  ) {
    final match = state.match;

    return Column(
      children: [
        _buildHeader(context, state, notifier),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildScorePanel(
                  context,
                  name: match.f1Name,
                  // The effective score: a penalty against the opponent has
                  // already become points here, and seeing that jump is how the
                  // referee knows the penalty landed. The penalty badge below
                  // still shows the raw count — that is what *this* fighter was
                  // given.
                  score: match.f1EffectivePoints,
                  advantages: match.f1EffectiveAdvantages,
                  penalties: match.f1Pen,
                  color: f1Color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScorePanel(
                  context,
                  name: match.f2Name,
                  score: match.f2EffectivePoints,
                  advantages: match.f2EffectiveAdvantages,
                  penalties: match.f2Pen,
                  color: f2Color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildFooter(context, state, notifier),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final tk = ChokeTokens.of(context);
    final paused = state.isPaused;
    final isLow = state.remainingSeconds <= 30 && state.isRunning && !paused;

    // A stopped clock reads gold, so a glance at the time says whether it is
    // running — the scoring rails stay live either way.
    final clockColor =
        paused ? tk.goldFg : (isLow ? colors.error : colors.onSurface);
    final statusColor = paused ? tk.goldFg : _statusColor(state.match.status);
    final statusText =
        paused ? l10n.statusPaused : _statusLabel(l10n, state.match.status);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () => _onBack(context, state),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isRunning || state.isWaiting) ...[
                  _buildClockButton(context, state, notifier),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Text(
                          _formatTime(state.remainingSeconds),
                          style: TextStyle(
                            color: clockColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(.15),
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: statusColor.withOpacity(.4)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.matchId(state.match.id),
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: state.isPublishing
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.secondary,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Pause/resume control, sitting next to the clock it stops — fighters go
  /// off the mat, the referee stops the time and restarts it on the reset.
  Widget _buildClockButton(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final waiting = state.isWaiting;
    final paused = state.isPaused;
    // Before the match starts this same control begins it; once running it
    // pauses and resumes the clock. This lets the referee review the match
    // (fighter names, duration) before starting instead of a blocking overlay.
    final isPlay = waiting || paused;
    final accent = isPlay ? tk.goldFg : tk.accent;
    final label =
        waiting ? l10n.startMatch : (paused ? l10n.resume : l10n.pause);
    final onTap = waiting
        ? notifier.startMatch
        : (paused ? notifier.resumeMatch : notifier.pauseMatch);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withOpacity(.45)),
            ),
            child: Icon(
              isPlay ? Icons.play_arrow : Icons.pause,
              color: accent,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScorePanel(
    BuildContext context, {
    required String name,
    required int score,
    required int advantages,
    required int penalties,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 74,
                  height: 1.1,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('A:$advantages', ChokeTokens.of(context).goldFg),
              const SizedBox(width: 6),
              _buildBadge('P:$penalties', ChokeTokens.of(context).dangerFg),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    MatchControlState state,
    MatchControlNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    // A finished or canceled match is read-only: replace the scoring controls
    // with a status indicator instead of showing disabled buttons.
    if (state.isFinished) return _buildReadOnlyFooter(context, state);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: OutlinedButton.icon(
              onPressed: state.canUndo ? notifier.undo : null,
              icon: const Icon(Icons.undo, size: 16),
              label: Text(
                l10n.undoLastAction,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: colors.onSurface.withOpacity(.25)),
                foregroundColor: colors.onSurface.withOpacity(.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: HoldButton(
              enabled: state.isRunning,
              accentColor: colors.primary,
              backgroundColor: Colors.transparent,
              border: Border.all(color: colors.primary.withOpacity(.5)),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              onHoldComplete: () => _askOutcome(state),
              child: Text(
                '${l10n.finish} · ${l10n.holdHint}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: HoldButton(
              // Cancelling is allowed before the match starts too, so a match
              // created with a wrong name, color or duration can be scrapped
              // without having to start it first.
              enabled: state.isRunning || state.isWaiting,
              accentColor: colors.error,
              backgroundColor: Colors.transparent,
              border: Border.all(color: colors.error.withOpacity(.5)),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              onHoldComplete: notifier.cancelMatch,
              child: Text(
                '${l10n.cancel} · ${l10n.holdHint}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown in place of the scoring controls once a match is finished or
  /// canceled. It says *how* it ended — a score row alone would show the loser
  /// of a submission with the bigger numbers — and offers to correct it.
  Widget _buildReadOnlyFooter(BuildContext context, MatchControlState state) {
    final l10n = AppLocalizations.of(context);
    final tk = ChokeTokens.of(context);
    final finished = state.match.status == MatchStatus.finished;
    final accent = finished ? tk.statusFinishedFg : tk.dangerFg;

    final outcome = describeOutcome(l10n, state.match);
    final label =
        outcome ?? (finished ? l10n.matchFinished : l10n.matchCanceled);

    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: accent.withValues(alpha: .4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    finished
                        ? Icons.emoji_events_outlined
                        : Icons.cancel_outlined,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // A result the clock got wrong would otherwise stay wrong forever.
          // Canceled matches are not results, so there is nothing to amend.
          if (finished) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _askOutcome(state),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: Text(
                l10n.outcomeAmend,
                style: const TextStyle(fontSize: 11),
              ),
              style: TextButton.styleFrom(foregroundColor: tk.faint),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Navigation & status helpers ───────────────────────────────────────

  void _onBack(BuildContext context, MatchControlState state) {
    if (state.isRunning) {
      _confirmLeave(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _confirmLeave(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.leaveMatchQuestion),
        content: Text(l10n.leaveMatchDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.stay),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.leave,
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(MatchStatus status) {
    final tk = ChokeTokens.of(context);
    return switch (status) {
      MatchStatus.waiting => tk.goldFg,
      MatchStatus.inProgress => tk.accent,
      MatchStatus.finished => tk.statusFinishedFg,
      MatchStatus.canceled => tk.dangerFg,
    };
  }

  String _statusLabel(AppLocalizations l10n, MatchStatus status) {
    return switch (status) {
      MatchStatus.waiting => l10n.statusWaiting,
      MatchStatus.inProgress => l10n.statusInProgress,
      MatchStatus.finished => l10n.statusFinished,
      MatchStatus.canceled => l10n.statusCanceled,
    };
  }
}
