import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';

import 'board_palette.dart';
import '../../services/wakelock/screen_wakelock.dart';
import '../../shared/wall_clock.dart';
import '../../shared/widgets/match_card.dart';
import '../match/models/match.dart';
import '../match/models/submission_catalog.dart';
import '../match/widgets/outcome_label.dart';
import 'providers/scoreboard_providers.dart';

/// The wall display: one match, big enough to read from across a mat.
///
/// Landscape only. The layout is two halves side by side, one per fighter, and
/// there is no honest way to fold that into a portrait phone — so the screen asks
/// for the orientation it needs, the way a video player does, and gives it back
/// on the way out.
///
/// Strictly read-only. It renders what the relays say and has no way to change
/// it; the match belongs to whoever is refereeing it somewhere else.
class ScoreboardMatchScreen extends ConsumerStatefulWidget {
  const ScoreboardMatchScreen({super.key, required this.matchId});

  /// Looked up by id on every build rather than passed in whole, so the screen
  /// re-renders as revisions arrive. Handing it a [Match] would freeze the match
  /// at the moment it was tapped.
  final String matchId;

  @override
  ConsumerState<ScoreboardMatchScreen> createState() =>
      _ScoreboardMatchScreenState();
}

class _ScoreboardMatchScreenState extends ConsumerState<ScoreboardMatchScreen> {
  /// Held onto from [initState] because [dispose] runs once `ref` is no longer
  /// usable, and releasing the screen is the one thing that must still happen.
  late final ScreenWakelockLease _wakelock;

  Timer? _ticker;

  /// Now, in unix seconds, advanced once a second so the clock counts down.
  ///
  /// The match carries no clock — [Match.remainingSecondsAt] derives it — so
  /// ticking "now" is the whole animation.
  int _now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Held for as long as a match is on this screen, whatever it is doing.
    //
    // Unconditional on match *state*, where the control screen's hold is not,
    // because the two wait differently. A referee's screen releases once the
    // match is decided — the result sits on the scorer's table. A spectator's
    // board is the opposite: the quiet stretches are the point. Before the
    // first bell they are waiting for the start; a minute of stalling is when
    // nobody is touching the phone; and a finished board is left up to be read
    // across a room.
    //
    // Conditional on the match *existing*, though. When it ages out of the
    // feed this screen is a dead end saying so, and a dead end is the page
    // most likely to be left face-up on a table overnight — the one place
    // pinning the display serves nobody.
    _wakelock = ref.read(screenWakelockProvider).lease();
    _syncWakelock();

    _scheduleTick();
  }

  /// One tick per wall-clock second, scheduled against the *next* boundary
  /// each time rather than periodically from an arbitrary phase.
  ///
  /// This screen's display lags the derived truth by its tick phase — the
  /// truncation of "now" IS the flip, and the phase measures from it — so
  /// boundary alignment takes that phase from up-to-a-second down to the
  /// guard. What separates two screens after this is each device's clock
  /// skew, plus whatever phase the *other* screen still carries.
  ///
  /// Re-deriving the delay every tick also self-corrects: a tick the platform
  /// delivered late — background throttling, a busy frame — schedules the
  /// next one against reality instead of compounding the drift. A late tick
  /// therefore paints the *current* second and the display can visibly skip
  /// one; that is chosen, not a bug — the alternative was a burst of stale
  /// repaints saying nothing true.
  void _scheduleTick() {
    _ticker = Timer(
      untilNextClockFlip(DateTime.now().millisecondsSinceEpoch),
      () {
        if (!mounted) return;
        // Re-voted on the tick, not trusted to the first call: a request the
        // platform dropped — no foreground activity yet, a transient refusal —
        // would otherwise stay dropped for the whole match. Repeats cost
        // nothing; the service only reaches the platform when what it holds
        // differs from what is asked.
        _syncWakelock();
        setState(() => _now = DateTime.now().millisecondsSinceEpoch ~/ 1000);
        _scheduleTick();
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    unawaited(_wakelock.release());
    super.dispose();
  }

  /// Vote to hold the screen exactly while the watched match is in the feed.
  void _syncWakelock() {
    final present = ref
        .read(scoreboardMatchesProvider)
        .any((m) => m.id == widget.matchId);
    unawaited(_wakelock.keepAwake(present));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched whole, deliberately not select()ed. A select here compares the
    // chosen Match with ==, and Match's equality is intentionally partial — it
    // omits status, startAt and pausedAt among others — so a waiting match
    // that started with the score unchanged compared equal to its past self
    // and Riverpod kept serving the stale one: the board sat on WAITING while
    // the fight ran. The rebuild this "wastes" is noise the once-a-second
    // ticker already pays for.
    final matches = ref.watch(scoreboardMatchesProvider);
    final match = matches.where((m) => m.id == widget.matchId).firstOrNull;

    final palette = BoardPalette.of(context);

    if (match == null) return _buildGone(l10n, palette);

    return Scaffold(
      backgroundColor: palette.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Everything scales off the height, so the board reads the same on a
          // phone held sideways and on a tablet.
          final unit = constraints.maxHeight / 100;
          return Stack(
            children: [
              _buildHalf(context, l10n, match, unit, isF1: true),
              _buildHalf(context, l10n, match, unit, isF1: false),
              _buildLoserDim(match, palette),
              _buildCenter(context, l10n, match, unit),
              // Under the banner in the stack, deliberately: a room reads the
              // announcement of who won, and nothing may sit over it.
              _buildCredit(l10n, unit, palette),
              _buildWinnerBanner(context, l10n, match, unit),
              _buildBack(l10n, palette),
            ],
          );
        },
      ),
    );
  }

  // ─── Fighter halves ─────────────────────────────────────────────────────

  Widget _buildHalf(
    BuildContext context,
    AppLocalizations l10n,
    Match match,
    double unit, {
    required bool isF1,
  }) {
    final palette = BoardPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final color = hexToColor(
      isF1 ? match.f1Color : match.f2Color,
      colors.outline,
    );
    final name = isF1 ? match.f1Name : match.f2Name;
    final score = isF1 ? match.f1EffectivePoints : match.f2EffectivePoints;
    final adv =
        isF1 ? match.f1EffectiveAdvantages : match.f2EffectiveAdvantages;
    final pen = isF1 ? match.f1Pen : match.f2Pen;
    final breakdown = isF1
        ? [match.f1Pt2, match.f1Pt3, match.f1Pt4]
        : [match.f2Pt2, match.f2Pt3, match.f2Pt4];

    return Align(
      alignment: isF1 ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: Stack(
          children: [
            // Colour wash, fading toward the middle of the screen.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isF1 ? Alignment.centerLeft : Alignment.centerRight,
                  end: isF1 ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    color.withValues(alpha: palette.halfWashStrong),
                    color.withValues(alpha: palette.halfWashFade),
                    Colors.transparent,
                  ],
                  stops: [0, palette.halfWashFadeStop, palette.halfWashEndStop],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            // The edge bar, and its glow.
            Align(
              alignment: isF1 ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 11,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: palette.edgeGlowAlpha),
                      blurRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isF1 ? unit * 4 : unit * 2,
                unit * 5,
                isF1 ? unit * 2 : unit * 4,
                unit * 5,
              ),
              child: Column(
                children: [
                  _buildName(name, color, unit, palette),
                  Expanded(
                    child: Center(
                      child: _buildScore(score, color, unit, palette),
                    ),
                  ),
                  _buildBreakdown(l10n, breakdown, unit, palette),
                  SizedBox(height: unit * 2.5),
                  _buildChips(l10n, adv, pen, unit, palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildName(
      String name, Color color, double unit, BoardPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: unit * 2.6,
          height: unit * 2.6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: palette.dotGlowAlpha),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        SizedBox(width: unit * 1.4),
        Flexible(
          child: Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w800,
              fontSize: (unit * 7).clamp(14.0, 58.0),
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScore(
      int score, Color color, double unit, BoardPalette palette) {
    return Text(
      '$score',
      style: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
        fontSize: (unit * 30).clamp(48.0, 232.0),
        height: 1,
        shadows: [
          Shadow(
            color: color.withValues(alpha: palette.scoreGlowAlpha),
            blurRadius: 55,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(AppLocalizations l10n, List<int> counts, double unit,
      BoardPalette palette) {
    const values = [2, 3, 4];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) SizedBox(width: unit * 4),
          Column(
            children: [
              Text(
                l10n.scoreboardPointsShort(values[i]),
                style: TextStyle(
                  color: palette.label,
                  fontWeight: FontWeight.bold,
                  fontSize: (unit * 2).clamp(9.0, 19.0),
                  letterSpacing: 1.6,
                ),
              ),
              SizedBox(height: unit),
              Text(
                '${counts[i]}',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                  fontSize: (unit * 4).clamp(16.0, 36.0),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChips(AppLocalizations l10n, int adv, int pen, double unit,
      BoardPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCountChip(
          l10n.scoreboardAdvShort,
          adv,
          palette.advLabel,
          palette.advValue,
          palette.advSurface,
          unit,
          palette,
        ),
        SizedBox(width: unit * 1.6),
        _buildCountChip(
          l10n.scoreboardPenShort,
          pen,
          palette.penLabel,
          palette.penValue,
          palette.penSurface,
          unit,
          palette,
        ),
      ],
    );
  }

  Widget _buildCountChip(
    String label,
    int count,
    Color labelColor,
    Color countColor,
    Color surface,
    double unit,
    BoardPalette palette,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit * 1.1),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: palette.chipFillAlpha),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: surface.withValues(alpha: palette.chipBorderAlpha),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.bold,
              fontSize: (unit * 2.5).clamp(11.0, 24.0),
              letterSpacing: 1,
            ),
          ),
          SizedBox(width: unit * .9),
          Text(
            '$count',
            style: TextStyle(
              color: countColor,
              fontWeight: FontWeight.w800,
              fontSize: (unit * 2.8).clamp(12.0, 27.0),
            ),
          ),
        ],
      ),
    );
  }

  /// Dim the half belonging to whoever lost, once somebody has.
  Widget _buildLoserDim(Match match, BoardPalette palette) {
    final winner = match.winner;
    if (winner == null || match.status != MatchStatus.finished) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: winner == MatchWinner.f1
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: ColoredBox(
          color: palette.loserVeil,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ─── Centre column ──────────────────────────────────────────────────────

  Widget _buildCenter(
    BuildContext context,
    AppLocalizations l10n,
    Match match,
    double unit,
  ) {
    final palette = BoardPalette.of(context);
    final showTimer = match.status == MatchStatus.waiting ||
        match.status == MatchStatus.inProgress;

    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        widthFactor: 0.28,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: unit * 5),
          child: Column(
            children: [
              _buildStatusPill(context, l10n, match, unit),
              Expanded(
                child: showTimer
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimerCard(l10n, match, unit, palette),
                          SizedBox(height: unit * 3),
                          Text(
                            l10n.vs.toUpperCase(),
                            style: TextStyle(
                              color: palette.vs,
                              fontWeight: FontWeight.w800,
                              fontSize: (unit * 3.4).clamp(14.0, 32.0),
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    BuildContext context,
    AppLocalizations l10n,
    Match match,
    double unit,
  ) {
    final palette = BoardPalette.of(context);
    final colors = Theme.of(context).colorScheme;

    // A finished match speaks in the winner's colour, so the pill and the banner
    // agree with each other at a glance.
    final (label, color) = switch (match) {
      Match(isPaused: true) => (l10n.statusPaused, palette.paused),
      Match(status: MatchStatus.waiting) => (l10n.statusWaiting, palette.waiting),
      Match(status: MatchStatus.inProgress) => (
          l10n.statusInProgress,
          palette.liveText,
        ),
      Match(status: MatchStatus.canceled) => (
          l10n.statusCanceled,
          palette.canceled,
        ),
      _ => (
          l10n.statusFinished,
          switch (match.winner) {
            MatchWinner.f1 => hexToColor(match.f1Color, colors.outline),
            MatchWinner.f2 => hexToColor(match.f2Color, colors.outline),
            null => palette.neutralWinner,
          },
        ),
    };

    // Only a finished match wears a colour that came off the wire, so it is the
    // only one that needs darkening to survive a light background. Every other
    // pill is a colour this palette chose for this theme, and putting one of
    // those through `readable` darkens it a second time.
    final isFinished = match.status == MatchStatus.finished;
    final word = isFinished ? palette.readable(color) : color;

    // A running match draws its surface from a different green than its word:
    // the word carries the contrast, the surface stays quiet.
    final surface = switch (match.status) {
      MatchStatus.inProgress when !match.isPaused => palette.liveSurface,
      _ => color,
    };

    final isRunning = match.status == MatchStatus.inProgress && !match.isPaused;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: unit * 2.4, vertical: unit),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: palette.pillFillAlpha),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: surface.withValues(alpha: palette.pillBorderAlpha),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(
            color: surface,
            blinking: isRunning,
            size: unit * 1.6,
            glowAlpha: palette.pillDotGlowAlpha,
          ),
          SizedBox(width: unit * 1.2),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: word,
                fontWeight: FontWeight.bold,
                fontSize: (unit * 2.5).clamp(10.0, 24.0),
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(AppLocalizations l10n, Match match, double unit,
      BoardPalette palette) {
    final remaining = match.remainingSecondsAt(_now);
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: unit * 3, vertical: unit * 2.5),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: palette.cardShadowBlur,
            offset: palette.cardShadowOffset,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.scoreboardTime,
            style: TextStyle(
              color: palette.label,
              fontWeight: FontWeight.bold,
              fontSize: (unit * 1.8).clamp(9.0, 17.0),
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: unit * 1.5),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w800,
              fontSize: (unit * 9).clamp(28.0, 76.0),
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Result ─────────────────────────────────────────────────────────────

  /// Who won, and how, over the middle of the board.
  ///
  /// The winner comes from the event and is never derived from the numbers: a
  /// fighter can lead 5–2 and lose to an armbar, and this banner is read by a
  /// room full of people.
  Widget _buildWinnerBanner(
    BuildContext context,
    AppLocalizations l10n,
    Match match,
    double unit,
  ) {
    if (match.status != MatchStatus.finished) return const SizedBox.shrink();

    final method = match.method;
    if (method == null) return const SizedBox.shrink();

    final palette = BoardPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final winner = match.winner;
    final color = switch (winner) {
      MatchWinner.f1 => hexToColor(match.f1Color, colors.outline),
      MatchWinner.f2 => hexToColor(match.f2Color, colors.outline),
      null => palette.neutralWinner,
    };
    // 3A keeps the border and the fill in the fighter's own colour and darkens
    // only what carries words, which is what makes a bright gi colour legible
    // on white without changing the colour the room recognises.
    final word = palette.readable(color);
    final detail = _detailOf(l10n, match);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: unit * 86),
        padding:
            EdgeInsets.symmetric(horizontal: unit * 5, vertical: unit * 3.5),
        decoration: BoxDecoration(
          // Its own surface, not the clock card's. The card is a faint panel the
          // board shows through; this has to be opaque enough that the fighter
          // washes do not come through the announcement of who won.
          color: palette.bannerSurface,
          borderRadius: BorderRadius.circular(22),
          border: palette.bannerOutlined
              ? Border.all(color: color.withValues(alpha: palette.pillBorderAlpha))
              : null,
          boxShadow: palette.bannerOutlined
              ? [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: palette.cardShadowBlur,
                    offset: palette.cardShadowOffset,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (winner == null ? l10n.scoreboardResult : l10n.scoreboardWinner)
                  .toUpperCase(),
              style: TextStyle(
                color: palette.label,
                fontWeight: FontWeight.bold,
                fontSize: (unit * 2.5).clamp(10.0, 24.0),
                letterSpacing: 3.6,
              ),
            ),
            if (winner != null) ...[
              SizedBox(height: unit * 2),
              Text(
                (winner == MatchWinner.f1 ? match.f1Name : match.f2Name)
                    .toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: word,
                  fontWeight: FontWeight.w800,
                  fontSize: (unit * 12).clamp(24.0, 86.0),
                  height: 1,
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: palette.scoreGlowAlpha),
                      blurRadius: 46,
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: unit * 2),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: unit * 3,
                vertical: unit * 1.6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: palette.chipFillAlpha),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: palette.pillBorderAlpha),
                ),
              ),
              child: Text(
                methodLabel(l10n, method).toUpperCase(),
                style: TextStyle(
                  color: word,
                  fontWeight: FontWeight.w800,
                  fontSize: (unit * 3.4).clamp(14.0, 32.0),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (detail != null) ...[
              SizedBox(height: unit * 2),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.label,
                  fontWeight: FontWeight.w600,
                  fontSize: (unit * 2.6).clamp(11.0, 25.0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The line under the method chip: which submission, or what the referee wrote
  /// about a disqualification. Null when the method already says everything.
  String? _detailOf(AppLocalizations l10n, Match match) {
    final submission = match.submission;
    if (submission != null && submission.isNotEmpty) {
      return labelFor(l10n, submission);
    }

    final dqDetail = match.dqDetail;
    if (dqDetail != null && dqDetail.isNotEmpty) return dqDetail;

    return null;
  }

  // ─── Chrome ─────────────────────────────────────────────────────────────

  /// Where the board came from, along the bottom edge.
  ///
  /// Every match projected on a wall is watched for its whole length by a room
  /// full of people who could run their own board, and none of them are holding
  /// the phone. So this is a line of text and nothing else: no tap target, no
  /// link — it is read across a room, not pressed.
  ///
  /// [BoardPalette.label] is the palette's own word for "explanation": the
  /// colour the column headers are drawn in, chosen in both themes to be read
  /// after the score rather than with it. That is exactly this line's rank.
  Widget _buildCredit(
      AppLocalizations l10n, double unit, BoardPalette palette) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(unit * 4, 0, unit * 4, unit * 1.5),
          child: Text(
            l10n.boardLiveCredit,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.label,
              // Scaled off the board's unit like everything else, so it reads
              // the same on a phone held sideways and on a projector, and
              // clamped so it never grows into the score or vanishes under it.
              fontSize: (unit * 1.9).clamp(9.0, 20.0),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBack(AppLocalizations l10n, BoardPalette palette) {
    return Positioned(
      top: 8,
      left: 8,
      child: SafeArea(
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 18),
          label: Text(l10n.goBack),
          style: TextButton.styleFrom(
            foregroundColor: palette.backLabel,
          ),
        ),
      ),
    );
  }

  /// The match aged out of the feed, or the relays never had it.
  ///
  /// It can happen while this screen is open: the feed keeps a day, and a board
  /// left running overnight will watch a match disappear out from under it.
  Widget _buildGone(AppLocalizations l10n, BoardPalette palette) {
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 44, color: palette.label),
              const SizedBox(height: 14),
              Text(
                l10n.scoreboardEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.label,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.goBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status dot, which pulses only while a match is actually running.
///
/// A paused or finished match holds still: a blinking light says "this is
/// happening now", and it must not say that when it is not.
class _StatusDot extends StatefulWidget {
  const _StatusDot({
    required this.color,
    required this.blinking,
    required this.size,
    required this.glowAlpha,
  });

  final Color color;
  final bool blinking;
  final double size;

  /// Zero on a light board: a blur under a saturated colour on near-white is a
  /// smudge, and this is the one thing here that moves.
  final double glowAlpha;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Built unconditionally, and here. A lazy `late final` would go unbuilt for a
    // dot that never blinks — every finished match — and then be constructed by
    // `dispose` reaching for `_controller`, which creates a ticker against an
    // ancestor that is already gone and takes the rest of the teardown with it.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.blinking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.blinking == old.blinking) return;
    if (widget.blinking) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size.clamp(8.0, 14.0);
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: widget.glowAlpha == 0
            ? null
            : [
                BoxShadow(
                  color: widget.color.withValues(alpha: widget.glowAlpha),
                  blurRadius: 14,
                ),
              ],
      ),
    );

    if (!widget.blinking) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: .35).animate(_controller),
      child: dot,
    );
  }
}
