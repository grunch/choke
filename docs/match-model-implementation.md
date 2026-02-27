# Match Model Implementation

## Overview

This document describes the implementation of the `Match` data model for the Choke BJJ scoring application. The model maps to Nostr event kind 31925 (addressable/replaceable events) and handles all scoring logic for Brazilian Jiu-Jitsu matches.

## Issue Reference

- **Issue:** [#4 - Match data model and content schema](https://github.com/grunch/choke/issues/4)
- **Status:** Implemented
- **PR:** #20

## Content Schema

The match data is serialized to JSON with the following structure:

```json
{
  "id": "abcd",
  "status": "waiting | inProgress | finished | canceled",
  "start_at": 123456789,
  "duration": 300,
  "f1_name": "Athlete A",
  "f2_name": "Athlete B",
  "f1_color": "#FFFFFF",
  "f2_color": "#000000",
  "f1_pt2": 0,
  "f2_pt2": 0,
  "f1_pt3": 0,
  "f2_pt3": 0,
  "f1_pt4": 0,
  "f2_pt4": 0,
  "f1_adv": 0,
  "f2_adv": 0,
  "f1_pen": 0,
  "f2_pen": 0
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (4 hex chars) | Unique match identifier |
| `status` | Enum string | `waiting`, `inProgress`, `finished`, or `canceled` |
| `start_at` | Integer (optional) | Unix timestamp when match started |
| `duration` | Integer | Match duration in seconds (e.g., 300 = 5 minutes) |
| `f1_name` / `f2_name` | String | Fighter names |
| `f1_color` / `f2_color` | String (hex) | Gi colors in #RRGGBB format |
| `f1_pt2` / `f2_pt2` | Integer | Takedown/Sweep count (+2 points each) |
| `f1_pt3` / `f2_pt3` | Integer | Guard pass count (+3 points each) |
| `f1_pt4` / `f2_pt4` | Integer | Mount/Back take count (+4 points each) |
| `f1_adv` / `f2_adv` | Integer | Advantage count |
| `f1_pen` / `f2_pen` | Integer | Penalty count |

## MatchStatus Enum

```dart
enum MatchStatus {
  waiting,      // Match created but not started
  inProgress,   // Match is active
  finished,     // Match completed normally
  canceled;     // Match was canceled
}
```

The enum provides:
- `toJson()`: Serializes to string (e.g., `"inProgress"`)
- `fromJson(String)`: Parses from string with error handling

## Score Calculation

The total score is calculated using the IBJJF points system:

```text
Score = (pt2 × 2) + (pt3 × 3) + (pt4 × 4)
```

Where:
- `pt2`: Takedowns and sweeps (+2 points each)
- `pt3`: Guard passes (+3 points each)
- `pt4`: Mount and back takes (+4 points each)

**Note:** Advantages and penalties are used for tie-breaking and do not contribute to the point total.

### Score Properties

```dart
// Fighter 1 score
int get f1Score => f1Pt2 * 2 + f1Pt3 * 3 + f1Pt4 * 4;

// Fighter 2 score
int get f2Score => f2Pt2 * 2 + f2Pt3 * 3 + f2Pt4 * 4;
```

## Match ID Generation

Match IDs are 4-character hexadecimal strings (e.g., `a3f7`) generated using cryptographically secure random:

```dart
static const _hexChars = '0123456789abcdef';
static final _random = Random.secure();

static String _generateMatchId() {
  return List.generate(4, (_) => _hexChars[_random.nextInt(16)]).join();
}
```

This provides:
- 65,536 possible unique IDs (16^4)
- Secure random generation suitable for production use
- Human-readable and easy to share

## Validation

The model validates all fields on construction:

### Validated Constraints

| Constraint | Validation |
|------------|------------|
| Match ID | Exactly 4 characters, valid hex |
| Duration | Non-negative integer |
| All counters | Non-negative integers |
| Colors | Valid hex format (#RRGGBB) |
| start_at | Non-negative if present |

### Validation Errors

Invalid data throws `FormatException` with descriptive messages:

```dart
// Examples:
FormatException('Match ID must be exactly 4 characters, got: abc')
FormatException('Duration must be non-negative, got: -300')
FormatException('f1Pt2 must be non-negative, got: -1')
```

## Nostr Event Integration

### Kind 31925 - Addressable Events

The model integrates with Nostr using kind 31925 (addressable/replaceable events). This allows:
- Multiple devices to sync match state
- Real-time updates as scores change
- Event replaceability (newer events supersede older ones for the same match)

### Event Structure

```text
kind: 31925
d: "<match_id>"
expiration: "<start_at + duration>" (optional)
content: "<serialized match JSON>"
```

### Creating Nostr Events

```dart
final match = Match.create(
  f1Name: 'Athlete A',
  f2Name: 'Athlete B',
  f1Color: '#FFFFFF',
  f2Color: '#000000',
  duration: 300,
);

final nostrEvent = match.toNostrEvent(
  pubkey: publicKey,
  privateKey: privateKey,
);

// Publish via NostrService
await nostrService.publishEvent(nostrEvent);
```

### Parsing Nostr Events

```dart
final match = Match.fromNostrEvent(nostrEvent);

// Validates:
// - Event kind is 31925
// - d tag matches content id
// - All data passes validation
```

## Serialization

### JSON Serialization

```dart
// To JSON Map
final json = match.toJson();

// From JSON Map
final match = Match.fromJson(json);

// To JSON String
final jsonString = match.toJsonString();

// From JSON String
final match = Match.fromJsonString(jsonString);
```

### Factory Constructor

```dart
// Create with auto-generated ID
final match = Match.create(
  f1Name: 'Athlete A',
  f2Name: 'Athlete B',
  f1Color: '#FFFFFF',
  f2Color: '#000000',
  duration: 300,
  status: MatchStatus.waiting,
  startAt: null,
);
```

## Copying and Updates

The `copyWith` method enables immutable updates:

```dart
final updatedMatch = match.copyWith(
  status: MatchStatus.inProgress,
  startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  f1Pt2: match.f1Pt2 + 1,  // Add a takedown
);
```

## Equality and Hashing

Matches are compared by:
- Match ID
- Scores (f1Score, f2Score)
- Advantages (f1Adv, f2Adv)
- Penalties (f1Pen, f2Pen)

This ensures that functionally equivalent matches compare equal while independent data (names, colors) does not affect equality.

```dart
match1 == match2  // true if same scores
match1.hashCode   // Consistent with equality
```

## Testing Considerations

### Unit Tests Needed

1. **Validation Tests**
   - Valid match construction
   - Invalid match ID formats
   - Negative counters
   - Invalid colors
   - Boundary values (zero, large numbers)

2. **Score Calculation Tests**
   - Empty match (0-0)
   - Complex score scenarios
   - Tie-breaking with advantages

3. **Serialization Tests**
   - Round-trip JSON serialization
   - JSON string serialization
   - Unknown enum values

4. **Nostr Integration Tests**
   - Event creation with signing
   - Event parsing from network
   - d tag validation
   - Kind validation

5. **ID Generation Tests**
   - Length and format
   - Randomness (distribution)

### Example Test Cases

```dart
group('Match', () {
  group('validation', () {
    test('accepts valid match', () {
      expect(() => Match.create(/* valid data */), returnsNormally);
    });

    test('rejects invalid match ID', () {
      expect(
        () => Match(id: 'xyz', /* ... */),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects negative counters', () {
      expect(
        () => Match(/* valid data */, f1Pt2: -1),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('score calculation', () {
    test('calculates score correctly', () {
      final match = Match(
        f1Pt2: 1,  // +2
        f1Pt3: 1,  // +3
        f1Pt4: 1,  // +4
        /* other fields */
      );
      expect(match.f1Score, equals(9));
    });
  });
});
```

## Integration with UI

The model is designed to work seamlessly with Flutter's reactive UI:

```dart
class MatchNotifier extends StateNotifier<Match> {
  MatchNotifier() : super(Match.create(/* ... */));

  void startMatch() {
    state = state.copyWith(
      status: MatchStatus.inProgress,
      startAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  void addTakedown({required bool fighter1}) {
    if (fighter1) {
      state = state.copyWith(f1Pt2: state.f1Pt2 + 1);
    } else {
      state = state.copyWith(f2Pt2: state.f2Pt2 + 1);
    }
  }

  void finishMatch() {
    state = state.copyWith(status: MatchStatus.finished);
  }
}
```

## File Location

```text
lib/
└── features/
    └── match/
        ├── models/
        │   └── match.dart          # Match model implementation
        └── match_screen.dart       # UI (existing)
```

## Dependencies

The implementation uses:
- `dart:convert` - JSON serialization
- `dart:math` - Secure random ID generation
- `nostr_tools` - Nostr event signing and hashing
- `nostr_service.dart` - NostrEvent type definition

## Future Enhancements

Potential improvements for future iterations:

1. **Submission Tracking**: Add boolean flags for submission victories
2. **Round Management**: Support for multi-round matches
3. **Weight Classes**: Add optional weight class metadata
4. **Belt Levels**: Add fighter belt/rank information
5. **Event History**: Track all state changes as a log
6. **Conflict Resolution**: Handle concurrent updates from multiple devices

## Acceptance Criteria Verification

| Criterion | Status | Notes |
|-----------|--------|-------|
| Model serializes/deserializes correctly | ✅ | `toJson()`, `fromJson()` implemented |
| Score calculation is correct | ✅ | IBJJF formula: pt2×2 + pt3×3 + pt4×4 |
| Nostr event format matches spec | ✅ | kind 31925, d tag, expiration tag |
| Validation rejects invalid data | ✅ | FormatException on all invalid inputs |
| Match ID generation | ✅ | 4-char secure random hex |
| Integration with NostrService | ✅ | Uses existing toNostrToolsEvent pattern |

## Related Documentation

- [NIP-01 - Basic Protocol](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [NIP-33 - Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md) (kind 31925)

