# Issue #5: Home Screen — Display Match List from Nostr Events

## Overview

Subscribe to the user's kind 31415 events from Nostr relays, parse them as Match objects, and display them in a scrollable list on the Home screen with status filter chips. Tapping a match card navigates to the Match Control screen.

## Architecture

### New File

| File | Purpose |
|------|---------|
| `lib/features/home/providers/home_providers.dart` | Providers for match list subscription, filtering, and status filter state |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/home/home_screen.dart` | Replace static Quick Start with match list + filter chips + empty state + FAB |
| `lib/main.dart` | Subscribe to user events on app start |

## Data Flow

```text
App start → NostrService.subscribeToUserEvents()
→ Relay sends kind 31415 events
→ NostrService.eventStream emits NostrEvent
→ homeMatchListProvider listens, parses Match.fromNostrEvent()
→ Deduplicates by match ID (keeps latest created_at)
→ filteredMatchListProvider applies status filter + 24h window
→ HomeScreen rebuilds with filtered list
```

## Providers

### homeMatchListProvider

A `StreamProvider` that listens to `NostrService.eventStream`, filters for kind 31415, parses to `Match`, and deduplicates by ID (latest `created_at` wins). Also includes locally created matches from `matchListProvider`.

### statusFilterProvider

A `StateProvider<Set<MatchStatus>>` defaulting to `{waiting, inProgress}`. User can toggle `finished` and `canceled` via filter chips.

### filteredMatchListProvider

Combines `homeMatchListProvider` + `statusFilterProvider`:
- Filter by selected statuses
- Filter by `created_at` within last 24 hours
- Sort by `created_at` descending (newest first)

## UI Layout

```text
┌─────────────────────────────┐
│  Choke          [+ Create]  │  Header + FAB
│  Score your BJJ matches     │
├─────────────────────────────┤
│ [Waiting] [In Progress]     │  Filter chips (toggleable)
│ [Finished] [Canceled]       │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ #abcd      ● In Progress│ │  Match card
│ │ Fighter1  4  vs  2  F2  │ │
│ │ ●          A:1 P:0   ●  │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ #ef01      ● Waiting    │ │
│ │ Fighter3  0  vs  0  F4  │ │
│ └─────────────────────────┘ │
│                             │
│  — or empty state —         │
│  🥋 No matches yet          │
│  Create a new one!          │
└─────────────────────────────┘
```

## Match Card Design

- Background: `BJJColors.white` with rounded corners
- Top row: Match ID (`#abcd`) left, status badge right (colored by status)
- Middle row: F1 color dot + name + score, "vs", score + name + F2 color dot
- Bottom row: Advantages/Penalties compact badges
- Tap → navigate to MatchControlScreen

## Status Filter Chips

Horizontal row of `FilterChip` widgets:
- Default selected: `Waiting`, `In Progress`
- `Finished` and `Canceled` unselected by default
- Tapping toggles inclusion in the filter

## Empty State

When filtered list is empty:
- Center: 🥋 emoji (large)
- Text: "No matches yet"
- Subtitle: "Create a new one!"

## Navigation

- **FAB** (or header button): Navigate to CreateMatchScreen
- **Tap match card**: Set `activeMatchProvider` + navigate to MatchControlScreen
- Remove old search bar and Quick Start section
