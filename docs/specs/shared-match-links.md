# Shared Match Links — Specification

**Status:** Agreed — ready to implement. Nothing here is built yet.
**Created:** 2026-07-31
**Applies to:** choke (Flutter app) and choke-scoreboard (web board)
**Companion document:** [`docs/deep-links.md`](../deep-links.md) — the existing board-level link

---

## 1. Overview

### 1.1 Purpose

Let one particular match be shared, so a link opens *that fight* rather than the
board it belongs to.

### 1.2 Problem

Today a shared link names an organizer:

```
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

```
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
| Organizer | `npub=<npub1…\|64-hex>`, or the existing alias `pubkey=` |
| Match | `match=<match id>` |

A link carrying `npub` but no `match` is a **board link** and keeps its current
behaviour exactly. A link carrying `match` without a readable `npub` is broken —
an id alone names nothing, because it is only unique within one author's events.

### 2.1 Why the root path, and not `/match/<id>`

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

### 2.2 Why this is safe to ship against installed versions

v2.0.0 is in production and not every user updates. An older app receiving
`?npub=X&match=Y` reads the pubkey it understands and ignores the parameter it
does not: it opens the board. Degraded, but correct — the recipient still
reaches the right organizer, one tap from the right match.

The web board behaves the same way for a viewer on a cached bundle.

There is no version of this link that produces an error on an old client, which
is the property that makes it shippable at all.

### 2.3 Why `match=` and not `id=`

**Decision, and a change from the original sketch.** The first proposal was
`&id=abcd`.

`id` is fine inside one page and poor in a public contract. This URL is shared
into group chats, pasted into spreadsheets, and printed on posters; it will
outlive the code that reads it. The day the site gains event or tournament
pages, a bare `id` has to be disambiguated by whatever else happens to be in the
query string, and by then old links are in the wild.

`match=` says what it names, and costs nothing today because nothing has shipped
yet. **This is the last cheap moment to choose it.**

Note the existing precedent runs the other way: `npub` and `pubkey` are both
accepted (`kSharePubkeyParams`), but that pair exists to absorb historical drift
between two readers, not because two names were ever wanted. A second alias for
`match` should not be added.

### 2.4 Both parameters are stripped together, or neither

The web board wipes the pubkey from the address bar once it has been applied
(`stripSharedPubkeyFromUrl` in choke-scoreboard's `share-link.ts`), so a later
refresh does not re-apply a link the viewer has since navigated away from.

It strips only the pubkey params. Left as it is, a resolved match link leaves
`?match=abcd` alone in the address bar — **which is precisely the broken form
this contract defines**, since an id alone names nothing. A refresh or a
copy-and-forward from that address bar then produces a link that cannot work.

Whatever strips must strip **both or neither**. This is a contract obligation,
not a web implementation detail, because the string a viewer copies out of their
address bar is a link that will be sent to somebody else.

### 2.5 Nostr addressing

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

Pending must time out into Unresolved rather than waiting forever, and
Unresolved must never be silently replaced by the board — that is the same
substitution `BrokenShareLink` already exists to prevent, and the reasoning in
`share_link.dart` applies here unchanged: the user followed a link meant for one
particular thing, and showing them a different thing is a lie they cannot catch.

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

> The web board enforces the same window under a different name —
> `MATCH_MAX_AGE_SECONDS` in choke-scoreboard's `src/lib/constants.ts` — and
> enforces it twice: once as `since` on the subscription filter, and again on a
> ticking freshness check in the match route, so a match open on screen expires
> where it stands. Same number, two names; worth reconciling if either ever
> moves.

This is being written down rather than discovered later, because it is a product
choice and not an accident:

- A live scoreboard is about the mats in front of you. A link that says "watch
  this now" is honest about being about now.
- Making it permanent is not a small change. It means fetching one event by its
  coordinates instead of reading the recent-matches window — a different query,
  a different cache, and a different empty state.
- **Permanence is already a paid feature in the business plan** (§4.1, permanent
  event archive under Event Page Pro). Giving away indefinite match permalinks
  for free spends that before it has been sold.

The web side is already partway there: commit `ab8f81e` gave its expired-match
page a dead end with an install CTA, reasoned around exactly this — matches age
out after a day while links do not. Only the wording of *why* the match is gone
needs to change there. Note also that its existing `match.notFoundBody` string
("This match may not exist or hasn't been loaded yet") is currently doing the
work of Pending *and* Unresolved at once — the very ambiguity §3.1 exists to
remove. Implementing this replaces one string with two, rather than adding one.

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

### 5.3 The organizer, when the match starts — later, same plumbing

Not in this change, and noted so it is not re-derived later.

The peak-intent moment is the organizer's: a fight has just been created, the
people who care are in the room or waiting on their phones, and ten minutes
later the link is worth nothing. The business plan asks for exactly this in
§2.1 — *"share button (link + QR) in the app when creating a match, so the
organizer can project the QR at the venue"* — and that bullet has sat unbuilt
because **it was waiting for this spec**: "share when creating a match" only
means something once a match is a shareable thing.

Once `MatchCard.onShare` and the match URL builder exist, wiring the home feed
and the creation hand-off is small. That is where the QR belongs.

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
in `share_link.dart`. This adds a match URL builder beside that last one and
reuses the rest.

### 5.6 Open question: chrome on a board that gets projected

The wall board is projected onto a screen at a venue. It already carries a Back
button permanently; §5.2 adds a second glyph beside it. Both are controls for
whoever holds the phone, and neither means anything to a room.

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

- [ ] A link with `npub` + `match` opens that match directly, in the app and on the web.
- [ ] A link with `npub` only behaves exactly as it does today (regression).
- [ ] An installed **v2.0.0** app given a `match` link opens the board, not an error.
- [ ] The recipient never sees "not available" before the feed has had a chance to answer.
- [ ] An id that never arrives ends in a state that says so and mentions that the match may have ended.
- [ ] A link to another match on the board already being watched navigates to it.
- [ ] A link to the match already on screen does nothing.
- [ ] A referee scoring a live match is not navigated away.

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

A link lives in a chat forever. If a share button ships first, the links people
send during that window degrade to board links for good: opened tomorrow, next
month, by anyone, they still land on a list. §2.2 makes that degradation safe;
it does not make it desirable, and it is entirely avoidable by ordering the
work.

So: parse first, resolve second, offer third.

### 9.3 Sequence

| # | Step | Notes |
|---|---|---|
| 1 | `kShareMatchParam`, `matchShareUrl(npub, matchId)`, and `SharedMatch` returned by `readShareLink` | Pure functions, no UI. Cheapest step and the one everything else rests on. Extend `test/services/deep_links/share_link_test.dart` rather than starting a new file. |
| 2 | `openShareLink` handles `SharedMatch`, and the stack-clearing condition inverts per §6.1 | Extend the existing tests; do not rewrite around them. The referee protection of §6.2 must keep passing untouched. |
| 3 | Pending / Resolved / Unresolved on the read-only match view (§3.1) | The hard part, and the only step with real design left in it. Do not start it in the same change as step 4. |
| 4 | `MatchCard.onShare` (§5.1) and the top-right icon (§5.2), plus their strings in all four locales | Small once 1–3 exist, and pointless before them. |

Steps 1–2 and step 3 are separable changes. Step 4 must not merge before step 3
resolves, per §9.2.

Cross-repo: choke-scoreboard's reader should land alongside step 1–2, before
step 4 in either repo. See its companion doc.

## 10. Out of scope

- `naddr1…` parameter support (§2.4).
- Permanent match permalinks (§4) — tied to the paid event archive.
- Deep links to a *tournament* or *event* grouping; no such object exists yet.
- Any change to the App Links intent filter or `assetlinks.json`.
