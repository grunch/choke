# Issue #7: Match Control Screen — Scoring, Timer, and Live Updates

## Overview

Replace the current static `MatchScreen` mockup with a fully functional match control screen. The screen receives a `Match` object, displays a countdown timer, provides scoring buttons per fighter, and publishes replacement events to Nostr on every state change.

## Current State

- `MatchScreen` is a hardcoded mockup with no real data binding
- `Match` model has full `copyWith`, scoring getters (`f1Score`, `f2Score`), and JSON/Nostr serialization
- `NostrService.publishAddressableEvent()` handles signing and publishing
- `MatchListNotifier` has `addMatch`, `updateMatch`, `removeMatch`
- `CreateMatchScreen` creates matches with `status: waiting` and navigates back to Home

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `lib/features/match/match_control_screen.dart` | Full match control UI (replaces old `match_screen.dart`) |
| `lib/features/match/providers/match_control_provider.dart` | `MatchControlNotifier` — manages active match state, timer, scoring, publishing |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/match/create_match_screen.dart` | Navigate to `MatchControlScreen` after creation instead of popping |
| `lib/main.dart` | Update MatchScreen reference in bottom nav (or remove from nav) |

### Deleted Files

| File | Reason |
|------|--------|
| `lib/features/match/match_screen.dart` | Replaced by `match_control_screen.dart` |

## State Management

### MatchControlNotifier

```dart
class MatchControlState {
  final Match match;
  final int remainingSeconds;  // Countdown value
  final bool isPublishing;     // Debounce indicator
  
  bool get isRunning => match.status == MatchStatus.inProgress;
  bool get isWaiting => match.status == MatchStatus.waiting;
  bool get isFinished => match.status == MatchStatus.finished || match.status == MatchStatus.canceled;
}
```

The notifier manages:
1. **Match state** — the current `Match` object (immutable, updated via `copyWith`)
2. **Timer** — a `Timer.periodic` (1 second) that decrements `remainingSeconds`
3. **Publishing** — calls `publishAddressableEvent` on every scoring action (debounced)
4. **Actions** — start, score, advantage, penalty, undo, finish, cancel

### Timer Logic

```text
remainingSeconds = duration - (now - startAt)
```

On start:
- Set `startAt = now` (unix timestamp)
- Set `status = in-progress`
- Start periodic timer

Each tick:
- `remainingSeconds = max(0, duration - (now - startAt))`
- When `remainingSeconds == 0`: stop timer, prompt to finish

On resume (app restart):
- Recalculate `remainingSeconds` from `startAt` and current time
- If still > 0, resume timer
- If <= 0, show "Time's up" prompt

### Publishing Strategy

Every scoring action triggers a publish. To avoid flooding relays:
- Debounce: skip publish if one is already in flight
- Queue: if a publish is in flight, queue the latest state and publish when done
- No publish during `waiting` status changes (only on start/score/finish/cancel)

## Scoring Actions

Each action creates a new `Match` via `copyWith` and publishes:

| Action | Field | Change |
|--------|-------|--------|
| Takedown/Sweep | `f{n}Pt2` | +1 (displays as +2 points) |
| Guard Pass | `f{n}Pt3` | +1 (displays as +3 points) |
| Mount/Back Take | `f{n}Pt4` | +1 (displays as +4 points) |
| Advantage | `f{n}Adv` | +1 |
| Penalty | `f{n}Pen` | +1 |
| Undo | last changed field | -1 (floor at 0) |

### Undo Stack

Maintain a `List<String>` of field names representing the last N actions. On undo, pop the last entry and decrement the corresponding field (never below 0).

## UI Layout

### Screen Structure (portrait)

```text
┌─────────────────────────────┐
│  ← Back    Match #abcd    ⋮ │  AppBar
├─────────────────────────────┤
│                             │
│         ┌───────┐           │
│         │ 04:32 │           │  Countdown timer (large)
│         │ mm:ss │           │
│         └───────┘           │
│      [status badge]         │
│                             │
├──────────┬──────────────────┤
│ Fighter1 │ VS │  Fighter 2  │  Score cards
│  Score   │    │   Score     │
│  A | P   │    │   A | P     │
├──────────┴──────────────────┤
│                             │
│  Select fighter: [F1] [F2]  │  Fighter selector tabs
│                             │
│  [+2 Takedown/Sweep      ] │
│  [+3 Guard Pass           ] │  Scoring buttons
│  [+4 Mount/Back Take      ] │
│  [Advantage] [Penalty]      │
│  [Undo Last Action        ] │
│                             │
│  ─────────────────────────  │
│  [Start Match] / [Finish]   │  Status actions
│  [Cancel Match]             │
└─────────────────────────────┘
```

### Fighter Selector

A toggle between Fighter 1 and Fighter 2. When a scoring button is tapped, it applies to the selected fighter. The toggle uses each fighter's color for visual clarity.

### Status-Dependent UI

| Status | Timer | Scoring | Buttons |
|--------|-------|---------|---------|
| `waiting` | Shows full duration | Disabled | [Start Match] |
| `in-progress` | Counting down | Enabled | [Finish] [Cancel] |
| `finished` | Shows 00:00 or final time | Disabled | (read-only) |
| `canceled` | Shows "Canceled" | Disabled | (read-only) |

### Color Coding

- Fighter panels use their assigned `f1_color` / `f2_color` as accent
- Leading fighter's score card gets a colored border
- Timer turns red when < 30 seconds

## Navigation

### Entry Points

1. **From CreateMatchScreen** — after successful creation, navigate to `MatchControlScreen(match: match)`
2. **From Home** — future: tap on a match in the list (not in this PR)

### Exit

- Back button returns to Home
- Finish/Cancel → show confirmation dialog → return to Home on confirm

## Error Handling

- **Publish failure**: Show snackbar, keep local state (don't revert scoring)
- **Timer overflow**: Guard `remainingSeconds` to never go negative
- **Undo on empty stack**: Button disabled when stack is empty
