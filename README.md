# DM Archive Viewer (iOS)

A native SwiftUI app for iOS 17+ that imports and displays the `.json`
files exported by the **DM Offline Archive** Chrome extension's
"Export chat" button — the same data, viewed the same way (dark theme,
blue/grey bubbles, reply previews, date dividers, tap-to-enlarge
photos), just on your iPhone instead of in a browser tab.

Untested disclaimer, upfront: this was written without access to a Mac,
Xcode, or a Swift compiler — I can't compile-check any of this myself.
It's built to be straightforward, standard SwiftUI with no exotic APIs,
but the realistic first step is opening the generated project in Xcode
(or reading the GitHub Actions build log) and fixing whatever actually
doesn't compile. Treat this as a strong first draft, not a finished,
verified product.

## What's actually in this repo

```
DMArchiveViewer/
  DMArchiveViewer/
    DMArchiveViewerApp.swift       — app entry point
    Info.plist
    Models/ArchiveModels.swift     — matches the extension's export JSON exactly
    Store/ArchiveStore.swift       — import + local persistence (Documents dir)
    Store/SearchMatching.swift     — same word-boundary search rule as the extension
    Views/LibraryView.swift        — conversation list + import button
    Views/ConversationView.swift   — the message thread
    Views/MessageRowView.swift     — bubbles, reply previews, dividers
    Views/AvatarView.swift
    Views/LightboxView.swift       — tap-to-enlarge photos
    Views/DataURLImage.swift       — decodes the data:image/...;base64,... strings
    Assets.xcassets/
  project.yml                      — XcodeGen spec (see below)
  .github/workflows/build-ios.yml  — CI build
```

There's no hand-authored `.xcodeproj` in this repo — those are fragile,
mostly-generated files that are genuinely risky to write by hand without
Xcode itself to verify them. Instead this uses
[XcodeGen](https://github.com/yonaskolb/XcodeGen): `project.yml`
describes the target in a few lines, and `xcodegen generate` produces a
real `.xcodeproj` from it, every time, identically, whether that's run
in CI or on your own Mac. If you do have a Mac: install XcodeGen
(`brew install xcodegen`), run `xcodegen generate` in this folder, and
open the resulting `DMArchiveViewer.xcodeproj` — that's a completely
normal Xcode project from that point on.

## Setting up the GitHub Actions build

1. Push this repo to GitHub.
2. Go to the **Actions** tab → **Build iOS App** → **Run workflow** (or
   just push a commit under `DMArchiveViewer/`, which triggers it
   automatically).
3. When it finishes, open the run and download the
   **DMArchiveViewer-unsigned-ipa** artifact from the bottom of the page.

That produces `DMArchiveViewer-unsigned.ipa`. Read the next section
before expecting to install it, though — this is the part that's
genuinely different from a normal "download and tap install."

## The part that needs to be said plainly: code signing

iOS does not allow an app onto a real, non-jailbroken iPhone without
**some** form of Apple code signing — not as an extension-specific
restriction, but as a platform-wide rule that applies to every iOS app
from every developer, including Apple's own default Xcode templates.
There is no way to route around this purely inside a CI pipeline with
zero Apple involvement; it needs *some* Apple ID or developer account
in the loop somewhere. This workflow deliberately builds **unsigned**
(`CODE_SIGNING_ALLOWED=NO`) so the build itself can complete on a bare
GitHub runner with nothing but a free Xcode install — no certificates,
no secrets, no Apple account tied to this repo. That's what makes it
possible to hand you a working build pipeline at all without your Apple
credentials. But it also means the `.ipa` it produces isn't installable
as-is.

Realistically, from here, two paths:

**AltStore / SideStore (free Apple ID, no $99/year account)**
This is almost certainly what you actually want. Install
[AltStore](https://altstore.io) or [SideStore](https://sidestore.io) on
your iPhone, sign in with a free Apple ID, and use it to install
`DMArchiveViewer-unsigned.ipa` directly — these tools re-sign the app
themselves using your Apple ID's free personal-developer entitlement.
The catch: a free Apple ID's signature expires after **7 days**, after
which AltStore/SideStore needs to refresh it (AltStore does this
automatically if your phone occasionally connects to AltServer running
on a computer, or via AltStore's own background refresh; SideStore can
refresh over the same WiFi network without a computer at all). This is
a real, widely-used pattern — not a workaround I'm improvising — and is
exactly the shape of workflow this repo's CI is built to feed.

**A paid Apple Developer Program membership ($99/year)**
If you have one, the workflow can be extended to produce a properly
signed `.ipa` that installs normally and doesn't expire every 7 days.
That needs your distribution certificate and provisioning profile
supplied as GitHub Actions secrets (commonly a base64-encoded `.p12` +
`.mobileprovision`, imported into a temporary keychain during the build
— `xcodebuild` then signs against them directly instead of building
unsigned). I haven't wired this up here since I don't have your Apple
Developer account, but the `project.yml`'s `CODE_SIGN_STYLE: Manual` is
specifically set up to make this an incremental change (swap the
signing settings and add the cert-import step) rather than a rewrite,
if you want to go this route later.

## Notes on what's implemented vs. simplified

- **Search** dims nothing — it filters the list down to matching
  messages (plus date dividers), which is simpler than the extension's
  "grey out non-matches in place" and was the more natural fit for a
  native list.
- **No match-count/arrow navigation** (the extension has this; this
  app doesn't yet) — searchable filtering covers the common case, and
  this was left out to keep the first version's scope realistic.
- **No wallpaper *upload*** — a conversation's wallpaper, if the
  original export included one, is displayed as the thread's
  background, but there's no in-app picker to set a new one.
- **Reply previews** show as a small quoted line above the bubble, the
  same shape as the extension, using whatever `replyToName` /
  `replyPreview` the export already captured — this app doesn't try to
  re-derive anything from the original DOM (it can't; there's no DOM),
  it's just displaying what was already extracted.
- Large conversations use `LazyVStack` inside a `ScrollView` so a
  multi-thousand-message import doesn't try to render every bubble at
  once — the same reasoning as the extension's own concern about huge
  conversations, just solved with native lazy rendering instead of
  virtualization workarounds.

## Round 2 fixes: import reliability and an in-app debug log

- **Import was failing silently for some files.** Two real causes,
  fixed: (1) `.fileImporter` only accepted files typed exactly as
  `public.json` — a file that arrived via AirDrop or as an email/Files
  attachment doesn't always end up tagged that cleanly, which could
  make it not even show up as selectable in the picker, with nothing to
  explain why. It now also accepts plain text, generic data, and a
  catch-all item type, covering a file regardless of how its type
  metadata ended up tagged on the way in. (2) The file read and JSON
  decode ran synchronously on the main thread — fine for a small file,
  but a large, photo-heavy export could take long enough to trip iOS's
  main-thread watchdog, which looks exactly like "the app just doesn't
  do anything" from the outside. Both the import and opening a saved
  conversation now do that work off the main actor, with a spinner
  shown while it's in progress.
- **A debug log, viewable and shareable from inside the app** — reached
  via the bug icon in the Library's top-left. This is the direct iOS
  equivalent of the Chrome extension's debug log, for the same reason:
  there's no Xcode console attached to a sideloaded app, so without
  this there was no way to see *why* something failed. Decoding errors
  specifically report the exact field and path that didn't match,
  rather than a generic "doesn't look like an export" — if import still
  fails, export this log (the share icon, top-right of the log screen)
  and send it over; it'll usually say precisely what's wrong.

## Importing a file

Get the `.json` from the extension's **Export chat** button (in the
Library's thread header, next to wallpaper and delete), get it onto
your iPhone (AirDrop, iCloud Drive, email attachment — anything the
Files app can see), then in this app tap the import icon in the top
right and pick it. Re-importing the same conversation (same id)
overwrites the existing copy rather than duplicating it.
