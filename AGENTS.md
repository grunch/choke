# AGENTS.md — Choke Development Guidelines

This file contains conventions and guidelines for AI agents working on the Choke project.

## Project Overview

Choke is a modern decentralized BJJ (Brazilian Jiu-Jitsu) match scoring and publishing app built with Flutter and Nostr.

## Architecture

### Feature-Based Structure

```
lib/
├── features/
│   ├── home/          # Home screen and dashboard
│   ├── match/         # Match scoring and management
│   ├── account/       # User profile and keys
│   └── settings/      # App configuration
├── data/
│   ├── models/        # Data models (Freezed)
│   └── repositories/  # Data access layer
├── services/
│   ├── nostr/         # Nostr protocol integration
│   └── key_management/# Secure key storage
└── shared/
    ├── widgets/       # Reusable UI components
    ├── utils/         # Helper functions
    └── theme/         # App theme and colors
```

## Design System

### Colors (BJJ Brand Palette)

| Color | HEX | Usage |
|-------|-----|-------|
| Navy Black | `#121A2E` | Backgrounds, dark surfaces |
| BJJ Green | `#1BA34E` | Primary actions, CTAs, success |
| Championship Gold | `#F5B800` | Accents, badges, awards |
| Pure White | `#FFFFFF` | Text on dark, cards |

**Always use colors from `AppTheme` or `BJJColors`, never hardcode.**

### Typography

- Headlines: White (`BJJColors.white`)
- Body text: Grey Light (`BJJColors.greyLight`)
- Labels/Tags: Green (`BJJColors.green`)
- Stats/Numbers: Gold (`BJJColors.gold`)

## Dependencies

### Core
- `flutter_riverpod` — State management
- `go_router` — Navigation (to be implemented)
- `nostr_tools` — Nostr protocol
- `flutter_secure_storage` — Key storage

### Code Generation
- `freezed` — Immutable data classes
- `json_serializable` — JSON serialization
- `riverpod_generator` — Riverpod code gen

**Always run `flutter pub run build_runner build` after modifying models.**

## Code Style

### Flutter/Dart

1. **Format:** `dart format .`
2. **Analyze:** `flutter analyze`
3. **Test:** `flutter test`

**Chain:** `flutter pub get && dart format . && flutter analyze && flutter test`

### Naming Conventions

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `kConstantName` or `CONSTANT_NAME`

### Widget Guidelines

- Use `const` constructors when possible
- Extract reusable widgets to `shared/widgets/`
- Keep widgets small and focused
- Use Riverpod for state management

## State Management (Riverpod)

```dart
// Provider
final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) {
  return MatchNotifier();
});

// Usage
class MatchScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchProvider);
    // ...
  }
}
```

## Nostr Integration

- Use `nostr_tools` package
- All events should be kind 31925 (addressable events)
- Implement NIP-59 gift wrap for private communications
- Store keys securely with `flutter_secure_storage`

## Security

- NEVER log private keys
- NEVER expose nsec in UI
- Use ephemeral keys for match scoring
- Implement key backup/restore with encryption

## Git Workflow

1. Create feature branch: `git checkout -b feature/name`
2. Make changes following conventions
3. Run full check chain before commit
4. Commit with conventional messages
5. Push and create PR

## Testing

- Unit tests for models and logic
- Widget tests for UI components
- Integration tests for critical flows

## Documentation

- Document all public APIs
- Add inline comments for complex logic
- Update README.md for new features

## Contact

- Repo: https://github.com/grunch/choke
- Nostr: npub14e8x7ggcvgy4j0wcsqh6kv4pfmtax7rkryenux9u7ytemjcuce7q9qpjtk
