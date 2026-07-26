import 'dart:convert';
import 'dart:math';
import '../../../services/nostr/nostr_service.dart';

/// Sentinel value for distinguishing "not provided" from "null" in copyWith
const _sentinel = Object();

/// Represents the status of a BJJ match
enum MatchStatus {
  waiting,
  inProgress,
  finished,
  canceled;

  /// Convert enum to kebab-case JSON string
  String toJson() {
    return switch (this) {
      MatchStatus.waiting => 'waiting',
      MatchStatus.inProgress => 'in-progress',
      MatchStatus.finished => 'finished',
      MatchStatus.canceled => 'canceled',
    };
  }

  /// Convert kebab-case JSON string to enum
  static MatchStatus fromJson(String json) {
    return switch (json) {
      'waiting' => MatchStatus.waiting,
      'in-progress' => MatchStatus.inProgress,
      'finished' => MatchStatus.finished,
      'canceled' => MatchStatus.canceled,
      _ => throw FormatException('Unknown MatchStatus: $json'),
    };
  }
}

/// Who won a match.
///
/// There is no `draw` here on purpose. A draw is [MatchMethod.draw] with **no**
/// winner — encoding it twice would let an event claim `winner: "f1"` and
/// `method: "draw"` at once, and every consumer would resolve that
/// contradiction differently. One fact, one field.
enum MatchWinner {
  f1,
  f2;

  String toJson() => name;

  static MatchWinner? fromJson(Object? json) {
    return switch (json) {
      null => null,
      'f1' => MatchWinner.f1,
      'f2' => MatchWinner.f2,
      _ => throw FormatException('Unknown winner: $json'),
    };
  }
}

/// How a match was won.
///
/// Three of these beat the scoreboard outright — [submission], [dq] and
/// [forfeit]. The fighter who was ahead can still lose, which is the whole
/// reason this exists: a match that ends on a submission and says only
/// "finished" publishes a scoreboard naming the wrong winner.
///
/// Note there is no `penalties`. Penalties are not a way to win: they have
/// already become advantages and points (see [Match.f1EffectivePoints]), so
/// counting them again would count the same penalty twice.
enum MatchMethod {
  /// The opponent tapped, submitted verbally, or the referee stopped it.
  submission,

  /// The clock ran out and one fighter had more points.
  points,

  /// Points were level; advantages decided it.
  advantages,

  /// Points and advantages were level, and the referees named a winner.
  decision,

  /// The **loser** was disqualified.
  dq,

  /// The loser withdrew, no-showed, or could not continue.
  forfeit,

  /// Points and advantages were level and the referees called it even. No
  /// winner.
  draw;

  String toJson() => name;

  static MatchMethod? fromJson(Object? json) {
    if (json == null) return null;
    for (final method in MatchMethod.values) {
      if (method.name == json) return method;
    }
    throw FormatException('Unknown method: $json');
  }

  /// Whether this method decides the match regardless of the scoreboard.
  bool get overridesScoreboard =>
      this == submission || this == dq || this == forfeit;
}

/// Why a fighter was disqualified.
///
/// The categories are standard; the infractions are not. Whether a knee reap is
/// illegal depends on the ruleset, the belt and the age division, and ADCC's
/// list differs from the IBJJF's again — so what actually happened goes in
/// [Match.dqDetail] as free text, and only the category is enumerated here.
enum DqReason {
  /// The fourth penalty. The app never raises this by itself: the referee ends
  /// the match, and the app offers this as what the scoreboard already says.
  accumulatedPenalties,

  /// Severe technical foul — illegal technique, illegal grip, improper attire.
  /// Disqualified from the **match**.
  technicalFoul,

  /// Severe disciplinary foul — unsportsmanlike conduct. Disqualified from the
  /// **competition**.
  disciplinaryFoul;

  String toJson() {
    return switch (this) {
      DqReason.accumulatedPenalties => 'accumulated_penalties',
      DqReason.technicalFoul => 'technical_foul',
      DqReason.disciplinaryFoul => 'disciplinary_foul',
    };
  }

  static DqReason? fromJson(Object? json) {
    return switch (json) {
      null => null,
      'accumulated_penalties' => DqReason.accumulatedPenalties,
      'technical_foul' => DqReason.technicalFoul,
      'disciplinary_foul' => DqReason.disciplinaryFoul,
      _ => throw FormatException('Unknown dq_reason: $json'),
    };
  }
}

/// Represents a BJJ match with scoring data
///
/// Maps to Nostr event kind 31415 (addressable events) with the following
/// content schema:
/// ```json
/// {
///   "id": "abcd",
///   "status": "waiting | in-progress | finished | canceled",
///   "start_at": 123456789,
///   "paused_at": 123456889,
///   "duration": 300,
///   "f1_name": "string",
///   "f2_name": "string",
///   "f1_color": "#RRGGBB",
///   "f2_color": "#RRGGBB",
///   "f1_pt2": 0, "f2_pt2": 0,
///   "f1_pt3": 0, "f2_pt3": 0,
///   "f1_pt4": 0, "f2_pt4": 0,
///   "f1_adv": 0, "f2_adv": 0,
///   "f1_pen": 0, "f2_pen": 0,
///
///   "winner": "f1 | f2",
///   "method": "submission | points | advantages | decision | dq | forfeit | draw",
///   "submission": "armbar",
///   "dq_reason": "accumulated_penalties | technical_foul | disciplinary_foul",
///   "dq_detail": "knee reap",
///   "ended_at": 123456889
/// }
/// ```
///
/// The outcome fields are absent from every event published before they
/// existed, so a consumer must tolerate their absence forever. An event this
/// app writes for a finished match always carries `method` and `ended_at`, and
/// a `winner` unless the match was drawn.
///
/// See docs/specs/match-outcome.md.
class Match {
  /// 4-character hex identifier for the match
  final String id;

  /// Current status of the match
  final MatchStatus status;

  /// Unix timestamp when the match started (seconds since epoch)
  final int? startAt;

  /// Unix timestamp when the clock was stopped (seconds since epoch), or null
  /// when the clock is running.
  ///
  /// A paused match is still [MatchStatus.inProgress]: the fighters are off
  /// the mat, not done. While this is set the clock reads as it did at this
  /// instant, so paused seconds never come off the match time. Resuming moves
  /// [startAt] forward by the length of the stoppage and clears this.
  final int? pausedAt;

  /// Match duration in seconds
  final int duration;

  /// Fighter 1 name
  final String f1Name;

  /// Fighter 2 name
  final String f2Name;

  /// Fighter 1 gi color (hex format #RRGGBB)
  final String f1Color;

  /// Fighter 2 gi color (hex format #RRGGBB)
  final String f2Color;

  /// Fighter 1 takedown/sweep count (+2 points each)
  final int f1Pt2;

  /// Fighter 2 takedown/sweep count (+2 points each)
  final int f2Pt2;

  /// Fighter 1 guard pass count (+3 points each)
  final int f1Pt3;

  /// Fighter 2 guard pass count (+3 points each)
  final int f2Pt3;

  /// Fighter 1 mount/back take count (+4 points each)
  final int f1Pt4;

  /// Fighter 2 mount/back take count (+4 points each)
  final int f2Pt4;

  /// Fighter 1 advantage count
  final int f1Adv;

  /// Fighter 2 advantage count
  final int f2Adv;

  /// Fighter 1 penalty count
  final int f1Pen;

  /// Fighter 2 penalty count
  final int f2Pen;

  /// Who won. Null while the match is unfinished, when it was canceled, and
  /// when it was a draw — a draw is [MatchMethod.draw] with no winner.
  final MatchWinner? winner;

  /// How the match was won. Null on a match that has not ended, and on every
  /// event published before outcomes existed (see [isLegacyResult]).
  final MatchMethod? method;

  /// The submission, as free text: 'armbar', 'rear naked choke'. Only
  /// meaningful with [MatchMethod.submission], and always optional — a referee
  /// must never be blocked from ending a match because the app has never heard
  /// of a baratoplata.
  final String? submission;

  /// Why the loser was disqualified. Required when [method] is
  /// [MatchMethod.dq].
  final DqReason? dqReason;

  /// What the disqualified fighter actually did: 'knee reap', 'slam'. Free
  /// text, always optional — the categories are standard, the infractions are
  /// not.
  final String? dqDetail;

  /// When the match ended, in unix seconds.
  ///
  /// Not derivable: `startAt + duration` is when the clock *would* have run
  /// out, which is exactly what a submission prevents.
  final int? endedAt;

  static const _hexChars = '0123456789abcdef';
  static final _random = Random.secure();

  Match({
    required this.id,
    required this.status,
    this.startAt,
    this.pausedAt,
    required this.duration,
    required this.f1Name,
    required this.f2Name,
    required this.f1Color,
    required this.f2Color,
    this.f1Pt2 = 0,
    this.f2Pt2 = 0,
    this.f1Pt3 = 0,
    this.f2Pt3 = 0,
    this.f1Pt4 = 0,
    this.f2Pt4 = 0,
    this.f1Adv = 0,
    this.f2Adv = 0,
    this.f1Pen = 0,
    this.f2Pen = 0,
    this.winner,
    this.method,
    this.submission,
    this.dqReason,
    this.dqDetail,
    this.endedAt,
  }) {
    _validate();
  }

  /// Generate a new random 4-character hex match ID
  static String _generateMatchId() {
    return List.generate(4, (_) => _hexChars[_random.nextInt(16)]).join();
  }

  /// Create a new match with auto-generated ID
  factory Match.create({
    required String f1Name,
    required String f2Name,
    required String f1Color,
    required String f2Color,
    required int duration,
    MatchStatus status = MatchStatus.waiting,
    int? startAt,
  }) {
    return Match(
      id: _generateMatchId(),
      status: status,
      startAt: startAt,
      duration: duration,
      f1Name: f1Name,
      f2Name: f2Name,
      f1Color: f1Color,
      f2Color: f2Color,
    );
  }

  /// Validate all fields
  void _validate() {
    // Validate match_id: must be exactly 4 hex characters
    if (id.length != 4) {
      throw FormatException('Match ID must be exactly 4 characters, got: $id');
    }
    if (!RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(id)) {
      throw FormatException('Match ID must be valid hex, got: $id');
    }

    // Validate duration is non-negative
    if (duration < 0) {
      throw FormatException('Duration must be non-negative, got: $duration');
    }

    // Validate all counter fields are non-negative
    final counters = {
      'f1Pt2': f1Pt2,
      'f2Pt2': f2Pt2,
      'f1Pt3': f1Pt3,
      'f2Pt3': f2Pt3,
      'f1Pt4': f1Pt4,
      'f2Pt4': f2Pt4,
      'f1Adv': f1Adv,
      'f2Adv': f2Adv,
      'f1Pen': f1Pen,
      'f2Pen': f2Pen,
    };

    for (final entry in counters.entries) {
      if (entry.value < 0) {
        throw FormatException(
          '${entry.key} must be non-negative, got: ${entry.value}',
        );
      }
    }

    // Validate hex colors
    final colorPattern = RegExp(r'^#[0-9a-fA-F]{6}$');
    if (!colorPattern.hasMatch(f1Color)) {
      throw FormatException(
        'f1Color must be valid hex color (#RRGGBB), got: $f1Color',
      );
    }
    if (!colorPattern.hasMatch(f2Color)) {
      throw FormatException(
        'f2Color must be valid hex color (#RRGGBB), got: $f2Color',
      );
    }

    // Validate start_at if present
    if (startAt != null && startAt! < 0) {
      throw FormatException(
        'startAt must be non-negative if provided, got: $startAt',
      );
    }

    // An outcome has to be internally consistent, or it is worse than none:
    // a consumer would have to guess which half of it to believe.
    if (method == MatchMethod.draw && winner != null) {
      throw const FormatException(
        'A draw has no winner: method "draw" with a winner is a contradiction',
      );
    }
    if (method != null && method != MatchMethod.draw && winner == null) {
      throw FormatException(
        'method "${method!.toJson()}" needs a winner',
      );
    }
    if (winner != null && method == null) {
      throw const FormatException(
        'a winner without a method says who won but not what they won by',
      );
    }
    if (method == MatchMethod.dq && dqReason == null) {
      throw const FormatException('method "dq" needs a dq_reason');
    }
    if (dqReason != null && method != MatchMethod.dq) {
      throw const FormatException('dq_reason without method "dq"');
    }
    if (method != null && endedAt == null) {
      throw const FormatException('a match with an outcome needs an ended_at');
    }
    if (endedAt != null) {
      if (endedAt! < 0) {
        throw FormatException('endedAt must be non-negative, got: $endedAt');
      }
      // A match cannot have ended before it began.
      if (startAt != null && endedAt! < startAt!) {
        throw FormatException(
          'endedAt ($endedAt) cannot precede startAt ($startAt)',
        );
      }
    }

    // A clock can only be stopped after it started
    if (pausedAt != null) {
      if (pausedAt! < 0) {
        throw FormatException(
          'pausedAt must be non-negative if provided, got: $pausedAt',
        );
      }
      if (startAt == null || pausedAt! < startAt!) {
        throw FormatException(
          'pausedAt ($pausedAt) cannot precede startAt ($startAt)',
        );
      }
    }
  }

  /// Seconds left on the clock as of [nowSeconds] (unix seconds).
  ///
  /// The clock is derived, never stored, so that everyone reading this match —
  /// the referee scoring it, a spectator watching it on the scoreboard — gets
  /// the same time out of the same event without either of them counting.
  ///
  /// A stoppage is charged to [startAt], which moves forward by its length, so
  /// elapsed time is simply now minus start. While [pausedAt] is set the clock
  /// reads what it read when it stopped.
  int remainingSecondsAt(int nowSeconds) {
    if (status == MatchStatus.waiting) return duration;
    if (startAt == null || startAt == 0) return duration;

    final elapsed = (pausedAt ?? nowSeconds) - startAt!;
    return (duration - elapsed).clamp(0, duration);
  }

  /// The match is under way but its clock is stopped.
  bool get isPaused => status == MatchStatus.inProgress && pausedAt != null;

  /// Calculate total score for fighter 1
  /// Formula: pt2*2 + pt3*3 + pt4*4
  int get f1Score => f1Pt2 * 2 + f1Pt3 * 3 + f1Pt4 * 4;

  /// Calculate total score for fighter 2
  /// Formula: pt2*2 + pt3*3 + pt4*4
  int get f2Score => f2Pt2 * 2 + f2Pt3 * 3 + f2Pt4 * 4;

  /// True for a match that ended before outcomes existed: finished (or
  /// canceled), and silent about how.
  ///
  /// Such an event was refereed by an app that applied no penalty consequences
  /// at all, so applying them now would **rewrite a result that has already
  /// been seen** — a match won 2–0 while the loser carried three penalties
  /// becomes 2–2, goes to advantages, and can flip. Leaving an old result
  /// showing the scoreboard it showed at the time is at worst incomplete;
  /// rewriting it asserts something new about a match nobody re-refereed.
  ///
  /// A match still in progress is **not** legacy, whatever it carries: it has
  /// no result to preserve, and it is being refereed *now*, by this app, under
  /// these rules.
  ///
  /// The test is [endedAt], not [method]. A legacy event has neither — but a
  /// match *this* app ends always stamps [endedAt], even when it cannot yet
  /// name a method (the referees have still to decide a level one). Keying off
  /// [method] would therefore have made the app contradict itself the instant a
  /// referee pressed Finish: a 0–0 match against three penalties reads 2–0
  /// while it runs, and would have snapped back to 0–0 the moment it stopped.
  bool get isLegacyResult =>
      endedAt == null &&
      (status == MatchStatus.finished || status == MatchStatus.canceled);

  /// Points fighter 1 has, including those their opponent's penalties conceded.
  ///
  /// The raw counters stay raw: [f1Pt2] still means "takedowns fighter 1
  /// scored". Folding the penalty points into them would claim a takedown that
  /// never happened, and nothing would remember where the points came from.
  int get f1EffectivePoints => f1Score + _penaltyPoints(f2Pen);

  int get f2EffectivePoints => f2Score + _penaltyPoints(f1Pen);

  /// Advantages fighter 1 has, including the one their opponent's second
  /// penalty conceded.
  int get f1EffectiveAdvantages => f1Adv + _penaltyAdvantages(f2Pen);

  int get f2EffectiveAdvantages => f2Adv + _penaltyAdvantages(f1Pen);

  /// The IBJJF ladder: the opponent's 3rd penalty concedes two points. The 4th
  /// adds nothing to the arithmetic — it is a disqualification, and only the
  /// referee may call one ([hasDisqualifyingPenalties]).
  int _penaltyPoints(int opponentPenalties) =>
      isLegacyResult ? 0 : (opponentPenalties >= 3 ? 2 : 0);

  /// The opponent's 2nd penalty concedes an advantage.
  int _penaltyAdvantages(int opponentPenalties) =>
      isLegacyResult ? 0 : (opponentPenalties >= 2 ? 1 : 0);

  /// Whether either fighter has earned a disqualification by accumulating four
  /// penalties.
  ///
  /// The app does **not** act on this: a fourth penalty that ended the match by
  /// itself would make the penalty button the one control on the mat that
  /// decides who loses, and a mis-tap would be unrecoverable. The referee ends
  /// the match; this only tells the UI what to offer them.
  bool get hasDisqualifyingPenalties => f1Pen >= 4 || f2Pen >= 4;

  /// The winner the scoreboard implies, or null when the fighters are level.
  ///
  /// Null is not a failure — it is the honest answer. A level match has no
  /// winner in the data, and inventing one is exactly the lie this model exists
  /// to prevent. The referees decide: [MatchMethod.decision] or
  /// [MatchMethod.draw].
  MatchWinner? get scoreboardWinner {
    if (f1EffectivePoints != f2EffectivePoints) {
      return f1EffectivePoints > f2EffectivePoints
          ? MatchWinner.f1
          : MatchWinner.f2;
    }
    if (f1EffectiveAdvantages != f2EffectiveAdvantages) {
      return f1EffectiveAdvantages > f2EffectiveAdvantages
          ? MatchWinner.f1
          : MatchWinner.f2;
    }
    return null;
  }

  /// How the scoreboard would decide it, or null when it cannot.
  ///
  /// Penalties are never the answer: they are already inside the points and
  /// advantages being compared, and using the raw count as a further tiebreak
  /// would count the same penalty twice — a fighter whose third penalty already
  /// handed their opponent two points could then lose *again* for having the
  /// higher count.
  MatchMethod? get scoreboardMethod {
    if (f1EffectivePoints != f2EffectivePoints) return MatchMethod.points;
    if (f1EffectiveAdvantages != f2EffectiveAdvantages) {
      return MatchMethod.advantages;
    }
    return null;
  }

  /// Convert score to display format (includes advantages/penalties notation)
  String getF1ScoreDisplay() => _buildScoreDisplay(f1Score, f1Adv, f1Pen);

  /// Convert score to display format (includes advantages/penalties notation)
  String getF2ScoreDisplay() => _buildScoreDisplay(f2Score, f2Adv, f2Pen);

  String _buildScoreDisplay(int score, int adv, int pen) {
    final parts = <String>['$score'];
    if (adv > 0) parts.add('$adv adv');
    if (pen > 0) parts.add('$pen pen');
    return parts.join(' | ');
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.toJson(),
      if (startAt != null) 'start_at': startAt,
      if (pausedAt != null) 'paused_at': pausedAt,
      'duration': duration,
      'f1_name': f1Name,
      'f2_name': f2Name,
      'f1_color': f1Color,
      'f2_color': f2Color,
      'f1_pt2': f1Pt2,
      'f2_pt2': f2Pt2,
      'f1_pt3': f1Pt3,
      'f2_pt3': f2Pt3,
      'f1_pt4': f1Pt4,
      'f2_pt4': f2Pt4,
      'f1_adv': f1Adv,
      'f2_adv': f2Adv,
      'f1_pen': f1Pen,
      'f2_pen': f2Pen,
      if (winner != null) 'winner': winner!.toJson(),
      if (method != null) 'method': method!.toJson(),
      if (submission != null) 'submission': submission,
      if (dqReason != null) 'dq_reason': dqReason!.toJson(),
      if (dqDetail != null) 'dq_detail': dqDetail,
      if (endedAt != null) 'ended_at': endedAt,
    };
  }

  /// Deserialize from JSON
  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      status: MatchStatus.fromJson(json['status'] as String),
      startAt: json['start_at'] as int?,
      pausedAt: json['paused_at'] as int?,
      duration: json['duration'] as int,
      f1Name: json['f1_name'] as String,
      f2Name: json['f2_name'] as String,
      f1Color: json['f1_color'] as String,
      f2Color: json['f2_color'] as String,
      f1Pt2: json['f1_pt2'] as int? ?? 0,
      f2Pt2: json['f2_pt2'] as int? ?? 0,
      f1Pt3: json['f1_pt3'] as int? ?? 0,
      f2Pt3: json['f2_pt3'] as int? ?? 0,
      f1Pt4: json['f1_pt4'] as int? ?? 0,
      f2Pt4: json['f2_pt4'] as int? ?? 0,
      f1Adv: json['f1_adv'] as int? ?? 0,
      f2Adv: json['f2_adv'] as int? ?? 0,
      f1Pen: json['f1_pen'] as int? ?? 0,
      f2Pen: json['f2_pen'] as int? ?? 0,
      winner: MatchWinner.fromJson(json['winner']),
      method: MatchMethod.fromJson(json['method']),
      submission: json['submission'] as String?,
      dqReason: DqReason.fromJson(json['dq_reason']),
      dqDetail: json['dq_detail'] as String?,
      endedAt: json['ended_at'] as int?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Parse from JSON string
  factory Match.fromJsonString(String jsonString) {
    return Match.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Convert to Nostr event (kind 31415 - Addressable Event)
  ///
  /// Creates an unsigned parameterized replaceable event with:
  /// - kind: 31415
  /// - d tag: match ID
  /// - expiration tag: calculated from start_at + duration
  /// - content: serialized match JSON
  ///
  /// The [pubkey] is required. Returns an unsigned [NostrEvent] that must
  /// be signed by a dedicated signing service before publishing.
  NostrEvent toNostrEvent({
    required String pubkey,
  }) {
    // Calculate expiration timestamp
    final exp = startAt != null ? startAt! + duration : null;

    // Build tags
    final tags = <List<String>>[
      ['d', id],
      if (exp != null) ['expiration', exp.toString()],
    ];

    // Build unsigned event (id and sig will be empty, must be signed externally)
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return NostrEvent(
      id: '',
      pubkey: pubkey,
      createdAt: createdAt,
      kind: 31415,
      tags: tags,
      content: toJsonString(),
      sig: '',
    );
  }

  /// Create Match from Nostr event (kind 31415)
  ///
  /// Parses the event content as JSON and extracts the match data.
  /// Validates that the event kind is 31415 and extracts the match ID
  /// from the "d" tag.
  ///
  /// Throws [FormatException] if:
  /// - Event kind is not 31415
  /// - Event content is not valid JSON
  /// - Match data fails validation
  factory Match.fromNostrEvent(NostrEvent event) {
    if (event.kind != 31415) {
      throw FormatException(
        'Expected event kind 31415, got: ${event.kind}',
      );
    }

    // Parse content JSON
    final json = jsonDecode(event.content) as Map<String, dynamic>;

    // Extract and validate d tag (required for kind 31415)
    final dTags =
        event.tags.where((tag) => tag.isNotEmpty && tag[0] == 'd').toList();

    if (dTags.length != 1 || dTags.first.length < 2 || dTags.first[1].isEmpty) {
      throw const FormatException(
        'Missing or invalid d tag for kind 31415 event',
      );
    }

    final dTag = dTags.first[1];
    if (dTag != json['id']) {
      throw FormatException(
        'Match ID mismatch: d tag says "$dTag" but content says "${json['id']}"',
      );
    }

    return Match.fromJson(json);
  }

  /// Create a copy of this match with updated fields
  ///
  /// To clear [startAt] or [pausedAt] to null, pass them as null explicitly.
  /// Omitting them preserves the current value.
  Match copyWith({
    String? id,
    MatchStatus? status,
    dynamic startAt = _sentinel,
    dynamic pausedAt = _sentinel,
    int? duration,
    String? f1Name,
    String? f2Name,
    String? f1Color,
    String? f2Color,
    int? f1Pt2,
    int? f2Pt2,
    int? f1Pt3,
    int? f2Pt3,
    int? f1Pt4,
    int? f2Pt4,
    int? f1Adv,
    int? f2Adv,
    int? f1Pen,
    int? f2Pen,
    dynamic winner = _sentinel,
    dynamic method = _sentinel,
    dynamic submission = _sentinel,
    dynamic dqReason = _sentinel,
    dynamic dqDetail = _sentinel,
    dynamic endedAt = _sentinel,
  }) {
    return Match(
      id: id ?? this.id,
      status: status ?? this.status,
      startAt: startAt == _sentinel ? this.startAt : startAt as int?,
      pausedAt: pausedAt == _sentinel ? this.pausedAt : pausedAt as int?,
      duration: duration ?? this.duration,
      f1Name: f1Name ?? this.f1Name,
      f2Name: f2Name ?? this.f2Name,
      f1Color: f1Color ?? this.f1Color,
      f2Color: f2Color ?? this.f2Color,
      f1Pt2: f1Pt2 ?? this.f1Pt2,
      f2Pt2: f2Pt2 ?? this.f2Pt2,
      f1Pt3: f1Pt3 ?? this.f1Pt3,
      f2Pt3: f2Pt3 ?? this.f2Pt3,
      f1Pt4: f1Pt4 ?? this.f1Pt4,
      f2Pt4: f2Pt4 ?? this.f2Pt4,
      f1Adv: f1Adv ?? this.f1Adv,
      f2Adv: f2Adv ?? this.f2Adv,
      f1Pen: f1Pen ?? this.f1Pen,
      f2Pen: f2Pen ?? this.f2Pen,
      winner: winner == _sentinel ? this.winner : winner as MatchWinner?,
      method: method == _sentinel ? this.method : method as MatchMethod?,
      submission:
          submission == _sentinel ? this.submission : submission as String?,
      dqReason: dqReason == _sentinel ? this.dqReason : dqReason as DqReason?,
      dqDetail: dqDetail == _sentinel ? this.dqDetail : dqDetail as String?,
      endedAt: endedAt == _sentinel ? this.endedAt : endedAt as int?,
    );
  }

  @override
  String toString() {
    return 'Match(id: $id, status: ${status.name}, '
        '$f1Name($f1Score) vs $f2Name($f2Score))';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Match &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          f1Score == other.f1Score &&
          f2Score == other.f2Score &&
          f1Adv == other.f1Adv &&
          f2Adv == other.f2Adv &&
          f1Pen == other.f1Pen &&
          f2Pen == other.f2Pen &&
          // A match that has gained an outcome is not the match it was: the
          // score can be identical and the winner the opposite fighter.
          winner == other.winner &&
          method == other.method &&
          submission == other.submission &&
          dqReason == other.dqReason &&
          dqDetail == other.dqDetail;

  @override
  int get hashCode => Object.hash(
        id,
        f1Score,
        f2Score,
        f1Adv,
        f2Adv,
        f1Pen,
        f2Pen,
        winner,
        method,
        submission,
        dqReason,
        dqDetail,
      );
}
