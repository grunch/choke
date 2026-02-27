# Choke 🥋⚡

A modern decentralized BJJ match scoring and publishing app via Nostr.

## What is Choke?

Choke lets you create, score, and publish Brazilian Jiu-Jitsu matches in real time using the Nostr protocol. Every scoring action is broadcast as a Nostr event, making match data open, verifiable, and accessible from any compatible dashboard.

## Features

- **Real-time scoring** — Takedowns (2pts), Guard Passes (3pts), Mount/Back Takes (4pts), Advantages, Penalties
- **Countdown timer** — Configurable match duration with second-by-second countdown
- **Decentralized** — All data published via Nostr (kind 31415 addressable events)
- **No accounts needed** — Nostr keypair generated on install
- **Delegation without nsec sharing** — Ephemeral match keys for team scoring
- **Live dashboard** — Web viewer for spectators and tournament projection (coming soon)

## Tech Stack

- **Mobile**: Flutter (Android & iOS)
- **State Management**: Riverpod
- **Protocol**: Nostr (nostr_tools)
- **Security**: flutter_secure_storage for key management
- **Design**: Custom BJJ-inspired theme

## Brand Colors

| Color | HEX | Usage |
|-------|-----|-------|
| Navy Black | `#121A2E` | Backgrounds |
| BJJ Green | `#1BA34E` | Actions & CTAs |
| Championship Gold | `#F5B800` | Accents & Awards |
| Pure White | `#FFFFFF` | Text & Cards |

See [BJJ_STYLE_GUIDE.md](BJJ_STYLE_GUIDE.md) for complete style guide.

## Getting Started

### Prerequisites

- Flutter SDK (^3.11.0)
- Dart SDK (^3.11.0)
- Android Studio / Xcode (for mobile builds)

### Installation

```bash
# Clone the repository
git clone https://github.com/grunch/choke.git
cd choke

# Install dependencies
flutter pub get

# Run code generation (if needed)
flutter pub run build_runner build

# Run the app
flutter run
```

### Build for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Architecture

```
lib/
├── features/       # Feature-based modules
├── data/          # Models and repositories
├── services/      # Nostr and key management
└── shared/        # Theme, widgets, utilities
```

## Nostr Integration

Choke uses NIP-25 events for match data and NIP-59 gift wrap for private communications between scorers.

### Event Kinds

- `31415` — Match events (addressable)
- `1059` — Gift wrap (encrypted)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [AGENTS.md](AGENTS.md) for development conventions.

## License

MIT License — see LICENSE file for details.

## Connect

- GitHub: [@grunch/choke](https://github.com/grunch/choke)
- Nostr: `npub14e8x7ggcvgy4j0wcsqh6kv4pfmtax7rkryenux9u7ytemjcuce7q9qpjtk`

---

Built with 🥋 and ⚡ by the BJJ & Bitcoin community.
