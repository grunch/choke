# AGENTS.md — Choke Development Guidelines

Conventions and guidelines for humans and AI agents working on the Choke
project. Read this before making changes.

## Language: English only (non-negotiable)

**Everything produced in this repository MUST be written in English**, with no
exceptions:

- Source code — identifiers, function/variable/class names
- Comments and docstrings
- Commit messages
- Branch names
- Pull request titles and descriptions
- Issue titles and descriptions, and issue comments
- Documentation, READMEs, and specs
- Code review comments

The **only** exception is user-facing product copy, which is localized through
the l10n system (`lib/l10n/*.arb`) and legitimately contains other languages
(English, Spanish, Portuguese, Japanese). Everything a developer writes stays in
English regardless of the contributor's native language.

## Sensitive code lives in Rust (non-negotiable)

Dart is for UI and state. **Everything security-sensitive or protocol-critical
is implemented in the Rust crate** (`rust/`) and reached only through the
generated `flutter_rust_bridge` bindings (`lib/src/rust/`):

- **Cryptography** — key generation, public-key derivation, event signing and
  verification, NIP-19 (`npub`/`nsec`) encoding and decoding
  (`rust/src/api/crypto.rs`)
- **Nostr protocol** — event ids, serialization, subscriptions, publishing
- **Relay networking** — every WebSocket a relay sees is opened by the Rust
  relay pool (`rust/src/api/relay.rs`), never by Dart

Rules for agents:

1. **Never implement crypto in Dart** — no signing, no hashing keys, no bech32,
   not even "temporarily". Call the `NostrCrypto` interface
   (`lib/services/nostr/crypto/`), which is backed by `RustNostrCrypto`.
2. **Never open connections to relays from Dart.** Relay traffic goes through
   the `NostrRelayBackend` interface (`lib/services/nostr/relay/`), backed by
   `RustRelayBackend`.
3. **Never add Dart dependencies for crypto or Nostr networking** to
   `pubspec.yaml`. If a capability is missing, extend the Rust crate under
   `rust/src/api/`, regenerate the bindings, and expose it through the existing
   Dart interfaces.
4. The Dart interfaces are the seam: app code talks to `NostrCrypto` /
   `NostrRelayBackend`, never to a crypto library or a socket directly. New
   sensitive capability = new method on the interface + Rust implementation.

Known deviation (do not copy): `testRelayConnectivity` in
`lib/features/settings/providers/relay_config_provider.dart` opens a raw
WebSocket from Dart to health-check a relay URL before saving it. It is the
only Dart-side relay connection in the app and it is **not** a precedent for
new Dart-side networking. PR #158 moves it into the crate (`relay_probe`);
once that merges, delete this paragraph.

## Project Overview

Choke is a modern decentralized BJJ (Brazilian Jiu-Jitsu) match scoring and
publishing app. It creates, scores, and publishes matches in real time over
Nostr — every scoring action is broadcast as a Nostr event (kind `31415`,
addressable) so match data is open, verifiable, and readable by any compatible
dashboard.

Built with **Flutter** (Android & iOS) on top of a native **Rust** crate that
provides the entire Nostr stack.

## Architecture

Feature-based structure:

```text
lib/
├── main.dart
├── features/          # Feature modules
│   ├── home/          # Home screen and dashboard
│   ├── match/         # Match scoring, timer, and management
│   ├── account/       # User profile and keys
│   └── settings/      # App configuration and relays
├── services/          # Cross-feature services
├── shared/            # Reusable widgets, theme, utilities
├── l10n/              # Localization (.arb) — the ONLY non-English content
└── src/rust/          # Generated Dart bindings for the Rust crate (do not edit)
```

The native Nostr surface lives outside `lib/`:

| Path | What it is |
|---|---|
| `rust/` | the crate — key handling, NIP-19, event signing, relay pool |
| `lib/src/rust/` | generated Dart bindings (committed; never edit by hand) |
| `rust_builder/` | Cargokit glue that builds the crate for each platform |

## Tech Stack

- **Mobile**: Flutter (Android & iOS)
- **State Management**: Riverpod (`flutter_riverpod`, `riverpod_annotation`)
- **Navigation**: `go_router`
- **Protocol**: Nostr via the Rust [`nostr`](https://crates.io/crates/nostr) and
  [`nostr-sdk`](https://crates.io/crates/nostr-sdk) crates, bridged with
  `flutter_rust_bridge`
- **Native**: Rust crate (`rust/`) — required to build or test the app
- **Security**: `flutter_secure_storage` for key management
- **Codegen**: `freezed`, `json_serializable`, `riverpod_generator`

## Design System

### Colors (BJJ Brand Palette)

| Color | HEX | Usage |
|-------|-----|-------|
| Navy Black | `#121A2E` | Backgrounds, dark surfaces |
| BJJ Green | `#1BA34E` | Primary actions, CTAs, success |
| Championship Gold | `#F5B800` | Accents, badges, awards |
| Pure White | `#FFFFFF` | Text on dark, cards |

**Always use colors from `AppTheme` or `BJJColors`, never hardcode hex values.**
See [BJJ_STYLE_GUIDE.md](BJJ_STYLE_GUIDE.md) for the full style guide.

### Typography

- Headlines: White (`BJJColors.white`)
- Body text: Grey Light (`BJJColors.greyLight`)
- Labels/Tags: Green (`BJJColors.green`)
- Stats/Numbers: Gold (`BJJColors.gold`)

## Code Style

### Flutter / Dart

Run the full check chain before every commit:

```bash
flutter pub get && dart format . && flutter analyze && flutter test
```

### Naming Conventions

- Files: `snake_case.dart`
- Classes / types: `PascalCase`
- Variables / functions: `camelCase`
- Constants: `kConstantName` or `CONSTANT_NAME`

### Widget Guidelines

- Use `const` constructors when possible
- Extract reusable widgets to `shared/`
- Keep widgets small and focused
- Use Riverpod for state management
- **Never hardcode color hex values** — always use `BJJColors` or `AppTheme`
- **Never expose raw exceptions in the UI** — show generic, user-friendly
  messages and log details with `debugPrint`

### Code Generation

Run after modifying models, providers, or Freezed classes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## The Rust Crate

Building the app compiles the crate automatically — no separate step needed.
Two cases do need a command:

```bash
# After changing anything under rust/src/api/, regenerate the bindings.
# The codegen CLI version must match flutter_rust_bridge in pubspec.yaml and
# rust/Cargo.toml — all three are pinned together.
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
flutter_rust_bridge_codegen generate

# Tests that exercise crypto or the relay pool need the native library on disk.
# Without it they skip themselves silently, so build the crate first:
cargo build --manifest-path rust/Cargo.toml
flutter test --tags rust
```

Crate quality gate (mirrors CI in `.github/workflows/rust.yml`):

```bash
cargo fmt --manifest-path rust/Cargo.toml --all -- --check
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml
```

## Nostr Integration

- Match data is published as Nostr addressable events, kind `31415`.
- Key handling, NIP-19, signing, and the relay pool all live in the Rust crate —
  reach them through the generated bindings, never reimplement crypto in Dart.
  See [Sensitive code lives in Rust](#sensitive-code-lives-in-rust-non-negotiable)
  at the top of this file — those rules are binding.

## Security

- **NEVER** log private keys.
- **NEVER** expose `nsec` in the UI.
- Use ephemeral match keys for team scoring (delegation without sharing `nsec`).
- Store keys with `flutter_secure_storage`; back up and restore encrypted.

## Testing

- Unit tests for models and logic
- Widget tests for UI components
- Integration tests for critical flows
- Tests that need the native library are tagged `rust` — see the crate section

## Git Workflow

1. Never commit directly to `main`; branch first: `git checkout -b feat/name`.
2. Make changes following these conventions.
3. Run the full check chain before committing.
4. Commit with [Conventional Commits](https://www.conventionalcommits.org):
   `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`.
5. Push and open a PR. On merge, only the tests re-run on `main`; the APK build
   runs on PRs. Releases are built from `v*` tags by `.github/workflows/release.yml`.
6. **Agents: subscribe to the PR you just opened** (`subscribe_pr_activity`), and
   stay subscribed until it is merged or closed. Opening a PR is not the end of
   the task — CI failures and review comments on it are yours to drive to green
   or to answer, without waiting to be asked.

All commits, branches, PRs, and issues are written in **English** (see the top
of this file).

## Markdown

- Always add a language identifier to fenced code blocks (MD040):
  - ✅ ` ```dart ` / ` ```json ` / ` ```text `
  - ❌ ` ``` ` (bare fence)

## Documentation

- Document all public APIs.
- Add inline comments for non-obvious logic (why, not what).
- Update `README.md` and relevant specs under `docs/` for new features.

## Contact

- Repo: <https://github.com/protolayer-io/choke>
- Nostr: `npub14e8x7ggcvgy4j0wcsqh6kv4pfmtax7rkryenux9u7ytemjcuce7q9qpjtk`
