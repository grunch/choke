# Announcement Channel — Specification

**Status:** Proposed. Nothing is built.
**Created:** 2026-08-01
**Applies to:** choke (Flutter app)
**Related:** the project's business plan, kept outside this repository. This is
the announcement half of the notification surface that plan asks for; the
"followed academy is live" half is deliberately not in here (§9).

---

## 1. Overview

### 1.1 Purpose

Give the project one authenticated way to say something to the people already
using the app — a release worth updating for, an outage, an event — without a
backend, an account, an email address, or a push service.

### 1.2 Problem

Today there is no channel at all. A user installs the app and the only thing the
project can ever say to them again is whatever fits in a Play Store release
note, which reaches them once, at update time, if they read it.

Everything the obvious fixes need — a server, a user identity, an email list, a
device token — is something this app has spent every release *not* having. The
app has no accounts, captures nothing, and that is a selling point rather than a
gap waiting to be filled.

### 1.3 Solution

The app already speaks Nostr, and a Nostr event is signed. So: publish
announcements from a key the project controls, hardcode that key's `npub` in the
app, and have the app read events **only** from that key.

The signature is the whole trust model. A hostile relay can withhold an
announcement or serve a stale one, and §3 handles both, but it cannot forge one.
No transport-level trust is required, which is exactly why no server is.

### 1.4 What this is not

Stated up front because the idea invites all three:

- **Not push.** Nothing wakes the device. An announcement is seen the next time
  the app is opened. See §9 for why, and what real push would cost.
- **Not a message to a particular user.** The channel is a broadcast. Reaching
  *the organizers who publish the most matches* is a different mechanism with a
  different trust model (§9).
- **Not two-way.** There is no reply path, and adding one would put an inbox in
  front of a maintainer with no moderation tooling behind it.

---

## 2. Event contract

This section is normative.

| Part | Value |
|---|---|
| Kind | `31416` — addressable, adjacent to the match kind `31415` |
| Author | one of the keys in §3.1, and nothing else |
| `d` tag | the announcement id: stable, opaque, unique per announcement |
| `expiration` tag | NIP-40, required — see §3.4 |
| `content` | the JSON of §2.2 |

The kind is addressable (30000–39999) on purpose: `NostrService` already caches
addressable events keyed by `kind:pubkey:d` and replaces them in place, so
correcting a typo in a live announcement is a republish under the same `d` and
costs no new code.

### 2.1 Tags

| Tag | Required | Meaning |
|---|---|---|
| `d` | yes | announcement id |
| `expiration` | yes | unix seconds; NIP-40 |
| `min_version` | no | show only to app versions ≥ this, semver |
| `max_version` | no | show only to app versions ≤ this, semver |

`min_version` / `max_version` exist for the announcement that is *about* the app
— "2.1 is out, it fixes X" should not be shown to someone who is already on 2.1.
The app's own version comes from `package_info_plus`, which is already a
dependency.

An unparseable version bound makes the announcement **invalid**, not unbounded:
a bound nobody can read is a targeting instruction that failed, and showing the
message to everyone is the wrong way to fail it.

### 2.2 Content

```json
{
  "v": 1,
  "locales": {
    "en": { "title": "…", "body": "…" },
    "es": { "title": "…", "body": "…" }
  },
  "url": "https://bjjscore.live/…"
}
```

| Field | Required | Rule |
|---|---|---|
| `v` | yes | schema version; `1` today. An event with an unknown `v` is **ignored**, not rendered best-effort. |
| `locales` | yes | map of locale code → `{title, body}`. Must contain `en`. |
| `locales[x].title` | yes | ≤ 80 characters after trimming |
| `locales[x].body` | yes | ≤ 500 characters after trimming |
| `url` | no | exactly one action link, `https` scheme only |

`en` is required because it is the fallback: the app has four locales and an
announcement that ships in three of them must still say *something* to the
fourth. Selection is the app's current locale, then `en`, then the announcement
is invalid.

Both strings are plain text. No markup is parsed, no link is auto-detected
inside `body`, and `url` is the only thing that is ever tappable — the sender is
trusted with authorship, not with the ability to render arbitrary things inside
the app.

### 2.3 Why the locales ride in one event

The alternative is one event per language, tagged `["l", "es"]`. It is more
idiomatic Nostr and it is worse here: it turns one publish into four, lets a
user's relay set deliver two of them and not the others, and leaves the app
deciding whether three events are one announcement or three. One event that
carries all four translations cannot half-arrive.

The cost is that the copy does not live in `lib/l10n/*.arb` and so is not
covered by the l10n workflow. That is inherent — the text is written after the
build ships. The app chrome around it (the screen title, the empty state, the
Settings toggle) *is* localized normally.

---

## 3. Trust model

### 3.1 The allowlist

A `const List<String>` of `npub`s compiled into the app. A list, not a single
value, and this is the one place where the plural matters: a hardcoded singular
key that is lost or leaked kills the channel until a Play review completes, and
that is measured in days. A list lets a successor key ship *before* it is
needed.

Two rules on the key itself:

1. **It is not the maintainer's personal key.** A dedicated key, kept offline,
   used for nothing else. If the announcement key is also the key that arbitrates
   matches, then losing a phone loses both.
2. **The constant holds `npub`, not hex.** It is what a human checks against the
   value published elsewhere, and the app's surfaces already speak `npub`.
   Decoding to hex for the subscription filter goes through `NostrCrypto`
   (`npub_decode` in the crate) like every other bech32 operation in the app —
   never a Dart bech32 implementation. See AGENTS.md.

An entry that fails to decode is dropped with a `debugPrint`, and the remaining
entries still work. A typo in one constant must not silence the channel.

### 3.2 Verification is explicit

**Every announcement event is verified in the crate before it is trusted**, via
the existing `verify_event_data`, regardless of what the relay pool does or does
not verify on its own. The relay pool's verification settings are a transport
detail that can change under us; this is the only property the whole feature
rests on, so it is asserted where it is used rather than assumed upstream.

An event that fails verification is dropped silently. It is not shown, not
counted, and not surfaced as an error — there is nothing a user could do about
it, and "an announcement failed to verify" is itself a message from an untrusted
source.

### 3.3 Freshness and replay

A relay can serve an old event forever, and a fresh install subscribing with no
history would take last quarter's announcement as news. So:

| Rule | Value |
|---|---|
| Too old | `created_at` older than 30 days → ignored |
| Future-dated | `created_at` more than 5 minutes ahead of now → ignored |
| Already seen | `d` in the seen set → not re-announced |
| Superseded | same `d`, newer `created_at` → replaces, and is re-announced |

The 5-minute window is clock skew, not tolerance for post-dating: an
announcement dated next week must not sit at the top of every inbox until then.

The subscription therefore carries `since = now - 30 days` and `limit = 20`, so
the freshness rule is enforced at the relay as well as locally. `Filter` already
has `kinds`, `authors`, `since`, and `limit` — **no new capability is needed in
the crate or on `NostrRelayBackend` for this feature.**

### 3.4 Expiry

`expiration` is required (§2), and an expired event is dropped on arrival and
swept from local storage. This is what keeps "we are down for maintenance
tonight" from being read as news a month later, and it also means the sender
cannot accidentally create something permanent.

---

## 4. App behaviour

### 4.1 Fetch

On app foreground, when the setting of §5 is on:

```text
Filter(kinds: [31416], authors: <hex of §3.1>, since: now - 30d, limit: 20)
```

The subscription lives as long as the app is in the foreground and is closed
when it leaves. There is no background work of any kind — see §9.

### 4.2 Storage

`shared_preferences`, following `relay_config_provider` and its neighbours:

- the announcements themselves, capped at the **20 most recent** by `created_at`
- the set of `d` ids already read
- the set of `d` ids dismissed

Cached announcements are shown offline. They are, after all, the last thing the
project said, and that stays true whether or not a relay answers today.

### 4.3 Surface

- **Home**, top bar: a bell with a dot when there is anything unread. No dot,
  no badge, no count when there is nothing — the bell is not a permanent piece
  of chrome advertising that a channel exists.
- **Announcements screen**: newest first, title, body, relative date, and the
  `url` as a single button when present. Tapping an item marks it read; swipe
  dismisses. `url` opens externally through `url_launcher`, as every other
  outbound link in the app does.
- **Empty state**: localized, and it says what the channel is for.

Nothing interrupts. No dialog, no snackbar, no takeover on launch. A referee
opening the app between matches must reach the scoring screen exactly as fast as
before.

### 4.4 Failure

Every failure mode of this feature is silent: no relay, no announcements, bad
JSON, failed signature, unknown `v`. A user who never receives an announcement
should not be able to tell that they didn't, and none of it is worth a word of
UI. Details go to `debugPrint`, per the AGENTS.md rule on raw exceptions.

---

## 5. Consent

A single switch in Settings — **Announcements**, default **on**, localized in
four languages.

Off means the subscription is never opened, not that arriving events are hidden.
The relay must not be able to distinguish a user who opted out from a user who
closed the app.

Default-on is a judgement call and worth stating plainly: the channel is
low-frequency and product-related, and nothing here posts a system notification,
so nothing here escapes the app the user just opened. The day it does post one,
Android 13+ requires a runtime permission and this default is re-argued, not
inherited.

Two constraints that are policy rather than code, and belong in this document
anyway:

- **Low frequency.** This channel exists for releases, outages, and events. The
  moment it carries anything else, the switch above stops being theoretical.
- **The app's promise still holds.** No registration, no data capture, nothing
  sent about the user. The channel is one-way *toward* the app; the app reports
  nothing back, not even a read receipt.

---

## 6. Publishing an announcement

There is no admin UI and none is planned. Publishing is a signed event from the
key of §3.1, sent with any Nostr client or a small script in `tool/`.

What the sender owes:

1. A `d` that has never been used, unless deliberately correcting a live one.
2. An `expiration` that is actually in the future.
3. `en` present in `locales`, plus whatever translations exist.
4. A `url` that is `https`, if any.

A `tool/` script that validates all four before signing is worth writing at the
same time as the reader, because the reader's failure mode is silence — publish
a malformed announcement and nothing tells you, on either end.

---

## 7. Testing

| Area | Cases |
|---|---|
| Allowlist | event from an allowed key accepted; from any other key ignored; one undecodable entry does not disable the rest |
| Verification | tampered content, tampered tags, wrong signature — all dropped |
| Freshness | 31 days old ignored; dated 10 minutes ahead ignored; same `d` with newer `created_at` replaces and re-announces; same `d` re-delivered does not re-announce |
| Expiry | expired on arrival dropped; expiring while cached swept |
| Content | unknown `v` ignored; missing `en` ignored; over-length title or body ignored; non-`https` `url` ignored while the announcement still renders; version bounds in range, out of range, and unparseable |
| Locale | current locale wins; missing locale falls back to `en`; all four locales resolve |
| Consent | switch off ⇒ no subscription is opened |
| Widget | dot appears only when unread; read and dismiss persist across a restart; empty state |

Signature cases are tagged `rust` — they need the native library, per AGENTS.md.

---

## 8. Build order

| # | Step | Why here |
|---|---|---|
| 1 | Parsing and validation of §2 plus the allowlist of §3.1 — pure functions, no UI, no network | Everything rests on it, and it is the cheapest thing to get wrong quietly |
| 2 | Fetch, verify, freshness, expiry, storage (§3.2–§3.4, §4.2) | Testable against a fake `NostrRelayBackend`, no screen yet |
| 3 | Settings switch (§5) | Ships before the surface, so the channel is never live without an off switch |
| 4 | Bell, screen, four locales of chrome (§4.3) | Last, when there is something to show |
| 5 | `tool/` publisher script (§6) | With or just after step 1, sharing its validator |

---

## 9. Out of scope

- **Real push (FCM).** It needs a service of ours holding a relay subscription
  and a device token per install — a backend, and a per-install identifier,
  which is the thing this app does not have. Revisit alongside followed
  academies, not before.
- **Background relay subscriptions on Android.** Doze kills them; a channel that
  works only while the phone is awake and charging is worse than one that is
  honestly foreground-only.
- **Targeted messages to the organizers who publish the most matches.** The
  right mechanism is a NIP-17 DM to npubs identified from relay metrics, and it
  is a separate spec: encrypted content, a different trust model, and outreach
  rather than broadcast. The allowlist built here is reusable for the reader
  side when that day comes.
- **Replies, reactions, or any inbound path.**
- **Announcements from followed academies.** That is the other half of the same
  notification surface, driven by match events rather than by this kind.
