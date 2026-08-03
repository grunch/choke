# Publishing an Announcement

How to send a message to everyone using the app, with `tool/announce.dart`.

There is no admin UI and none is planned. An announcement is a signed Nostr
event published from the announcement key, and this guide is the whole
procedure. See [the spec](specs/announcement-channel.md) for why the channel is
shaped this way.

**The failure mode of this channel is silence.** Publish a malformed
announcement and nothing tells you — not the relay, not the app, not the
readers. The tool exists to catch what it can before you sign, and step 5 exists
because it cannot catch everything.

## Before you start

You need the private key of one of the publishers listed in
`lib/features/announcements/announcement_publishers.dart`. The app checks the
author of every event against that allowlist and drops everything else without a
word. An announcement signed by any other key is not a quieter announcement; it
is no announcement at all.

That key lives offline and is used for nothing else (§3.1). It is deliberately
not on the machine that writes the copy, which is why this tool signs nothing.

You also need [`nak`](https://github.com/fiatjaf/nak) to sign and publish.

## 1. Generate a template

```sh
dart run tool/announce.dart --template --out draft.json
```

## 2. Write the announcement

Edit `draft.json`. What the tool will hold you to (§6):

| Field | Rule |
|---|---|
| `d` | Unique identifier. Reusing one **corrects** the earlier announcement rather than adding a new one — see [Corrections](#corrections). |
| `locales` | All four — `en`, `es`, `ja`, `pt` — and no others. There is no fallback: a missing locale is a reader who sees nothing. |
| `expires_at` | An instant in the future, ISO-8601 or unix seconds. Nothing published here is permanent (§3.4). |
| `locales.<code>.title` | 80 characters max, measured after trimming. |
| `locales.<code>.body` | 500 characters max, measured after trimming. |
| `url` | Optional. If present, `https` with a host — the app drops anything else silently. |
| `min_version` | Optional. Oldest app version this is for, inclusive. |
| `max_version` | Optional. The version this announcement is *about*, **exclusive**. |

Two things worth reading twice:

- **The Japanese block in the template is an English placeholder.** Replace it or
  you will publish that sentence verbatim to every Japanese reader.
- **`max_version` is exclusive.** If the app is at `2.0.1` and you write
  `"max_version": "2.1.0"`, builds below 2.1.0 see it — including yours. Write
  `"2.0.1"` and you have excluded yourself, which is the usual way a test
  announcement appears to vanish. **For a test, omit both bounds** so it reaches
  every build.

Version bounds must parse: at most three numeric components, an optional
pre-release suffix, and **no build metadata** — write `2.1.0`, never `2.1.0+454`.
A bound the app cannot read invalidates the whole announcement (§2.1).

### Example draft

A test announcement with no version bounds, so every build receives it:

```json
{
  "d": "local-test-1",
  "expires_at": "2026-08-10T00:00:00Z",
  "locales": {
    "en": {
      "title": "Test announcement",
      "body": "If you can read this, the announcement channel works."
    },
    "es": {
      "title": "Anuncio de prueba",
      "body": "Si puedes leer esto, el canal de anuncios funciona."
    },
    "pt": {
      "title": "Anúncio de teste",
      "body": "Se você consegue ler isto, o canal de anúncios funciona."
    },
    "ja": {
      "title": "テストのお知らせ",
      "body": "これが読めれば、お知らせチャンネルは動作しています。"
    }
  }
}
```

Give a real test an `expires_at` a few days out. One that expires while you are
looking at it disappears from the screen, which reads as a bug in the channel
when it is the channel working (§3.4).

## 3. Validate

```sh
dart run tool/announce.dart draft.json --out event.json
```

Either it prints

```text
Valid. Sign it, publish it, and check that it arrives — nothing downstream will
tell you if it does not.
```

or it lists **everything** wrong at once, so a draft with four problems takes one
pass, not four.

Use `--out`, not a shell redirect. In this package `dart run` prints its own
build progress to stdout, and `> event.json` puts that progress in the file.

The tool writes an event with no `pubkey`, no `id` and no `sig`. Those come from
whatever holds the key.

## 4. Sign and publish

```sh
nak event --sec <the announcement key> wss://nos.lol wss://relay.primal.net < event.json
```

Relays are **positional arguments to `nak event`**; there is no `nak publish`
subcommand. The event is read from stdin.

Those two relays are the defaults a fresh install starts with
(`lib/shared/nostr_relays.dart`). If your app has others configured under
Settings, publish to those instead — an announcement on a relay nobody in the
allowlist reads is an announcement nobody receives.

Sign reasonably soon after validating. `created_at` is carried over from
`event.json`, and readers ignore anything dated more than five minutes in the
future (§3.3).

## 5. Confirm it arrived

Not optional. Nothing downstream will tell you if it did not.

```sh
nak req -k 31416 -a <the announcement pubkey, hex> wss://nos.lol
```

Then open the app: the bell appears in the top bar, and tapping it opens the
announcements screen. Remember the channel is opt-in — a reader who never
enabled it in Settings sees nothing, by design (§5).

If the event is on the relay but not in the app, the usual causes are, in order:
the signing key is not in the allowlist; a version bound excluded the build; the
channel is switched off in Settings; the event is older than the 30-day
freshness window.

## Corrections

The address of an announcement is `(kind, pubkey, d)`. Publishing again with the
**same `d` from the same key** replaces the earlier one and re-announces it to
readers who had already dismissed it. That is the fix mechanism: there is no
delete, and no way to edit in place.

Two consequences:

- Republishing a correction **from a different allowlisted key** creates a second
  announcement rather than fixing the first. Both will be on screen.
- A `d` you have used before will silently overwrite that announcement. Pick a
  new one unless replacing is what you mean.

## Expiry and the freshness window

Two separate limits, and they do not extend each other:

- **`expires_at`** — when you decide the announcement stops being true.
- **The 30-day freshness window** (§3.3) — readers ignore any event whose
  `created_at` is older than 30 days, however long a relay keeps serving it.

An `expires_at` beyond 30 days is not an error, and the tool accepts it with a
warning: readers will stop showing the announcement after 30 days regardless, so
the expiry you wrote is not the one that applies.

## Reference

| Path | What it is |
|---|---|
| `tool/announce.dart` | The CLI: template, validation, unsigned event. |
| `tool/announcement_draft.dart` | The draft model and every check in step 3. |
| `lib/features/announcements/announcement_publishers.dart` | The allowlist — the whole trust model. |
| `lib/shared/nostr_relays.dart` | The relays a fresh install starts with. |
| `docs/specs/announcement-channel.md` | The spec every § here refers to. |

Run `dart run tool/announce.dart --help` for the usage text.
