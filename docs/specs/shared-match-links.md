# Shared Match Links — Specification

**Status:** Shipped, on the spectator surfaces only. Steps 1–4 of §9.3 are on
`main` (#154, #155, #157), and choke-scoreboard's reader is on its own (#36, #38).
**What is not built:** §5.3 — an organizer still cannot share their own match
from anywhere they already are. §9.4 is the list of what is left.
**Created:** 2026-07-31
**Last revised:** 2026-08-01
**Applies to:** choke (Flutter app) and choke-scoreboard (web board)
**Companion document:** [`docs/deep-links.md`](../deep-links.md) — the existing board-level link

---

## 1. Overview

### 1.1 Purpose

Let one particular match be shared, so a link opens *that fight* rather than the
board it belongs to.

### 1.2 Problem

Today a shared link names an organizer:

```text
https://bjjscore.live/?npub=npub1…
```

The recipient lands on a list and has to find the match they were sent. The
person sharing knows this, so the link goes out with instructions attached —
"watch my son's match, it's the third one". Every one of those words is
friction, and the list reorders itself as matches start and finish, so the
instructions go stale while the message is still being read.

The unit people share is a match. The product only knows how to share a board.

### 1.3 Solution

Carry the match id alongside the pubkey in the same query string:

```text
https://bjjscore.live/?npub=npub1…&match=abcd
```

Both readers — the app via App Links, the web board directly — open that match.

---

## 2. URL contract

This section is the contract. **Both repositories implement exactly this**, and
neither may extend it alone.

| Part | Value |
|---|---|
| Origin | `https://bjjscore.live` |
| Path | `/` — the root, always |
| Organizer | `npub=<npub1…\|64-hex>` |
| Match | `match=<match id>` |

A link carrying `npub` but no `match` is a **board link** and keeps its current
behaviour exactly. A link carrying `match` without a readable `npub` is broken —
an id alone names nothing, because it is only unique within one author's events.

The `pubkey` alias that used to sit beside `npub` was removed separately (#153),
leaving the single `kSharePubkeyParam` this section names.

### 2.1 Grammar of `match`

Normative, and identical in the builder and in both readers:

```text
match = 4 * HEXDIG-lowercase          ; /^[0-9a-f]{4}$/
```

That is exactly what `Match._generateMatchId()` produces — four characters drawn
from `0123456789abcdef`. It follows that:

- **Builders emit it verbatim and lowercase.** Every legal character is
  URL-safe, so there is nothing to encode.
- **Readers validate the *decoded* value**, in this order: take what the URL
  parser hands back → trim surrounding whitespace → lowercase → match the
  pattern. Both platforms decode before a caller sees the value
  (`Uri.queryParameters` here, `URLSearchParams` on the web); reading the raw
  query string to avoid that would be fighting the platform for nothing.

  That order settles the awkward cases explicitly, and both readers must agree
  on all of them:

  | Input | Decodes to | Verdict |
  |---|---|---|
  | `abcd` | `abcd` | accepted |
  | `ABCD` | `ABCD` | accepted — lowercased |
  | `abcd%20` | `abcd ` | accepted — trimmed |
  | `%61%62%63%64` | `abcd` | accepted |
  | `abc` / `abcde` / `wxyz` | — | **Broken** |

  Accepting more than we emit is deliberate. Links are mangled by chat clients
  and auto-capitalising keyboards, and the `npub` reader already trims for
  exactly that reason.
- **Anything that still fails the pattern is a *broken* link, not an absent
  one** — the sender named something unreadable, and §3.1 governs saying so.

#### The lookup key is (organizer, match), never match alone

A match id is unique only inside one author's events, so an id on its own names
nothing — which is why §2 calls a `match` without a readable `npub` broken.

The same follows through to resolution, and it is a requirement rather than a
description of what either reader does today: **a match resolves only if the
event's author equals the npub the link named.** An event carrying the same id
from a different author must neither resolve the route nor expire it.

This matters more here than the arithmetic suggests. choke-scoreboard's
`matchesMap` is keyed by match id alone, and this app looks a match up by id
within whatever feed is loaded. Both are safe only for as long as exactly one
organizer's events are in scope, which a link that switches organizers is
precisely designed to break. Coverage for "the same id from two different
authors" is owed on both sides.

> **Known limitation.** Four hex characters is 16 bits, and ids are generated
> randomly with no collision check. Two matches by one organizer inside the
> 24-hour window can collide, and `npub` + `match` would then name both. The
> odds need hundreds of matches in a day, which a large tournament can reach.
> Widening the id is out of scope and would be a change to `Match`; this spec
> only records that the link contract inherits whatever uniqueness the id has.

### 2.2 Why the root path, and not `/match/<id>`

A path-shaped URL reads better and was the first instinct. It does not work.

`android/app/src/main/AndroidManifest.xml` declares the App Links intent filter
with `android:path="/"` — the app claims **the root and nothing else**. That was
deliberate (see the comment in the manifest): claiming the whole host would have
handed the app every URL on the site, including pages it cannot render, where it
would have swallowed the link and shown nothing rather than letting the browser
have it.

So `bjjscore.live/match/abcd` would not open the app at all. It would open the
browser, on a device that has the app installed, which is the one outcome the
whole App Links setup exists to avoid.

Keeping the match id in the query string of the root URL means:

- no manifest change,
- no re-verification of `assetlinks.json`,
- no risk to deep linking that has only just been verified in production.

### 2.3 Why this is safe to ship against installed versions

v2.0.0 is in production and not every user updates. An older app receiving
`?npub=X&match=Y` reads the pubkey it understands and ignores the parameter it
does not: it opens the board. Degraded, but correct — the recipient still
reaches the right organizer, one tap from the right match.

The web board behaves the same way for a viewer on a cached bundle — with one
caveat that is a **known limitation, not a clean fallback**. An older bundle
opens the organizer's board and leaves `?match=…` sitting in the address bar,
because the bundle it is running strips only the pubkey (§2.5). Refreshing or
forwarding from that address bar yields a link carrying `match` and no `npub` —
the broken form. Landing on the board is right; the URL left behind is not.

The strip fix of §2.5 has shipped, so this now describes only *cached* bundles,
and it ages out with them rather than needing further work.

No version of this link produces an *error* on an old client, which is the
property that makes it shippable. That is a weaker claim than "degrades
correctly", and deliberately so.

### 2.4 Why `match=` and not `id=`

**Decision, and a change from the original sketch.** The first proposal was
`&id=abcd`.

`id` is fine inside one page and poor in a public contract. This URL is shared
into group chats, pasted into spreadsheets, and printed on posters; it will
outlive the code that reads it. The day the site gains event or tournament
pages, a bare `id` has to be disambiguated by whatever else happens to be in the
query string, and by then old links are in the wild.

`match=` says what it names, and costs nothing today because nothing has shipped
yet. **This is the last cheap moment to choose it.**

Note the precedent that existed when this was written ran the other way: `npub`
and `pubkey` were both accepted, a pair that absorbed historical drift between
two readers rather than two names anybody wanted. It has since been removed
(#153). A second alias for `match` should not be added.

### 2.5 Both parameters are stripped together, or neither

**Shipped** in choke-scoreboard's #36. Recorded here because it is a contract
obligation, not a web implementation detail: the string a viewer copies out of
their address bar is a link that will be sent to somebody else.

The web board wipes the pubkey from the address bar once it has been applied, so
a later refresh does not re-apply a link the viewer has since navigated away
from. Stripping only the pubkey would leave `?match=abcd` alone there — **which
is precisely the broken form this contract defines**, since an id alone names
nothing, and a refresh or copy-and-forward from that address bar would produce a
link that cannot work.

Whatever strips must strip **both or neither**.

### 2.6 Nostr addressing

Matches are addressable events (kind `31415`, keyed by a `d` tag). `npub` +
`match` are therefore exactly the coordinates the protocol already uses to name
one — the URL is a readable `naddr`, not a parallel identifier scheme invented
for the web.

Supporting a literal `naddr1…` parameter is **out of scope**: it is unreadable
in a chat message, and the two-field form is what a human can check by eye when
a link misbehaves.

---

## 3. Resolution semantics

### 3.1 The hard part is waiting, not parsing

A cold deep link arrives before any data does. The app sets the watched pubkey,
*then* subscribes, and events reach it from the relays some unknown time later.
The web board is in the same position: its match route reads from a store the
board subscription fills.

`ScoreboardMatchScreen` looks the match up by id on every build and renders a
"no longer available" dead end when it is absent. Pushing that screen the
instant a link opens therefore shows the recipient **"this match is not
available"** as the first thing they see — the precise opposite of what the link
promised, on the happy path.

So a match link has three outcomes, and the middle one must exist:

| State | What is shown |
|---|---|
| **Pending** | The match has been named and the feed has not answered yet. A waiting state that says so. |
| **Resolved** | The event arrived. The read-only match view, as reached from the board today. |
| **Unresolved** | The feed settled and this id is not in it. Say that plainly, and leave the board reachable. |

Unresolved must never be silently replaced by the board — that is the same
substitution `BrokenShareLink` already exists to prevent, and the reasoning in
`share_link.dart` applies here unchanged: the user followed a link meant for one
particular thing, and showing them a different thing is a lie they cannot catch.

#### When Pending ends — normative

"Times out eventually" cannot be implemented twice the same way, so the rules
are fixed here rather than left to each reader:

1. **Settled signal.** A lookup is settled once the subscription reports it has
   sent everything it holds — NIP-01's `EOSE`. The two readers ended up in
   different places, and the asymmetry is deliberate rather than forgotten:
   - choke-scoreboard: **done.** `oneose` now has its own channel instead of
     only clearing the shared `isLoading` store, which an unconditional
     10-second `setTimeout` also cleared — a caller could not tell "the relays
     answered" from "ten seconds passed". Landed in its #36.
   - choke: **not done, and leaning on rule 2 alone.** `NostrRelayBackend`
     exposes only `Stream<NostrEvent> get events`; the signal never reaches
     Dart, and plumbing it through the backend and the Rust layer under it is
     its own change. `kMatchLinkBackstop` in `share_link.dart` says so in
     place, which is the condition this rule attaches to leaning on the
     backstop: the code has to admit it out loud.
2. **Backstop.** Without a settled signal, Pending ends **10 seconds** after the
   link opens. Long enough for a slow relay on venue wifi, short enough that
   nobody concludes the app has hung.

   Ten rather than a fresh number because choke-scoreboard already waits
   exactly that long before giving up on EOSE. Inventing a second timeout two
   seconds away from an existing one buys nothing and leaves two magic numbers
   where there was one. Both readers use this same value.
3. **A late arrival still wins.** If the event turns up *after* the move to
   Unresolved, the reader resolves to it. The link was right and the network was
   slow; refusing to show what did arrive would be gratuitous. Unresolved states
   what is known so far — it is not terminal.
4. **Either route reaches Unresolved.** Whichever comes first — the settled
   signal with no matching event, or the backstop expiring — ends Pending. It
   is not "wait for the timeout regardless": a feed that has answered and does
   not have the match has answered.
5. **Unresolved never becomes the board on its own**, per §4. The board stays
   one deliberate tap away.

### 3.2 Suggested shape

`ShareLink` is a sealed class with three cases today. This adds a fourth:

```dart
/// A shared link naming one match on [pubkeyHex].
class SharedMatch extends ShareLink {
  const SharedMatch(this.pubkeyHex, this.matchId);
  final String pubkeyHex;
  final String matchId;
}
```

`openShareLink` handles it like `SharedBoard` — same pubkey, same tab — and
additionally requests the match. The pending/unresolved states belong to the
screen, not to the link parser: the parser's job ends once it has said what the
link named.

---

## 4. Lifetime of a shared match link

**Decision: a match link is live, not permanent.**

`scoreboardMaxAgeSeconds` is `86400`. The board drops matches older than 24
hours, so a shared match link resolves for a day and is Unresolved after that.

**The window is normative: 86400 seconds, in both repositories.** It lives today
as `scoreboardMaxAgeSeconds` (choke) and `MATCH_MAX_AGE_SECONDS`
(choke-scoreboard, `src/lib/constants.ts`). Two languages and two build systems
make a single shared source impractical, so the obligation is a conformance one:
**neither value moves without the other**.

That obligation is now enforced on both sides: each repo asserts its own
constant equals 86400 — `test/features/scoreboard/scoreboard_match_link_test.dart`
here, `src/lib/constants.test.ts` there — so a one-character edit on either side
fails a test instead of splitting the contract in silence.

Both must also measure it the same way — from the event's `created_at`, against
the same boundary — so any given link is Resolved in both readers or Unresolved
in both, never one of each.

> The web enforces the window twice: as `since` on the subscription filter, and
> again on a ticking freshness check in the match route, so a match open on
> screen expires where it stands. A stricter reading is allowed provided the
> boundary is identical; a different boundary is not.

This is being written down rather than discovered later, because it is a product
choice and not an accident:

- A live scoreboard is about the mats in front of you. A link that says "watch
  this now" is honest about being about now.
- Making it permanent is not a small change. It means fetching one event by its
  coordinates instead of reading the recent-matches window — a different query,
  a different cache, and a different empty state.
- **Permanence is already a paid feature in the business plan** (its §4.1, permanent
  event archive under Event Page Pro). Giving away indefinite match permalinks
  for free spends that before it has been sold.

The web side was already partway there when this was written: commit `ab8f81e`
gave its expired-match page a dead end with an install CTA, reasoned around
exactly this — matches age out after a day while links do not. Its
`match.notFoundBody` string ("This match may not exist or hasn't been loaded
yet") was doing the work of Pending *and* Unresolved at once, the very ambiguity
§3.1 exists to remove; #36 split it in two. This app says the same thing in
`scoreboardMatchPending*` and `scoreboardMatchUnresolved*`.

What this obliges: the Unresolved state must say the match *may have ended some
time ago*, not merely that it does not exist. A recipient opening yesterday's
link deserves to understand that the link was fine and the window closed —
otherwise it reads as the app being broken, and they blame the sender.

Revisiting this is a deliberate follow-up, not a bug report.

---

## 5. Where the share action lives

A match link is only worth building if something offers it. The spectator
surfaces come first, because that is where a match link is *reached* — the board
is how somebody who is not refereeing finds a fight at all.

### 5.1 From the board list, per match

Every match listed on the scoreboard is shareable without opening it. Somebody
scanning a list of five mats should be able to send one of them onward in a
single tap, without first entering it and coming back.

`MatchCard` gains an optional `onShare`. It is shared with the home feed, so
this must be additive: a card given no callback renders exactly what it renders
today, and home is untouched by this change.

The affordance is a **secondary** one — a small, muted icon in the card's
trailing area. A list of ten cards each shouting "share" is a list nobody reads;
the icon should recede until looked for. The card's tap target stays what it is:
opening the match.

### 5.2 While watching one match

The read-only match view gets a **single share icon, top-right**, mirroring
`_buildBack` at `Positioned(top: 8, left: 8)` — same offsets, same `SafeArea`,
same `palette.backLabel`, so the two chrome items read as a pair.

Icon only, no label. Back carries a word because leaving is a decision; sharing
is one glyph everybody already knows, and the wall board has no room to spend.

One tap, straight to the platform share sheet. No intermediate menu: this is the
"look at this" reflex, and a chooser in front of it costs more than it offers.

**No QR on this screen.** The QR's job is a room, and a room is the organizer's
moment (§5.3), not a spectator's. More to the point, when this screen *is* the
projection, the audience is already looking at it — what they need is the
bjjscore.live credit line along the bottom, which now exists. A QR here would
do the credit's job again, with more clutter, on the one surface that can least
afford it. A venue-facing code belongs to the "venue mode" idea in the business
plan (§9.1), not here.

### 5.3 The organizer, when the match starts — still not built

Not in the change that shipped §5.1 and §5.2, and still the gap. It is worth
being blunt about how the gap reads from inside the app, because "steps 1–4 are
done" hides it:

**An organizer cannot share their own match from anywhere they already are.**
Home builds its cards without `onShare`, and `MatchControlScreen` — the screen
somebody refereeing is actually looking at — offers nothing. Both share
affordances live on the spectator board and are gated on a *watched* pubkey
(`onShare` is null while `watchedHex` is), and the Scoreboard tab does not
prefill the user's own key. So the only route to sharing your own fight is to
paste your own npub into the tab meant for following somebody else. Nobody will
find that, and nobody should have to.

The peak-intent moment is the organizer's: a fight has just been created, the
people who care are in the room or waiting on their phones, and ten minutes
later the link is worth nothing. The business plan asks for exactly this in
its own §2.1 — *"share button (link + QR) in the app when creating a match, so the
organizer can project the QR at the venue"* — and that bullet has sat unbuilt
because **it was waiting for this spec**: "share when creating a match" only
means something once a match is a shareable thing.

`MatchCard.onShare`, `matchShareUrl` and `shareMatchLink` now all exist, so
wiring the home feed and the creation hand-off is small — the plumbing this
bullet was waiting on is built. That is where the QR belongs, and it is the
next thing worth doing here.

### 5.4 Two share actions, two different links

The app will now share two things, and a user who cannot tell them apart will
send the wrong one:

| Action | Link | Means |
|---|---|---|
| Share **board** (exists, scoreboard header) | `?npub=…` | "follow this academy" |
| Share **match** (new) | `?npub=…&match=…` | "watch this fight" |

They must be labelled for what they produce — *Share this board* versus *Share
this match* — never both as a bare "Share". Sending a whole board when somebody
meant to send one fight is the friction of §1.2, reintroduced from the other
end.

### 5.5 Nothing new has to be built to send it

The plumbing exists and is shared: `showQrDialog` in
`lib/shared/widgets/qr_dialog.dart`, the share-sheet call with its
`PlatformException` handling and `shareFailed` snackbar, and `liveBoardShareUrl`
in `share_link.dart`. `matchShareUrl` went in beside that last one and
`shareMatchLink` reuses the rest — the one share path both surfaces call.

### 5.6 Open question: chrome on a board that gets projected

Still open, and now concrete rather than anticipated: the wall board is
projected onto a screen at a venue, it already carried a Back button
permanently, and §5.2 has since put a second glyph beside it. Both are controls
for whoever holds the phone, and neither means anything to a room.

The class already describes itself as asking for landscape "the way a video
player does". The rest of that pattern fits: fade the chrome layer out after a
few seconds of no touch, bring it back on tap. Sharing stays one tap away for
the holder and disappears from the wall for everyone else — and the Back button,
which has the same problem today, is fixed by the same change.

Worth doing, and separable: it improves what already ships, so it can be its own
change rather than a rider on this one.

## 6. Behaviour that has to change

### 6.1 The stack-clearing exception in `openShareLink`

`openShareLink` currently skips clearing the navigator stack when the incoming
link names the board **already** being watched. The comment explains why: a
re-share in a group chat would otherwise close the match the viewer had open and
hand them back the list, for no change at all.

That rule inverts for match links. A link naming a *different* match on the
*same* board must now navigate, where today it deliberately does nothing. The
condition becomes "does this link name what is already on screen", not "does it
name the board already being watched".

Handle this carefully: the existing behaviour was added on purpose and its test
coverage in `test/services/deep_links/share_link_test.dart` should be extended,
not rewritten around.

### 6.2 `MatchControlScreen` still refuses to be popped

`_clearStack` asks each route what it would do and stops at the first refusal, so
a referee scoring a live match is not torn away by an incoming link. That
protection applies unchanged and must not be weakened for match links: the
incoming match is still selected, it is simply behind a screen the user was told
they must leave deliberately.

---

## 7. Edge cases

| Case | Expected |
|---|---|
| `match=` present but empty | Treated as absent — a board link. Matches how an empty `npub=` is already handled. |
| `match` names an id on another organizer's board | Unresolved. Ids are only unique per author; nothing is guessed. |
| Organizer opens a link to their own match | Read-only view of a match they are refereeing. Acceptable; routing them to their control screen instead is a possible refinement, not a requirement. |
| Re-share of the link already open | Nothing happens. No flicker, no reload. |
| Link arrives while a match is being scored | The referee's screen wins, per §6.2. |

---

## 8. Acceptance

Every box is checked against a test that pins it, named so the claim can be
re-checked rather than trusted.

- [x] A link with `npub` + `match` opens that match directly, in the app and on the web — `share_link_test.dart` "reads the link matchShareUrl actually builds", "asks for the match the link named"; web side in its #36.
- [x] A link with `npub` only behaves exactly as it does today (regression) — `share_link_test.dart` "an empty match is no match, and leaves a board link intact", "a board link afterwards asks for no match".
- [x] An installed **v2.0.0** app given a `match` link opens the board, not an error — by construction (§2.3): the parameter is ignored by a reader that does not know it.
- [x] The recipient never sees "not available" before the feed has had a chance to answer — `scoreboard_match_link_test.dart` "waits, rather than saying the match is not there".
- [x] An id that never arrives ends in a state that says so and mentions that the match may have ended — same file, "says the match may have ended once the backstop expires"; `scoreboardMatchUnresolvedBody` in all four locales.
- [x] A link to another match on the board already being watched navigates to it — same file, "opens a different match on the board already watched".
- [x] A link to the match already on screen does nothing — same file, "does nothing at all when the same link arrives again".
- [x] A referee scoring a live match is not navigated away — `share_link_test.dart` "does not tear a guarded screen away from the user", untouched by this work.

Not an acceptance criterion, and the reason §5.3 is still open: **none of the
above is reachable by an organizer sharing their own match.** The list above
tests what the link does once somebody sends one, not whether the person with
the most reason to send one can.

---

## 9. Build order

### 9.1 Baseline already on `main`

This work starts on top of, and reuses:

- `liveBoardShareUrl` / `kLiveBoardBaseUrl` / `kShareLinkHost` in
  `lib/services/deep_links/share_link.dart` (PR #150)
- `QrDialog` / `showQrDialog` in `lib/shared/widgets/qr_dialog.dart` (#150)
- The board share + QR actions on the scoreboard header, and the share-sheet
  call with its `PlatformException` handling and `shareFailed` snackbar (#150)
- The bjjscore.live credit at the foot of the wall board (#151), which is why
  §5.2 needs no QR
- `mockShareChannel` in `test/support/share_channel.dart` (#150)

### 9.2 Readers land before writers

**This is the ordering constraint that matters.** Both readers — the app and
choke-scoreboard — must understand `match=` *before* anything starts producing
links that carry it.

Ship a share button first and, for as long as the window lasts, **every**
recipient lands on a list instead of the fight they were sent — because during
that window every reader is an old reader. The sender has no way to know, and
keeps sending.

That degradation is not permanent in the *link*: the URL still carries
`match=…`, so once the readers ship, the same message opened again resolves
correctly. It is permanent only for clients that never update, which §2.3 makes
safe rather than desirable. In practice the point is close to moot for old
*links*, since a match expires after 24 hours (§4) — which is exactly why the
cost lands on the window itself rather than on the archive.

So the reason to order the work is not that links rot. It is that a share button
whose links nobody can open yet is a broken feature for the whole time it is
alone, and that is avoidable for free.

So: parse first, resolve second, offer third.

### 9.3 Sequence

| # | Step | Landed | Notes |
|---|---|---|---|
| 1 | `kShareMatchParam`, `matchShareUrl(npub, matchId)`, and `SharedMatch` returned by `readShareLink` | ✅ #154 | Pure functions, no UI. Cheapest step and the one everything else rests on. |
| 2 | `openShareLink` handles `SharedMatch`, and the stack-clearing condition inverts per §6.1 | ✅ #154 | The referee protection of §6.2 kept passing untouched. |
| 3 | Pending / Resolved / Unresolved on the read-only match view (§3.1) | ✅ #155 | Leans on the backstop alone, per §3.1 rule 1. |
| 4 | `MatchCard.onShare` (§5.1) and the top-right icon (§5.2), plus their strings in all four locales | ✅ #157 | Spectator surfaces only — see §5.3 and §9.4. |

The ordering constraint of §9.2 held: choke-scoreboard's reader (#36) landed
alongside steps 1–3, before either repo offered a link carrying `match=`.

### 9.4 What is left

In the order it is worth doing.

| # | Work | Why it is still open |
|---|---|---|
| 5 | **§5.3 — the organizer's share, with the QR.** `MatchCard.onShare` on the home feed, and the hand-off when a match is created. | The gap that matters: today the only path to sharing your own match is pasting your own npub into the spectator tab. Every piece it needs now exists. |
| 6 | **§3.1 rule 1 — plumb `EOSE` through `NostrRelayBackend`.** | Pending ends on a 10-second backstop with no settled signal. Correct per the spec, and coarser than the web reader, which has had its own channel since #36. |
| 7 | **§5.6 — fade the chrome on a projected board.** | Improves what already ships, Back button included. Separable by design. |

Not on this list: permanent permalinks (§4), `naddr1…` (§2.6) — both out of
scope in §10 rather than pending.

## 10. Out of scope

- `naddr1…` parameter support (§2.6).
- Permanent match permalinks (§4) — tied to the paid event archive.
- Deep links to a *tournament* or *event* grouping; no such object exists yet.
- Any change to the App Links intent filter or `assetlinks.json`.
