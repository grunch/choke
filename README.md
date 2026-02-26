# Choke 🥋⚡

A modern decentralized BJJ match scoring and publishing app via Nostr.

## What is Choke?

Choke lets you create, score, and publish Brazilian Jiu-Jitsu matches in real time using the Nostr protocol. Every scoring action is broadcast as a Nostr event, making match data open, verifiable, and accessible from any compatible dashboard.

## Features

- **Real-time scoring** — Takedowns (2pts), Guard Passes (3pts), Mount/Back Takes (4pts), Advantages, Penalties
- **Countdown timer** — Configurable match duration with second-by-second countdown
- **Decentralized** — All data published via Nostr (kind 31925 addressable events)
- **No accounts needed** — Nostr keypair generated on install
- **Delegation without nsec sharing** — Ephemeral match keys for team scoring
- **Live dashboard** — Web viewer for spectators and tournament projection (coming soon)

## Tech Stack

- **Mobile**: Flutter (Android & iOS)
- **Protocol**: Nostr (NIP-1 addressable events, NIP-19, NIP-40)
- **Relays**: `wss://relay.mostro.network`, `wss://nos.lol`

## Scoring (IBJJF Rules)

| Action | Points |
|--------|--------|
| Takedown | 2 |
| Sweep | 2 |
| Knee on Belly | 2 |
| Guard Pass | 3 |
| Back Take | 4 |
| Mount | 4 |

**Score = pt2×2 + pt3×3 + pt4×4**

## Development

```bash
flutter pub get
flutter run
```

## License

TBD
