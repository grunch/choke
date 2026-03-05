# Changelog

## [v1.1.0] - 2026-03-05

### Added
- feat: add multi-language support — EN, ES, PT, JA (closes #42) (9c51752)

### Fixed
- fix: pin intl to ^0.20.0 (required by flutter_localizations) (d12d039)
- fix: apply CodeRabbit review fixes (2a3ef8c)

### Changed
- chore: update changelog and version for v1.1.0 (eb9311a)
- chore: update changelog and version for v1.0.1 (92ec666)


## [v1.1.0] - 2026-03-05

### Added
- feat: add multi-language support — EN, ES, PT, JA (closes #42) (9c51752)

### Fixed
- fix: apply CodeRabbit review fixes (2a3ef8c)

### Changed
- chore: update changelog and version for v1.0.1 (92ec666)


## [v1.0.1] - 2026-03-04

### Added
- feat: add tag-based release workflow with changelog generation (c1d8660)
- feat: update app icon and splash screen with Choke mascot (7186dfe)
- feat: add mutation testing with mutation_test package (ddf31d0)
- feat: remove unused settings items (f301a72)
- feat: relay management screen (closes #9) (ab0cad9)
- feat: add app icon and splash screen with BJJ bird logo (3ddd004)
- feat: display match list from Nostr events on home screen (#5) (2d17ef1)
- feat: implement match control screen with scoring, timer, and live updates (#7) (b6f34b2)
- feat: implement match creation form and Nostr event publishing (#6) (bb108e1)
- feat: implement Match data model with Nostr integration (46b4865)
- feat: implement Nostr service (issue #3) (dc60181)
- feat: implement issue #2 - Key management system (89f5520)
- feat: redesign Home and Match screens with healthcare app layout (133409c)
- feat: implement issue #1 - Flutter project setup with BJJ theme (8edeff5)

### Fixed
- fix: apply CodeRabbit review — use tag ref for changelog, fix push to main (a606926)
- fix: add padding to foreground icon for adaptive safe zone (98477d2)
- fix: make icon fill the full circle on Android 12+ (56ce329)
- fix: add pull_request trigger and clarify workflow activation (4de864f)
- fix: correct mutation_test.xml regex format and fix failing tests (152538e)
- fix: return bool from _confirmDelete for Dismissible confirmDismiss (f43bd77)
- fix: address all CodeRabbit review comments (issue #9) (f0699c7)
- fix: validate public key derivation on init and use KeyApi for key generation (d56d103)
- fix: show all match statuses by default on home screen (b4b3e29)
- fix: update home feed immediately on match state changes (cbf9b1d)
- fix: address CodeRabbit review on PR #28 (3d87f83)
- fix: address CodeRabbit review on PR #26 (2fe5b3d)
- fix: use kebab-case for match status serialization (491cb2e)
- fix: address CodeRabbit review comments on PR #24 (6a079da)
- fix: ensure events are actually published to relays (cdbc22c)
- fix: initialize NostrService on app start to connect relays (4838fe3)
- fix: address CodeRabbit review comments on PR #21 (039a6c5)
- fix: address CodeRabbit review comments on PR #20 (bc75f54)
- fix: address all remaining CodeRabbit review comments (d5c35b4)
- fix: address StreamSubscription memory leak (CodeRabbit) (7d3e29c)
- fix: address all CodeRabbit review comments on PR #16 (462220e)
- fix: wrap QrImageView in SizedBox to fix hit-test error (acfed38)
- fix: use StatefulBuilder for import dialog state management (b1f0827)
- fix: address remaining CodeRabbit review comments (9d36ee7)
- fix: address CodeRabbit review comments (cfed702)
- fix: resolve KeyManager compilation errors (59901d5)
- fix: replace qr_code_scanner with mobile_scanner for AGP 8 compatibility (49f2939)
- fix: lower Dart SDK constraint for compatibility (6504748)

### Documentation
- docs: fix HTML report filename (826077f)
- docs: fix HTML report opening instruction (cross-platform) (d56f7ae)
- docs: replace logo with smaller version (712a023)
- docs: add logo to README and remove NIP-59 references (7fcd9c9)
- docs: add markdown linting and widget guidelines to AGENTS.md (f957bf5)
- docs: update PR reference to #20 (1798fa8)
- docs: add README and full spec document (940b5b6)

### Changed
- Avoid partial cache mutation before key validation succeeds. (156a612)
- chore: stop tracking GeneratedPluginRegistrant.swift, commit pubspec.lock (3ad9541)
- cleanup: remove Match Types and Gyms Near You sections from home screen (db64983)
- Update gitignore (915bf03)
- refactor: change Nostr event kind from 38000 to 31415 (d87defa)
- refactor: change Nostr event kind from 31925 to 38000 (4b33be8)
- refactor: add fromNostrToolsEvent factory for bidirectional conversion (572d64a)
- refactor: use nostr_tools APIs instead of manual crypto (542c436)


All notable changes to the Choke project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file is automatically updated by the release workflow when a new version tag is pushed.
