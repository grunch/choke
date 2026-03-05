import 'dart:convert';
import 'dart:math';
import 'package:nostr_tools/nostr_tools.dart' as nostr;
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

/// Represents a BJJ match with scoring data
///
/// Maps to Nostr event kind 31415 (addressable events) with the following
/// content schema:
/// ```json
/// {
///   "id": "abcd",
///   "status": "waiting | in-progress | finished | canceled",
///   "start_at": 123456789,
///   "duration": 300,
///   "f1_name": "string",
///   "f2_name": "string",
///   "f1_color": "#RRGGBB",
///   "f2_color": "#RRGGBB",
///   "f1_pt2": 0, "f2_pt2": 0,
///   "f1_pt3": 0, "f2_pt3": 0,
///   "f1_pt4": 0, "f2_pt4": 0,
///   "f1_adv": 0, "f2_adv": 0,
///   "f1_pen": 0, "f2_pen": 0
/// }
/// ```
class Match {
  /// 4-character hex identifier for the match
  final String id;

  /// Current status of the match
  final MatchStatus status;

  /// Unix timestamp when the match started (seconds since epoch)
  final int? startAt;

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

  static const _hexChars = '0123456789abcdef';
  static final _random = Random.secure();

  Match({
    required this.id,
    required this.status,
    this.startAt,
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
  }

  /// Calculate total score for fighter 1
  /// Formula: pt2*2 + pt3*3 + pt4*4
  int get f1Score => f1Pt2 * 2 + f1Pt3 * 3 + f1Pt4 * 4;

  /// Calculate total score for fighter 2
  /// Formula: pt2*2 + pt3*3 + pt4*4
  int get f2Score => f2Pt2 * 2 + f2Pt3 * 3 + f2Pt4 * 4;

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
    };
  }

  /// Deserialize from JSON
  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      status: MatchStatus.fromJson(json['status'] as String),
      startAt: json['start_at'] as int?,
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
  /// To clear [startAt] to null, pass [startAt] as null explicitly.
  /// Omitting [startAt] preserves the current value.
  Match copyWith({
    String? id,
    MatchStatus? status,
    dynamic startAt = _sentinel,
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
  }) {
    return Match(
      id: id ?? this.id,
      status: status ?? this.status,
      startAt: startAt == _sentinel ? this.startAt : startAt as int?,
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
          f2Pen == other.f2Pen;

  @override
  int get hashCode => Object.hash(
        id,
        f1Score,
        f2Score,
        f1Adv,
        f2Adv,
        f1Pen,
        f2Pen,
      );
}
