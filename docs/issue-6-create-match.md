# Issue #6: Create Match — Form & Initial Event Publishing

## Overview

Implement the match creation flow: a form screen where users input fighter names, match duration, and fighter colors, then publish the initial kind 38000 Nostr event with status `waiting`.

## Current State

- **Match model** (`lib/features/match/models/match.dart`): Fully implemented with `Match.create()` factory, JSON serialization, `toNostrEvent()`, and validation.
- **NostrService** (`lib/services/nostr/nostr_service.dart`): `publishAddressableEvent()` handles signing (via `nostr_tools`) and publishing to ≥2 relays.
- **KeyManager**: Keys are generated on first launch and cached.
- **MatchScreen**: Currently a static mockup — will remain as the scoring screen. The new form is a separate screen.

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `lib/features/match/create_match_screen.dart` | Form UI for creating a match |
| `lib/features/match/providers/match_providers.dart` | Riverpod providers for match state |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/home/home_screen.dart` | Wire "Create New Match" button to navigate to `CreateMatchScreen` |
| `lib/main.dart` | Add import for `CreateMatchScreen` (if needed for routing) |

## Data Flow

```text
User fills form → validate inputs → Match.create() → build Nostr event
→ NostrService.publishAddressableEvent(dTag: matchId, content: matchJson, additionalTags: [expiration])
→ on success: add match to local state + pop back to Home
→ on failure: show error snackbar with retry
```

## Form Fields

| Field | Type | Validation | Default |
|-------|------|------------|---------|
| Fighter 1 Name | `TextFormField` | Required, non-empty | — |
| Fighter 2 Name | `TextFormField` | Required, non-empty | — |
| Duration | Duration picker (mm:ss) | > 0 seconds | 300s (5:00) |
| Fighter 1 Color | Color picker | Valid hex | `#1BA34E` (BJJ Green) |
| Fighter 2 Color | Color picker | Valid hex | `#F5B800` (Gold) |

## Nostr Event Structure

```json
{
  "kind": 38000,
  "pubkey": "<user_pubkey>",
  "created_at": <unix_timestamp>,
  "tags": [
    ["d", "<4-hex-match-id>"],
    ["expiration", "<now + 604800>"]
  ],
  "content": "{\"id\":\"abcd\",\"status\":\"waiting\",\"start_at\":0,\"duration\":300,\"f1_name\":\"Fighter 1\",\"f2_name\":\"Fighter 2\",\"f1_color\":\"#1BA34E\",\"f2_color\":\"#F5B800\",\"f1_pt2\":0,\"f2_pt2\":0,\"f1_pt3\":0,\"f2_pt3\":0,\"f1_pt4\":0,\"f2_pt4\":0,\"f1_adv\":0,\"f2_adv\":0,\"f1_pen\":0,\"f2_pen\":0}",
  "id": "<sha256_hash>",
  "sig": "<schnorr_sig>"
}
```

- `start_at`: `0` (match not started yet)
- `expiration`: `now + 1 week` (604800 seconds) per NIP-40
- `d` tag: auto-generated 4-hex match ID
- All counters at 0

## Riverpod State Management

### Providers

```dart
/// List of matches created/received by the user
final matchListProvider = StateNotifierProvider<MatchListNotifier, List<Match>>((ref) {
  return MatchListNotifier();
});

class MatchListNotifier extends StateNotifier<List<Match>> {
  MatchListNotifier() : super([]);

  void addMatch(Match match) {
    state = [match, ...state];
  }

  void removeMatch(String matchId) {
    state = state.where((m) => m.id != matchId).toList();
  }

  void updateMatch(Match updated) {
    state = state.map((m) => m.id == updated.id ? updated : m).toList();
  }
}
```

## UI Design

### CreateMatchScreen Layout

Following the existing app design language (navy background, rounded containers, BJJ color palette):

1. **AppBar**: "New Match" title, back button
2. **Form body** (scrollable):
   - Fighter 1 name input
   - Fighter 2 name input  
   - Duration picker (CupertinoPicker-style wheel showing mm:ss)
   - Color picker row (two circular color selectors)
3. **Bottom**: "Create Match" button (full-width, BJJ Green)
4. **Loading state**: Button shows spinner during publish

### Color Picker

Simple approach: pre-defined palette of 8 BJJ-relevant colors in a horizontal row of tappable circles. No need for a full color picker widget.

Palette: `#1BA34E` (Green), `#F5B800` (Gold), `#D32F2F` (Red), `#2196F3` (Blue), `#FFFFFF` (White), `#9C27B0` (Purple), `#FF9800` (Orange), `#121A2E` (Navy)

### Duration Selector

Pre-defined duration chips (3:00, 4:00, 5:00, 6:00, 7:00, 8:00, 10:00) displayed as tappable rounded containers. Selected chip is highlighted in BJJ Green.

## Error Handling

- **Validation errors**: Inline under each field (standard `FormField` validation)
- **Publish failure** (< 2 relays): Snackbar with error message + retry option
- **No keys**: Should not happen (generated on init), but guard with error state

## Navigation

After successful creation:
1. Add match to `matchListProvider`
2. Pop back to Home screen

## Testing

- Unit: `Match.create()` generates valid 4-hex ID, JSON roundtrip
- Unit: Validation rejects empty names, zero duration
- Widget: Form shows validation errors on empty submit
- Widget: Successful creation calls `publishAddressableEvent` with correct params
