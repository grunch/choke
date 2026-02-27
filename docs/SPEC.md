# BJJ Match Scoring and Publishing App (via Nostr)

App description: "A modern decentralized BJJ match scoring and publishing app via Nostr"

## Overview

Through the app, we can create Nostr events for matches by simply entering the fighters' names, the duration of the match and optionally their colors. The match creator is the only one who can start and update the match results from the app. All updates will be visible in real time on a web dashboard that we will build in the future (not part of the current scope). All data transport and security are handled using Nostr.

## Current Scope

Fetch events from nostr relays in real time, the events we are fetching are authored by the user (pubkey field == user's pubkey), kind 31415, only display on the home screen the ones with creation time less than 24 hours. Only show by default the events in waiting and in-progress status, with a filter where the user can filter by other statuses.

---

## Nostr Protocol

### Event Form

- **Kind**: 31415 (addressable event → NIP-1)
- **Uniqueness key**: (kind, pubkey, "d")
- **Replace rule**: newest `created_at` wins for the same (kind, pubkey, d)
- **Tags**:
  - `["d", "<match_id>"]` — 4-hex ID (e.g., "abcd")
  - `["expiration", "<unix_ts>"]` (NIP-40) for auto-prune after finish (1 week from now)
- **Content**: serialized JSON (UTF-8)

### Content Schema (JSON)

```json
{
  "id": "abcd",
  "status": "waiting | in-progress | finished | canceled",
  "start_at": 123456789,
  "duration": 300,
  "f1_name": "string",
  "f2_name": "string",
  "f1_color": "#RRGGBB",
  "f2_color": "#RRGGBB",
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

> **Score = pt2×2 + pt3×3 + pt4×4** (per fighter)

### Field Definitions

- **pt_n** (integer) — Points for each fighter:
  - pt2, pt3, pt4 represent movements worth 2, 3, or 4 points
  - Total score = (pt2 × 2) + (pt3 × 3) + (pt4 × 4)
- **adv** (integer) — Advantages, incremented or decremented by 1
- **pen** (integer) — Penalties, incremented or decremented by 1
- **color** (string) — Hexadecimal color code, typically representing the gi color
- **duration** (integer) — Countdown length in seconds (default: 300)
- **start_at** (integer) — Unix timestamp when match started

### Status Enum

- `waiting` — Match created, not started
- `in-progress` — Match running, timer counting down
- `finished` — Match completed
- `canceled` — Match canceled

---

## Identity & Keys

- On install, app generates a keypair
- Signing: sign all events with the user's private key (nsec)
- Discovery: share npub or QR of pubkey to filter on the dashboard (NIP-19 encoding)
- Team mode (optional): user may voluntarily share the private key with teammates if a tournament requires multiple scorers
- Keys stored locally; expose npub/QR for discovery, nsec only if user explicitly opts in
- Consider passcode/biometric to reveal/copy nsec
- User can import nsec (recovery/delegation)

### Account Screen

- Show masked nsec (hidden by default) and npub
- Copy to clipboard for both
- Export pubkey as QR code
- Import nsec field

---

## Lifecycle

1. **Create match** — Generate match_id (4 hex chars), publish event with status: `waiting`
2. **Start** — Update same address with status: `in-progress`, `start_at` = now
3. **In-match updates** — For each action (points/advantages/penalties), publish replacement event
4. **Finish / Cancel** — Publish replacement with status: `finished` or `canceled`, add expiration tag (now + 1 week)
5. **Expire never-started matches** — If match stays `waiting` beyond policy window, publish with status: `canceled`

Always publish the expiration tag.

---

## Relays

- Publish to ≥2 relays for redundancy
- Default relays:
  - `wss://relay.mostro.network`
  - `wss://nos.lol`
- Dashboard should subscribe to same relay set; allow users to add relays

---

## Validation (Client-Side)

- Ensure match_id is 4 hex chars
- Enforce duration >= 0
- Keep counters non-negative integers (no negative points)
- Allow only the creator key (matching pubkey) to update that (kind, pubkey, d)

---

## UI Behavior

### Home Screen

- Show events kind 31415 with status `waiting`, `in-progress` (default filter)
- Filter option to show `finished` and `canceled` statuses
- Only show events created in last 24 hours
- Only show events authored by the current user
- Show only the last addressable event per match (dedup by d tag)
- Display as cards: ID, color-coded, "f1_name SCORE vs SCORE f2_name"
- Tap card → enter match detail
- If no matches: show 🥋 emoji + "No matches yet, create a new one!" message

### Match Creation

- Input: fighter names, duration (default 300s), optional colors
- Generates 4-hex match_id
- Publishes kind 31415 event with status: `waiting`

### Match Control (Detail Screen)

- Start Match → status: `in-progress`, countdown timer begins
- Timer: second-by-second countdown from `duration`
- Score buttons: +2, +3, +4 for each fighter
- Advantage/Penalty: +1 for each fighter
- No negative values allowed
- Each action publishes updated replacement event

---

## Examples

### Newly Created Match (waiting)

```json
{
  "id": "abcd",
  "status": "waiting",
  "start_at": 123456789,
  "duration": 600,
  "f1_name": "Roger Gracie",
  "f2_name": "Buchecha",
  "f1_color": "#aabbcc",
  "f2_color": "#ccddee",
  "f1_pt2": 0, "f2_pt2": 0,
  "f1_pt3": 0, "f2_pt3": 0,
  "f1_pt4": 0, "f2_pt4": 0,
  "f1_adv": 0, "f2_adv": 0,
  "f1_pen": 0, "f2_pen": 0
}
```

### Match in Progress

```json
{
  "id": "abcd",
  "status": "in-progress",
  "start_at": 123456789,
  "duration": 600,
  "f1_name": "Roger Gracie",
  "f2_name": "Buchecha",
  "f1_color": "#aabbcc",
  "f2_color": "#ccddee",
  "f1_pt2": 1, "f2_pt2": 0,
  "f1_pt3": 0, "f2_pt3": 0,
  "f1_pt4": 0, "f2_pt4": 0,
  "f1_adv": 0, "f2_adv": 0,
  "f1_pen": 1, "f2_pen": 1
}
```

In this example, f1 is winning 2–0 (pt2=1 → 2×1=2 points).

---

## Security & Privacy

- Keys stored locally
- Content is public; avoid PII beyond fighter names/colors
- Passcode/biometric recommended to reveal nsec
- nsec sharing is voluntary (team mode)
