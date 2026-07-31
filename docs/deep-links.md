# Shared board links

> **A link to one particular match** — `?npub=…&match=…` — is specified in
> [`specs/shared-match-links.md`](specs/shared-match-links.md). It is **read**
> but not yet **shown**: `readShareLink` returns `SharedMatch` and
> `openShareLink` records the request in `requestedMatchProvider`, and the
> scoreboard does not act on it yet. Nothing produces such a link either.
> Everything below describes the board link, which that one extends rather than
> replaces.

Sharing a pubkey from Account produces an ordinary web link:

```
https://bjjscore.live/?npub=npub1…
```

One link, two destinations. Someone without the app opens the web board, which
is what has always happened and still does. Someone **with** the app gets the
app, on the Scoreboard section, already watching that pubkey.

That is deliberate: a link that only worked for people who had already installed
the app would be useless for sharing, which is the only reason it exists.

## What the app does

`lib/services/deep_links/share_link.dart` reads the pubkey out of the URL and
`main.dart` acts on it:

- **Cold start** — `platformDispatcher.defaultRouteName`, read after the first
  frame (the providers it writes to must not be touched mid-build).
- **Already running** — `WidgetsBindingObserver.didPushRouteInformation`.

Both need the platform to hand the link to the framework rather than merely
launching the activity, which is what `flutter_deeplinking_enabled` does in the
Android manifest.

The accepted parameter is `npub`, holding either an `npub1…` or 64-character hex
— the same name choke-scoreboard accepts (`SHARE_PUBKEY_PARAM` in its
`share-link.ts`), because the same URL is opened by whichever of the two the
recipient has.

A `pubkey` alias used to be accepted alongside it. Nothing ever produced one, so
it was removed rather than carried: two names for one thing doubled the cases to
cover and left "which is canonical?" to be asked every time a link was built.

A link for any other host is ignored. So is one that names no usable key: the
app keeps whatever board the user was already watching rather than dropping them
on an empty one.

## What still has to be served — Android

**This is served, and verified in production.** `assetlinks.json` lives in
choke-scoreboard at `static/.well-known/assetlinks.json` and carries the Play
App Signing certificate's fingerprint alongside the local release key's, so
links open the app for builds installed from Google Play and for locally signed
ones alike.

What follows is why it has to stay that way, and how to check it after a change.

The intent filter is marked `android:autoVerify="true"`, and Android checks it
at install time. If the check fails, https links are *not* handed to the app —
they open the browser, and the only way to change that is for the user to go
into system settings and enable the link by hand. There is no error and nothing
in the app to see; it simply never opens. That is the failure this file prevents,
not a state the project is currently in.

The file must be at **`https://bjjscore.live/.well-known/assetlinks.json`**, as
`application/json`, over https, with no redirect:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "io.protolayer.choke",
      "sha256_cert_fingerprints": [
        "THE:PLAY:APP:SIGNING:FINGERPRINT",
        "THE:UPLOAD:KEY:FINGERPRINT"
      ]
    }
  }
]
```

The fingerprint is of the certificate the APK is **signed** with, not of
anything in this repository:

```sh
keytool -list -v -keystore <release.keystore> -alias <alias> | grep 'SHA256:'
```

Two things that catch people out:

- **Play App Signing re-signs the app.** The fingerprint that matters for a
  Play install is Google's, not the upload key's — this is what made the feature
  fail against the production build until it was added. Play Console moved the
  page: it is now under *Play Protected → Play Store protection → Manage Play
  app signing*, not the old *Setup → App signing*. Both fingerprints can be
  listed; the array takes several, and both are.
- **The debug build is a different package.** `applicationIdSuffix = ".debug"`
  makes debug builds `io.protolayer.choke.debug`, which the entry above does not
  cover. Add a second object for it, with the debug keystore's fingerprint, if
  links need to work in a debug build.

Verify on a device:

```sh
adb shell pm get-app-links io.protolayer.choke
# force a re-check
adb shell pm verify-app-links --re-verify io.protolayer.choke
```

`verified` is what you want. `legacy_failure` or an empty result means the JSON
was not fetched or did not match.

Manual test with the app installed:

```sh
adb shell am start -a android.intent.action.VIEW \
  -d "https://bjjscore.live/?npub=npub1…"
```

## What still has to be done — iOS

iOS is **not wired**. Nothing here touches it, and the release workflow builds
only an APK and an App Bundle, so this was left alone rather than half-done.

For the record, it needs all three:

1. The `com.apple.developer.associated-domains` entitlement on the Runner target
   with `applinks:bjjscore.live`, added through Xcode so the target and the
   provisioning profile agree.
2. `https://bjjscore.live/.well-known/apple-app-site-association` — JSON, no
   file extension, `application/json`, no redirect — naming
   `TEAMID.io.protolayer.choke`.
3. A rebuild and reinstall. iOS fetches the association at install time and does
   not retry on its own.

The Dart side needs nothing: Universal Links arrive at
`didPushRouteInformation` too.
