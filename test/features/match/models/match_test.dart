import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/match/models/match.dart';

void main() {
  group('Match', () {
    // Valid test data
    final validMatchData = {
      'id': 'a3f7',
      'status': 'waiting',
      'duration': 300,
      'f1_name': 'Roger Gracie',
      'f2_name': 'Buchecha',
      'f1_color': '#FFFFFF',
      'f2_color': '#000000',
      'f1_pt2': 0,
      'f2_pt2': 0,
      'f1_pt3': 0,
      'f2_pt3': 0,
      'f1_pt4': 0,
      'f2_pt4': 0,
      'f1_adv': 0,
      'f2_adv': 0,
      'f1_pen': 0,
      'f2_pen': 0,
    };

    group('construction', () {
      test('creates valid match with all fields', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.waiting,
          startAt: 1699900000,
          duration: 300,
          f1Name: 'Roger Gracie',
          f2Name: 'Buchecha',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
          f2Pt2: 0,
          f1Pt3: 1,
          f2Pt3: 0,
          f1Pt4: 0,
          f2Pt4: 1,
          f1Adv: 2,
          f2Adv: 1,
          f1Pen: 0,
          f2Pen: 1,
        );

        expect(match.id, equals('a3f7'));
        expect(match.status, equals(MatchStatus.waiting));
        expect(match.startAt, equals(1699900000));
        expect(match.duration, equals(300));
        expect(match.f1Name, equals('Roger Gracie'));
        expect(match.f2Name, equals('Buchecha'));
        expect(match.f1Color, equals('#FFFFFF'));
        expect(match.f2Color, equals('#000000'));
        expect(match.f1Pt2, equals(1));
        expect(match.f2Pt4, equals(1));
        expect(match.f1Adv, equals(2));
        expect(match.f2Pen, equals(1));
      });

      test('creates valid match with default counters', () {
        final match = Match(
          id: 'b5e2',
          status: MatchStatus.inProgress,
          duration: 600,
          f1Name: 'Athlete A',
          f2Name: 'Athlete B',
          f1Color: '#FF5733',
          f2Color: '#33FF57',
        );

        expect(match.f1Pt2, equals(0));
        expect(match.f2Pt2, equals(0));
        expect(match.f1Pt3, equals(0));
        expect(match.f2Pt3, equals(0));
        expect(match.f1Pt4, equals(0));
        expect(match.f2Pt4, equals(0));
        expect(match.f1Adv, equals(0));
        expect(match.f2Adv, equals(0));
        expect(match.f1Pen, equals(0));
        expect(match.f2Pen, equals(0));
      });

      test('Match.create generates valid ID', () {
        final match = Match.create(
          f1Name: 'Fighter 1',
          f2Name: 'Fighter 2',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          duration: 300,
        );

        expect(match.id.length, equals(4));
        expect(RegExp(r'^[0-9a-f]{4}$').hasMatch(match.id), isTrue);
        expect(match.status, equals(MatchStatus.waiting));
      });
    });

    group('validation', () {
      test('rejects match ID too short', () {
        expect(
          () => Match(
            id: 'abc',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exactly 4 characters'),
            ),
          ),
        );
      });

      test('rejects match ID too long', () {
        expect(
          () => Match(
            id: 'abcde',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exactly 4 characters'),
            ),
          ),
        );
      });

      test('rejects invalid hex match ID', () {
        expect(
          () => Match(
            id: 'xyz1',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('valid hex'),
            ),
          ),
        );
      });

      test('accepts uppercase hex match ID', () {
        expect(
          () => Match(
            id: 'A3F7',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          returnsNormally,
        );
      });

      test('rejects negative duration', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: -1,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('non-negative'),
            ),
          ),
        );
      });

      test('accepts zero duration', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: 0,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          returnsNormally,
        );
      });

      test('rejects negative counters', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
            f1Pt2: -1,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('rejects invalid color format', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: 'FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('valid hex color'),
            ),
          ),
        );
      });

      test('rejects color with wrong length', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFF',
            f2Color: '#000000',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('accepts valid hex colors', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#AaBbCc',
            f2Color: '#123456',
          ),
          returnsNormally,
        );
      });

      test('rejects negative startAt', () {
        expect(
          () => Match(
            id: 'a3f7',
            status: MatchStatus.waiting,
            startAt: -1,
            duration: 300,
            f1Name: 'A',
            f2Name: 'B',
            f1Color: '#FFFFFF',
            f2Color: '#000000',
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('score calculation', () {
      test('calculates empty match score as 0-0', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        expect(match.f1Score, equals(0));
        expect(match.f2Score, equals(0));
      });

      test('calculates takedown points (pt2)', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 3,
          f2Pt2: 1,
        );

        expect(match.f1Score, equals(6)); // 3 * 2
        expect(match.f2Score, equals(2)); // 1 * 2
      });

      test('calculates guard pass points (pt3)', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt3: 2,
          f2Pt3: 1,
        );

        expect(match.f1Score, equals(6)); // 2 * 3
        expect(match.f2Score, equals(3)); // 1 * 3
      });

      test('calculates mount/back points (pt4)', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt4: 1,
          f2Pt4: 2,
        );

        expect(match.f1Score, equals(4)); // 1 * 4
        expect(match.f2Score, equals(8)); // 2 * 4
      });

      test('calculates combined score correctly', () {
        // Example from SPEC.md: f1_pt2=1, rest=0 → f1 wins 2-0
        final match = Match(
          id: 'abcd',
          status: MatchStatus.inProgress,
          duration: 600,
          f1Name: 'Roger Gracie',
          f2Name: 'Buchecha',
          f1Color: '#aabbcc',
          f2Color: '#ccddee',
          f1Pt2: 1,
          f1Pt3: 0,
          f1Pt4: 0,
          f2Pt2: 0,
          f2Pt3: 0,
          f2Pt4: 0,
        );

        expect(match.f1Score, equals(2));
        expect(match.f2Score, equals(0));
      });

      test('advantages do not affect score total', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
          f1Adv: 5,
          f2Adv: 3,
        );

        expect(match.f1Score, equals(2));
        expect(match.f2Score, equals(0));
      });

      test('penalties do not affect score total', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt3: 1,
          f1Pen: 2,
          f2Pen: 1,
        );

        expect(match.f1Score, equals(3));
        expect(match.f2Score, equals(0));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final match = Match(
          id: 'abcd',
          status: MatchStatus.inProgress,
          startAt: 123456789,
          duration: 600,
          f1Name: 'Roger Gracie',
          f2Name: 'Buchecha',
          f1Color: '#aabbcc',
          f2Color: '#ccddee',
          f1Pt2: 1,
          f2Pt2: 0,
          f1Pt3: 0,
          f2Pt3: 0,
          f1Pt4: 0,
          f2Pt4: 0,
          f1Adv: 0,
          f2Adv: 0,
          f1Pen: 1,
          f2Pen: 1,
        );

        final json = match.toJson();

        expect(json['id'], equals('abcd'));
        expect(json['status'], equals('inProgress'));
        expect(json['start_at'], equals(123456789));
        expect(json['duration'], equals(600));
        expect(json['f1_name'], equals('Roger Gracie'));
        expect(json['f2_name'], equals('Buchecha'));
        expect(json['f1_color'], equals('#aabbcc'));
        expect(json['f2_color'], equals('#ccddee'));
        expect(json['f1_pt2'], equals(1));
        expect(json['f2_pt2'], equals(0));
        expect(json['f1_pen'], equals(1));
        expect(json['f2_pen'], equals(1));
      });

      test('omits null start_at from JSON', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.waiting,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        final json = match.toJson();

        expect(json.containsKey('start_at'), isFalse);
      });

      test('deserializes from JSON correctly', () {
        final match = Match.fromJson(validMatchData);

        expect(match.id, equals('a3f7'));
        expect(match.status, equals(MatchStatus.waiting));
        expect(match.duration, equals(300));
        expect(match.f1Name, equals('Roger Gracie'));
        expect(match.f2Name, equals('Buchecha'));
      });

      test('deserializes with default values for missing counters', () {
        final json = {
          'id': 'a3f7',
          'status': 'inProgress',
          'duration': 300,
          'f1_name': 'A',
          'f2_name': 'B',
          'f1_color': '#FFFFFF',
          'f2_color': '#000000',
        };

        final match = Match.fromJson(json);

        expect(match.f1Pt2, equals(0));
        expect(match.f2Adv, equals(0));
      });

      test('round-trip JSON serialization preserves data', () {
        final original = Match(
          id: 'ab12',
          status: MatchStatus.finished,
          startAt: 1234567890,
          duration: 480,
          f1Name: 'Grappler 1',
          f2Name: 'Grappler 2',
          f1Color: '#123456',
          f2Color: '#ABCDEF',
          f1Pt2: 2,
          f2Pt2: 1,
          f1Pt3: 1,
          f2Pt3: 0,
          f1Pt4: 0,
          f2Pt4: 1,
          f1Adv: 3,
          f2Adv: 2,
          f1Pen: 0,
          f2Pen: 1,
        );

        final json = original.toJson();
        final restored = Match.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.status, equals(original.status));
        expect(restored.startAt, equals(original.startAt));
        expect(restored.duration, equals(original.duration));
        expect(restored.f1Name, equals(original.f1Name));
        expect(restored.f2Name, equals(original.f2Name));
        expect(restored.f1Color, equals(original.f1Color));
        expect(restored.f2Color, equals(original.f2Color));
        expect(restored.f1Pt2, equals(original.f1Pt2));
        expect(restored.f2Pt4, equals(original.f2Pt4));
        expect(restored.f1Adv, equals(original.f1Adv));
        expect(restored.f2Pen, equals(original.f2Pen));
      });

      test('serializes to JSON string', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.waiting,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        final jsonString = match.toJsonString();

        expect(jsonString, contains('"id":"a3f7"'));
        expect(jsonString, contains('"status":"waiting"'));
      });

      test('deserializes from JSON string', () {
        final jsonString =
            '{"id":"b4c1","status":"inProgress","duration":300,"f1_name":"X","f2_name":"Y","f1_color":"#FFF","f2_color":"#000"}';

        expect(
          () => Match.fromJsonString(jsonString),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('MatchStatus enum', () {
      test('serializes to JSON string', () {
        expect(MatchStatus.waiting.toJson(), equals('waiting'));
        expect(MatchStatus.inProgress.toJson(), equals('inProgress'));
        expect(MatchStatus.finished.toJson(), equals('finished'));
        expect(MatchStatus.canceled.toJson(), equals('canceled'));
      });

      test('deserializes from JSON string', () {
        expect(MatchStatus.fromJson('waiting'), equals(MatchStatus.waiting));
        expect(
          MatchStatus.fromJson('inProgress'),
          equals(MatchStatus.inProgress),
        );
        expect(MatchStatus.fromJson('finished'), equals(MatchStatus.finished));
        expect(MatchStatus.fromJson('canceled'), equals(MatchStatus.canceled));
      });

      test('throws on unknown status', () {
        expect(
          () => MatchStatus.fromJson('unknown'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Unknown MatchStatus'),
            ),
          ),
        );
      });
    });

    group('copyWith', () {
      test('copies match with updated fields', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.waiting,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        final updated = match.copyWith(
          status: MatchStatus.inProgress,
          f1Pt2: match.f1Pt2 + 1,
        );

        expect(updated.id, equals('a3f7')); // unchanged
        expect(updated.f1Name, equals('A')); // unchanged
        expect(updated.status, equals(MatchStatus.inProgress)); // changed
        expect(updated.f1Pt2, equals(1)); // changed
        expect(updated.f2Pt2, equals(0)); // unchanged default
      });

      test('returns identical match when no changes', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        final copy = match.copyWith();

        expect(copy.id, equals(match.id));
        expect(copy.status, equals(match.status));
        expect(copy.f1Pt2, equals(match.f1Pt2));
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final match = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'Roger',
          f2Name: 'Buchecha',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
        );

        final str = match.toString();

        expect(str, contains('a3f7'));
        expect(str, contains('inProgress'));
        expect(str, contains('Roger'));
        expect(str, contains('Buchecha'));
        expect(str, contains('2')); // f1Score
      });
    });

    group('equality', () {
      test('equal matches are equivalent', () {
        final match1 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
        );

        final match2 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
        );

        expect(match1, equals(match2));
        expect(match1.hashCode, equals(match2.hashCode));
      });

      test('different scores are not equal', () {
        final match1 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 1,
        );

        final match2 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'A',
          f2Name: 'B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
          f1Pt2: 2,
        );

        expect(match1, isNot(equals(match2)));
      });

      test('names do not affect equality', () {
        final match1 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'Athlete A',
          f2Name: 'Athlete B',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        final match2 = Match(
          id: 'a3f7',
          status: MatchStatus.inProgress,
          duration: 300,
          f1Name: 'Different Name',
          f2Name: 'Other Name',
          f1Color: '#FFFFFF',
          f2Color: '#000000',
        );

        expect(match1, equals(match2));
      });
    });
  });
}
