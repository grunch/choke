# Changelog

## [v2.1.1] - 2026-08-14

### Added
- feat: build a universal macOS bundle on every release (9d458eb)
- feat: keep the screen awake between fights on a watched board (97d8ef4)

### Fixed
- fix: drop keychain-access-groups from macOS entitlements (359430c)
- fix: expire a scoreboard match when its freshness window passes (7d0082e)

### Documentation
- docs: add Play Store badge and demo video (5311226)

### Changed
- chore: remove temporary macOS smoke workflow (f49e9eb)
- chore: update changelog and version for v2.1.0 (da64092)


## [v2.1.0] - 2026-08-05

### Added
- feat: send the board link from under its own QR code (bb97d67)
- feat: reach Chromebooks (8b810d6)

### Fixed
- fix: stop shrinking the share button's tap target (68ca796)
- fix: reject a -PchokeAbis that names no ABI (513d4a1)
- fix: ship the 32-bit ARM devices Play was hiding the app from (8cb8b04)
- fix: one Spanish, and it is tuteo (fb50743)

### Changed
- refactor: one share control per screen, in the same place on both (be559d1)
- chore: update changelog and version for v2.0.2 (072e3b1)


## [v2.0.2] - 2026-08-03

### Added
- feat: tap the link under a QR code to copy it (9c71569)
- feat: the announcement allowlist ships with three real keys (db40e42)
- feat: refuse to publish an announcement the app would drop (0098af1)
- feat: put the announcements behind a bell that is usually not there (d5c9b92)
- feat: give the channel an off switch that acts at the tap (65aae36)
- feat: fetch announcements, and keep only what still holds (7bd3497)
- feat: read an announcement without trusting anything about it (c95f692)

### Fixed
- fix: bounds the tool accepts and the app rejects, and an --out that ate a path (50b5772)
- fix: notice a link that opened nothing, and label the bell's dot (35c689d)
- fix: discard a cache read that a clear outran (c988bd6)
- fix: address the review on the fetch phase (275ede7)
- fix: address the review on the parsing phase (4f61aef)
- fix: warn about an expiry the freshness window will cut short (81d7d03)
- fix: make the announcements reachable without a gesture (08e57e1)
- fix: re-read the switch after the disk, not before it (accc237)
- fix: order the writes, and tell the relays when the inbox goes away (603b311)
- fix: fail an oversized version as unreadable, not as an exception (0c3c285)

### Documentation
- docs: name the nested fields as nested, and label a bare fence (18c3e83)
- docs: how to publish an announcement, and a nak line that never worked (a265e90)
- docs: close the gaps a spec can hide behind (306f2c9)
- docs: specify one authenticated way to speak to the app (83df1f0)

### Changed
- test: an inbox suite that expired the day after it was written (ea13092)
- chore: update changelog and version for v2.0.1 (fe07daa)


## [v2.0.1] - 2026-08-01

### Added
- feat: the organizer's own board, as a code for the room (27ff7f0)
- feat: share a match from the feed you already have open (89f7b0e)
- feat: give a spectator a way to send one fight (3ccaf87)
- feat: let a match link wait before it gives up (febd25f)
- feat: read a link that names one match, not just a board (f727e74)
- feat: credit bjjscore.live along the bottom of the wall board (33470ef)
- feat: let a watched board be handed on, by link or by QR (d561214)

### Fixed
- fix: cover the truncation itself, and stop the error naming a format (5e3386a)
- fix: name the organizer wrong and hear about it in release too (e6b6c9e)
- fix: a probe that cannot run is unreachable, not an exception (7fa725f)
- fix: set the match request before the pubkey that rebuilds the feed (8dbec65)
- fix: stop blaming the pubkey for a link the match id broke (f9cda65)
- fix: let the credit wrap instead of cutting its own call to action (fa8f454)
- fix: stop truncating the link under its own QR code (ad21e64)
- fix: point the license notice at the license instead of a missing copy (e3adc55)

### Documentation
- docs: describe what shipped, and name the gap it left (c403d25)
- docs: the relay-networking rule has no exceptions left (df963ed)
- docs: settle the backstop note, and drop a controller nobody writes to (7eece2e)
- docs: point the relay-networking rule at its own known deviation (f8140ba)
- docs: make watching an opened PR part of the git workflow (9ea1ad0)
- docs: point the known-deviation note at PR #158 (65047b5)
- docs: state the Rust boundary as a binding rule in AGENTS.md (82158a8)
- docs: settle how a match value is parsed, and what a lookup is keyed by (a2acd1e)
- docs: correct the spec against what the two readers actually do (06cab4b)
- docs: close the gaps CodeRabbit found in the match-link spec (9fc62b0)
- docs: mark the spec agreed, and say what to build first (0502d74)
- docs: settle where a match gets shared from (da4868c)
- docs: specify links to one particular match (d7ae208)

### Changed
- refactor: npub is what people are handed, so it is what they are shown (8853aeb)
- refactor: one match-share path, and a tap target that is what it looks like (6ca5180)
- refactor: move the Settings relay probe into the Rust crate (59be438)
- refactor: open the share sheet in one place instead of three (6391426)
- refactor: read a shared link's key from npub, and only npub (9ff35d0)
- refactor: give the board credit the shape of a place to go (97388d9)
- chore: stop handing a write token to jobs that only build (ce6c810)
- chore: move CI actions off the deprecated Node 20 runtime (040b4d6)
- chore: update changelog and version for v2.0.0 (dbdbb07)


## [v2.0.0] - 2026-07-27

### Added
- feat: build a Windows binary on release (9e8f193)
- feat: keep the screen awake while watching a board (e492088)
- feat: paint the board in design 3A when the app is in a light theme (be6badf)

### Fixed
- fix: bootstrap flutter before piping its version into jq (ace6b89)
- fix: stop an expired match from crashing the app when it is reopened (013a711)
- fix: drop the select that could freeze the board on a stale match (ee1f3b5)
- fix: address the review findings on this PR (2c6e1fc)
- fix: address the reviewer findings on this PR (e79dc22)
- fix: address the review findings on this PR (c1c4d6e)
- fix: address the review findings on this PR (071a59a)
- fix: address the review findings on this PR (9add175)

### Changed
- perf: repaint the board the moment its clock actually changes (98ae04b)
- refactor: reference the app's gold instead of repeating it (7fbf7c8)
- chore: update changelog and version for v1.6.6 (54640f9)


## [v1.6.6] - 2026-07-26

### Added
- feat: filter the scoreboard by status, as home does (9ceac00)
- feat: open shared board links in the app (ff574e0)
- feat: add a read-only scoreboard for watching another pubkey's matches (abdca7a)
- feat: add NIP-19 npub decoding (8a9bcb5)
- feat: keep the screen awake while a match is being scored (e90fcef)

### Fixed
- fix: address the review findings on this PR (f72daeb)
- fix: address the review findings on this PR (edd5777)
- fix: address the review findings on this PR (5d1d5be)
- fix: clear the stack when a shared link arrives (5399959)
- fix: resolve equal-timestamp revisions by NIP-01's id tie-break (a0880b5)
- fix: say so when a shared link's pubkey cannot be read (2c3e461)
- fix: address the review findings on this PR (2d318a3)
- fix: make the scoreboard header icon legible (1e3484b)
- fix: keep scoreboard subscription ids inside NIP-01's limit (e9edf44)
- fix: keep the home feed to this user's own matches (470c78b)
- fix: bound the wakelock call and keep tests off the platform channel (b17c879)

### Changed
- refactor: fold the broken-link state into the shared placeholder (be0e94c)
- chore: update changelog and version for v1.6.5 (34fef4a)
- chore: update changelog and version for v1.6.4 (8c66799)


## [v1.6.5] - 2026-07-26

### Added
- feat: keep the screen awake while a match is being scored (e90fcef)

### Fixed
- fix: bound the wakelock call and keep tests off the platform channel (b17c879)

### Changed
- chore: update changelog and version for v1.6.4 (8c66799)


## [v1.6.4] - 2026-07-26

### Added
- feat: swap the end horn for a harder, lower klaxon (fd88bb9)
- feat: let Settings mute the match cues (880b99b)
- feat: sound the match clock — a bell on start, a horn at zero (e5f53a3)

### Fixed
- fix: address CodeRabbit review on the match cues (c01cb60)
- fix: let a reconnect actually reset the sweep pace; share the relay defaults (4ec57dc)
- fix: stop shipping a rate-limited relay, and back off when refused (72191b3)
- fix: publish on the first relay acceptance, not the slowest (5c5d92a)
- fix: do not accept a language choice that was never stored (dcd947c)
- fix: persist the language selection across app restarts (ad45497)

### Documentation
- docs: correct the publishEvent contract, time the burst test (48b07fd)

### Changed
- chore: update changelog and version for v1.6.3 (fbac68a)


## [v1.6.3] - 2026-07-20

### Added
- feat: put the splash mark on a light disc over the navy background (6a036bd)
- feat: enlarge the C mark inside the home header tile (f0fb0ad)
- feat: adopt the new Choke C mark as the app icon across all platforms (08e90f0)
- feat: enable R8 minification and resource shrinking for release APK (2e357a4)

### Fixed
- fix: give the Android 12+ splash its own optically centred icon (55f0b21)
- fix: nudge the splash mark 2% left for optical balance (cf4dc28)
- fix: centre the splash mark on its ring, not its bounding box (598359c)

### Documentation
- docs: address CodeRabbit feedback on README, format codebase (f871227)
- docs: add testing and code coverage documentation to README.md (d0e5560)

### Changed
- chore: update changelog and version for v1.6.2 (3aae894)


## [v1.6.2] - 2026-07-19

### Fixed
- fix: address review — fail-closed coverage tooling, wss-only form, test hygiene (7297dcb)
- fix(relays): unreachable relay no longer hangs addRelay forever (e795a14)

### Changed
- test: raise hand-written-code coverage from 59% to 98.6% (a1448bc)
- chore: update changelog and version for v1.6.1 (a9ddcae)


## [v1.6.1] - 2026-07-18

### Fixed
- fix(create-match): show all durations at once, no horizontal scroll (e7fb968)

### Changed
- ci: complete the Linux toolchain, avoid tarbomb, document Linux install (dcfe073)
- ci: also build and publish a Linux x64 bundle on release (e70eac8)
- chore: update changelog and version for v1.6.0 (9802340)


## [v1.6.0] - 2026-07-18

### Added
- feat: add Website link to the top of Settings > About (2f3a815)
- feat: show brand C logo in the home header (67c9f8b)
- feat(linux): add desktop entry and window icon (510d597)
- feat: adopt the Choke C mark as the app icon and launch logo (a79b9ae)
- feat(account): share a bjjscore.live live-board link (530a168)

### Fixed
- fix: use original C logo on a light gray tile, no recolor (f300485)
- fix(settings): lighten the black belt backdrop in dark theme (c473cde)
- fix(account): handle share sheet failure (9b8613d)

### Documentation
- docs: document the Linux desktop build requirements (46752e9)
- docs: use privacy@ contact email in privacy policy (90b5fa0)
- docs: use contact email instead of npub in privacy policy (acdcb6a)
- docs: add privacy policy for Google Play (4c596ae)

### Changed
- chore: update changelog and version for v1.5.2 (caace2c)


## [v1.5.2] - 2026-07-17

### Documentation
- docs: rewrite AGENTS.md and require English across the repo (191814a)

### Changed
- ci: pin upload-google-play to a full commit SHA (e9e00a0)
- ci: auto-upload the .aab to Google Play on release (4d61bee)
- ci: restrict release tag validation to plain vX.Y.Z (44a0e19)
- ci: harden release workflow against tag template injection (d307186)
- ci: also build a signed .aab for Google Play in the release workflow (e8eb413)
- ci: skip Android APK build on merge to main (ed1f7c2)
- chore: update changelog and version for v1.5.1 (ffedd79)


## [v1.5.1] - 2026-07-16

### Added
- feat: allow cancelling a waiting match before it starts (24877ee)
- feat: review a match before starting; start via the clock button (032aacf)
- feat: replace home empty-state icon with mascot image (f410fc7)

### Changed
- chore: update changelog and version for v1.5.0 (aebfc08)


## [v1.5.0] - 2026-07-15

### Added
- feat: compact home status filters, default to active matches (978cf4d)
- feat: link black belt box to protolayer.io and drop credit underline (b9b6a6c)
- feat: rebrand settings footer to ProtoLayer with website link (c10cde1)
- feat(account): generate a new keypair from the account screen (1cdd7cb)

### Fixed
- fix: 44px min tap target for filter chips; free CI disk space (90380c1)
- Fix spanish submission translations (fb9e7fc)
- fix(account): refresh identity and handle errors on keypair generation (93b2201)
- fix: serialize relay operations and mute superseded watchers (2a914a6)
- fix: address review findings on the reconnect rebuild (eb8ffbf)
- fix: resume must never strand the relay transport (6bbb8c5)

### Documentation
- docs: clarify which files to commit after gen-l10n (4b55dbb)
- docs: add translations/i18n contributor guide and link it from README (f8bbe77)
- docs: add translations/i18n contributor guide and link it from README (cd4a7a7)

### Changed
- chore: relicense under GPL-3.0 and set copyright to ProtoLayer OÜ (73dfa0b)
- chore: point grunch/choke references to protolayer-io/choke (31b04c5)
- refactor: use InkWell + link semantics for footer credit (92fb57e)
- Revert "docs: add translations/i18n contributor guide and link it from README" (578f400)
- chore: update changelog and version for v1.4.0 (b0f514f)


## [Unreleased]

### Added
- feat(account): generate a new keypair from the account screen, guarded by a confirmation dialog that warns the current identity is lost if not backed up

## [v1.4.0] - 2026-07-14

### Added
- feat: tap the submission instead of typing it (1ed817b)
- feat(match): show the result, and let a wrong one be corrected (9e8550c)
- feat(match): ask the referee how the match ended (a2a5b62)
- feat(match): record how a match was won, and make penalties count (c286a94)
- add lib/**/test/** paths to rust CI (71471ee)
- feat(relay): make nostr-sdk the default transport (481c35b)
- feat(relay): add the nostr-sdk relay backend, proven by a transport contract (b8cc3b7)
- feat(crypto): make the Rust nostr crate the default backend (6b1b62b)
- feat(rust): implement NostrCrypto in Rust, proven equivalent by differential tests (2d58158)
- feat(rust): scaffold the Rust/flutter_rust_bridge toolchain (92737c0)

### Fixed
- fix: read the value of -PdebugSignRelease, not just its presence (8705b28)
- fix: sign releases with v3 as well as v2 (ff2d72d)
- fix: stop local builds from poisoning release updates (9b419f8)
- fix: make saving the submission list durable and ordered (cb65d24)
- fix(match): a correction is not an ending, and an answer must not vanish (cfea5fb)
- fix(match): carry the phase-2 fixes through the amend refactor (06c8b7a)
- fix(match): three ways the sheet could fail a referee (5fe4c97)
- fix(match): a match this app finished is not a legacy event (0ab6c8a)
- fix(ci): scope the arm64 filter to the release variant, not the Gradle run (b393cc5)
- fix(relay): closing a dead socket must not block the reconnect (e7c14ac)
- fix(relay): honest publish verdict, gated status, and fmt (755dc09)
- fix(relay): a connect still shaking hands must not hijack its replacement (50db868)
- fix(security): keep private-key material out of the device log (3dbb6e7)
- fix(ci): commit the Cargokit Gradle wiring the APK build needs (cfbe52f)
- fix: a socket swap must not poison the connection that replaces it (c5f481f)
- fix: every relay converges to the latest match state (1e1ca92)

### Documentation
- docs(spec): do not apply the penalty ladder to matches already refereed (fd7f8fa)
- docs(spec): the fourth penalty records, it does not decide (f9aa23c)
- docs(spec): tag the code fences with a language (MD040) (e384fd7)
- docs(spec): draws are real, and penalties cannot be a tiebreak (f5af9c6)
- docs(spec): apply the penalty ladder, categorise DQ reasons, always record ended_at (4be6bc2)
- docs: spec for recording how a match was won (9e891cd)
- docs(relay): document the transport interface; make Filter const (49f34f5)
- docs(migration): phase 0 spike results — pins, size budget, gotchas (7c89a4e)
- docs: spec for migrating nostr_tools to rust nostr-sdk via flutter_rust_bridge (fd1b1f0)

### Changed
- chore: rename the app id to io.protolayer.choke (8e7d13d)
- chore: remove the Match tab, which could only tell you to go somewhere else (c889878)
- test(match): a match cannot end before it starts (561ec57)
- ci: ship an arm64-only release APK (bd92427)
- test(relay): wait for the transport to connect, don't guess how long it takes (2a4b104)
- refactor(nostr): put a NostrRelayBackend seam under the relay layer (569567c)
- test,docs: close review gaps in the Rust crypto phase (5220df0)
- refactor(nostr): put a NostrCrypto seam between the app and its crypto library (472ba7f)
- ci: put sdkmanager on PATH before installing the NDK (62e1040)
- ci: give the runners what the Rust build actually needs (1c83061)
- chore: update changelog and version for v1.3.0 (13fc2a2)


## [v1.3.0] - 2026-07-12

### Added
- feat: pause and resume the match clock (58dc913)

### Fixed
- fix: local match updates always supersede stale feed timestamps (17a4f81)
- fix: make match publishing to Nostr reliable (72c39eb)
- fix: freeze the paused clock at the real time, not the last tick (347f013)
- fix: finish a match automatically when the clock reaches zero (dcfebb3)

### Changed
- Improve design (7dbb6ea)
- chore: update changelog and version for v1.2.1 (8d1c11b)


## [v1.2.1] - 2026-07-12

### Added
- feat: replace belt emoji footer with black belt image (a14a019)

### Changed
- Aplica sugerencias de revisión en tarjetas de estado (8865470)
- Rediseña pantalla de inicio: quita logo C y agranda badges de estado (f1a6e82)
- i18n: localize black belt image semanticLabel (8bd1a72)
- test: actualiza aserción del footer de solo lectura al texto combinado (6f43608)
- Permite ver el detalle de luchas finalizadas o canceladas en solo lectura (de64e77)
- Update lib/l10n/app_es.arb (798b080)
- Reemplaza 'combate' por 'lucha' en las traducciones al español (cac7beb)
- chore: update changelog and version for v1.2.0 (f67cc53)


## [v1.2.0] - 2026-07-11

### Added
- feat: app-wide redesign (turn 2) with light/dark theme support (d3f42d0)
- feat: horizontal thumb-rail scoring with hold-to-subtract (0957c7d)

### Fixed
- fix: address PR review — chip counts, brand gradient tokens, withValues (9aef05d)
- fix: address CodeRabbit review on HoldButton (2191770)
- fix: gate signing on keystore file existence, add secrets preflight (ca8eb78)
- fix: sign release APK with persistent upload keystore (1c64c1c)

### Documentation
- docs: add horizontal scoring mode specification (f1e5803)

### Changed
- chore: update changelog and version for v1.1.4 (95f5262)


## [v1.1.4] - 2026-03-07

### Added
- feat: add 'Built by Pana' footer with black belt badge in settings (7c71999)

### Fixed
- fix: localize 'Built by' text in footer (c6c7331)
- fix: handle packageInfo error state with explicit logging (4eed371)

### Changed
- test: add widget tests for settings footer (dc4c0a0)
- chore: update changelog and version for v1.1.3 (2698f56)


## [v1.1.3] - 2026-03-05

### Added
- feat: localize relay error messages (i18n) (112f400)
- feat: implement default match duration setting (e03f186)

### Fixed
- fix: add top padding to BottomNavigationBar icons (b6c0a08)
- fix: migrate remaining screens to Theme.of(context) (ac99160)
- fix: add 9-minute option and validate duration values (b059fe2)
- fix: use theme primary color for SnackBar backgrounds (a0c8fa6)
- fix: wire source code link to open GitHub repo (6c43f55)
- fix: migrate AccountScreen to use Theme.of(context) (da84c0b)

### Changed
- Reset loading state on add failure to avoid stuck spinner (880a95b)
- chore: update changelog and version for v1.1.2 (1477168)


## [v1.1.2] - 2026-03-05

### Added
- feat: show dynamic version in Settings (6e212ed)
- feat: add license support for multi-language apps (19f3f3d)
- feat: implement dark/light/system theme toggle (988088e)

### Fixed
- fix: truncate systemDefault text to avoid stretching (37326fa)
- fix: Japanese MIT License translation (d9e4b0b)
- fix: hydrate theme mode before first frame to avoid flash (cb0791a)

### Documentation
- docs: add DartDoc to ChokeApp, ThemeModeNotifier and setThemeMode (227647e)

### Changed
- chore: update changelog and version for v1.1.2 (1385ed8)
- chore: bump build number to 89 (66a6c87)
- chore: bump version to 1.1.2+88 (fccb6af)
- refactor: use Riverpod FutureProvider for package info (03c3978)
- refactor: use Riverpod FutureProvider for package info (7d0c0d2)
- chore: update changelog and version for v1.1.1 (19c3026)


## [v1.1.2] - 2026-03-05

### Added
- feat: show dynamic version in Settings (6e212ed)
- feat: add license support for multi-language apps (19f3f3d)
- feat: implement dark/light/system theme toggle (988088e)

### Fixed
- fix: Japanese MIT License translation (d9e4b0b)
- fix: hydrate theme mode before first frame to avoid flash (cb0791a)

### Documentation
- docs: add DartDoc to ChokeApp, ThemeModeNotifier and setThemeMode (227647e)

### Changed
- chore: bump build number to 89 (66a6c87)
- chore: bump version to 1.1.2+88 (fccb6af)
- refactor: use Riverpod FutureProvider for package info (03c3978)
- refactor: use Riverpod FutureProvider for package info (7d0c0d2)
- chore: update changelog and version for v1.1.1 (19c3026)


## [v1.1.1] - 2026-03-05

### Added
- feat: add multi-language support — EN, ES, PT, JA (closes #42) (9c51752)

### Fixed
- fix: include generated l10n files and fix imports (d2adb17)
- fix: add flutter gen-l10n step before build in release workflow (4cc9d43)
- fix: pin intl to ^0.20.0 (required by flutter_localizations) (d12d039)
- fix: apply CodeRabbit review fixes (2a3ef8c)

### Changed
- chore: update changelog and version for v1.1.0 (56b4c0d)
- chore: update changelog and version for v1.1.0 (3728f7d)
- chore: update changelog and version for v1.1.0 (eb9311a)
- chore: update changelog and version for v1.0.1 (92ec666)


## [v1.1.0] - 2026-03-05

### Added
- feat: add multi-language support — EN, ES, PT, JA (closes #42) (9c51752)

### Fixed
- fix: add flutter gen-l10n step before build in release workflow (4cc9d43)
- fix: pin intl to ^0.20.0 (required by flutter_localizations) (d12d039)
- fix: apply CodeRabbit review fixes (2a3ef8c)

### Changed
- chore: update changelog and version for v1.1.0 (3728f7d)
- chore: update changelog and version for v1.1.0 (eb9311a)
- chore: update changelog and version for v1.0.1 (92ec666)


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
