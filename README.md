# PNotch

A notch app for the MacBook: a music player, a clipboard manager, a system monitor, a small robot companion and a Claude Code tracker living in the camera housing. Hover the notch and it unfolds under the menu bar: what's playing, your recent copies in a searchable list (text, rich text, code, links with previews, colors, images, files and contacts), how the Mac is doing, what your robot is up to, or what Claude Code is working on.

The interface is in English and French, following the system language.

## Features

### Music

- **Now playing** from any app that reports to the system: Music, Spotify, podcasts, video in a browser… Cover with the player's icon, title, artist, scrubbable progress, previous / play-pause / next, and a halo in the cover's color.
- **Live activity**: while music plays, the closed notch widens to show the cover and a bouncing equalizer.
- Since macOS 15.4 only Apple processes may read the system "Now Playing". PNotch uses [MediaRemoteAdapter](Vendor/MediaRemoteAdapter/README.md), loaded into `/usr/bin/perl`, like boring.notch does.

### System

- **Live metrics**: CPU (user and system), GPU, memory (colored by memory pressure), network download and upload, free storage, battery and time left (uptime on desktop Macs). Each with its last minute as a chart.
- Read with public APIs (Mach, sysctl, IOKit), sampled every second only while the page is on screen.
- A button opens Activity Monitor for a closer look.

### Clipboard

- **A list that drops from the notch**, as wide as the other pages, the header split around the camera housing. It shrinks around the results. Displays without a notch get a drawn one.
- **Typed previews**: colors show as swatches, code with its syntax colors, links with their page preview, images and files as thumbnails, vCards as contact avatars.
- **Direct paste**: choosing an item (click or <kbd>↩</kbd>) pastes it into the app you were using. Hold <kbd>⌥</kbd> to only copy it. Pasting needs the Accessibility permission (System Settings › Privacy & Security › Accessibility); without it PNotch copies and asks once.
- **Shortcut** (<kbd>⌃⌘V</kbd>, changeable in Settings): opens the list with the cursor in the search field. Press it again (or <kbd>↓</kbd>) to move to the next item, <kbd>↩</kbd> to use it.
- **Search** at the top of the list: every word you type must match (case and accents ignored) the content, the type or the source app, and matches are highlighted. Clicking the notch opens it with the cursor in the search; hovering never steals the keyboard. <kbd>esc</kbd> clears it.
- **Filters** next to the search: All, Images (including picture files copied from Finder) and Links.
- **Keyboard first**: <kbd>↑</kbd> <kbd>↓</kbd> to select (even while typing a search), <kbd>↩</kbd> to paste, <kbd>⌥↩</kbd> to only copy, <kbd>⇧↩</kbd> for plain text, <kbd>⌘P</kbd> to pin, <kbd>⌘⌫</kbd> to delete, <kbd>esc</kbd> to close. Right-click an item for the same actions.
- **Sneak peek**: copying something flashes the source app and the content type around the closed notch.
- **Private by default**: content flagged as confidential by password managers ([nspasteboard.org](http://nspasteboard.org)) is never recorded. History is stored locally in `~/Library/Application Support/com.pnotch.PNotch`.

### Companion

- **On every page**: the robot sits in the header, next to the buttons, with its accessories and its moods, and something to do on each page:
  - *Music*: headphones always on; it dances while a song plays (notes in the cover's color, a jump at each new song) and nods along, waiting, when paused.
  - *Clipboard*: it holds a clipboard and reads it, and looks puzzled when a search finds nothing.
  - *System*: it holds a plug wired to the processor, graphics, memory and network, data climbing each cable as fast as the metric is busy; every few seconds it tugs at them. Its antenna shows the processor's load.
  - *Claude Code*: its visor turns into a `>_` terminal while no session is busy, Claude's star twinkles in its eyes while one works, and it calls you with a "!" when a session waits for you; clicking it then takes you there.

  A click pets it; a right-click has the page's shortcuts (play/pause, next track, clear the search, Activity Monitor, answer Claude) and leads to its page. It can stay on its own page only (Settings › Companion).
- **A small robot** with its own page, drawn live in 2.5D: metallic shading, a glass visor, glowing eyes, and a highlight that follows your pointer like a light source. Its eyes follow the pointer too, and it blinks, breathes and floats.
- **Moods from the Mac**: it dances while music plays, sweats when the processor is busy or the Mac runs hot, dozes off late at night or when you're away, and keeps an eye on things the rest of the time.
- **Messenger**: when you copy something, or Claude Code is done or needs you, it jumps and its face announces the news around the closed notch (Settings › Companion).
- **Focus with it**: its page has a focus timer, 25/5 or 50/10. It puts on a headband and concentrates with you, the time left shows around the closed notch, and when the session is done it cheers, a chime rings and the break begins (a cup of something warm for it too). Sessions survive quitting PNotch; the day's sessions and focused minutes are counted.
- **Attachment**: click it to pet it (hearts). Its page counts the days you've been together and the pets.
- **Customization** (paintbrush button): name, body color, eye color, and something to wear (headphones, crown, glasses, flower). Its name is also its tab's title.

### Claude Code

- **Live activity**: while a Claude Code session works, the closed notch shows Claude's twinkling star and how long it has been at it. When a session waits for you (a permission, a question, a plan to approve), a raised hand stays there until you answer, ahead of the music.
- **Sneak peek** when a turn is done or stopped on an error, delivered by the robot. Quick answers in the app you're looking at stay quiet.
- **Sessions page**: every session with its project, your last prompt and what Claude is doing right now ("Running npm test", "Wants to edit ContentView.swift", the start of its last answer). Click one to bring back its terminal or editor.
- **Answer from the notch**: while you're away from a session's terminal or editor, its permission requests wait in the notch with Deny, Always (Claude Code's suggested rule, e.g. this command in this project) and Allow; opening the notch goes straight to them. In front of the terminal, going back to it, clicking the session, or with PNotch closed, Claude Code asks there as usual. Can be turned off in Settings › Claude Code.
- **Connecting** (button on the page, or Settings › Claude Code) adds a hook to `~/.claude/settings.json`. Only PNotch's entries are added or removed: the rest of the file keeps its order and formatting, symlinked dotfiles are written through, and the previous version is saved as `settings.json.pnotch-backup`. The hook script, `~/.claude/hooks/pnotch.sh`, runs in the background (except for permission requests, which wait for the notch's answer), does nothing while PNotch is closed, and hands events to PNotch through a Unix socket only your account can open: nothing leaves the Mac. Connections made by an older version are upgraded at launch, with the same backup. Sessions opened before connecting pick it up once restarted.
- Claude Code doesn't run a hook when you press <kbd>esc</kbd>: PNotch notices the interruption in the session's transcript.

### Tabs

Settings › Tabs chooses which pages the notch shows, their order, and the page it opens on (the last one used by default).

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (the project uses folder-synchronized groups)

## Building

```sh
open PNotch.xcodeproj
```

Run the `PNotch` scheme. Swift packages ([Defaults](https://github.com/sindresorhus/Defaults), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [Sparkle](https://sparkle-project.org)) are resolved by Xcode.

Development builds are signed with the team's *Apple Development* certificate (team `CLFGDZUD7W`, set in the project). A stable signature matters: macOS ties the Accessibility permission to it, so it survives rebuilds.

Tests use Swift Testing and always run in English:

```sh
xcodebuild test -project PNotch.xcodeproj -scheme PNotch -destination 'platform=macOS'
```

> When Xcode is open on the project, it holds SwiftPM's download locks: add `-packageCachePath <some folder>` to command-line builds so they don't wait for it.

### Manual test checklist

Before a release, on a notched MacBook:

1. Hover the notch: it opens on the expected page; leaving with the pointer closes it, typing in the search doesn't.
2. Click the notch: the cursor is in the search; <kbd>esc</kbd> clears it, then closes.
3. Copy text, a link, an image, a Finder file: each lands in the list with the right preview, the sneak peek shows around the closed notch.
4. Click an item (permission granted): it's pasted into the app in use; <kbd>⌥</kbd>-click only copies.
5. <kbd>⌃⌘V</kbd>: the list opens; pressing it again moves down; <kbd>↩</kbd> pastes.
6. Play music in Music, Spotify, then a browser: live activity, cover, scrubbing, play/pause, next.
7. System tab: values move, Activity Monitor opens.
8. Companion tab: the robot follows the pointer, dances with music, reacts to a click (hearts) and to a copy (jump, face around the closed notch); customization applies right away.
9. Claude Code: connect from the page, start `claude` in Terminal and in VS Code; the star and timer show while it works, the raised hand on a permission prompt, the sneak peek when it's done; esc clears the activity; clicking a session brings back its app; disconnecting restores `~/.claude/settings.json`.
10. Settings › Tabs: hide and reorder tabs, change the start page.
11. Switch the system language between English and French.

## Localization

Strings live in `PNotch/Localizable.xcstrings` (English source, French translation). Xcode extracts new strings at build time; translate them in the catalog editor.

## Distribution

PNotch ships as a signed, notarized DMG, and updates itself with Sparkle from [theo-mrn/pnotch-updates](https://github.com/theo-mrn/pnotch-updates), served by GitHub Pages at `https://theo-mrn.github.io/pnotch-updates/appcast.xml`. That repository only holds what is distributed (DMGs, update archives, `appcast.xml`), never the source.

To release a version:

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
2. `scripts/release.sh`: archives the app, signs it with Developer ID, notarizes and staples it, builds a signed and notarized DMG (the app next to a link to Applications), and signs the update archive into the appcast. Everything stays in `build/release`: try the DMG first.
3. `scripts/publish.sh`: pushes the update files to the GitHub Pages repository, where installed copies find them, and attaches the DMG to a GitHub release.

One-time setup, already done on the release Mac:

- **Developer ID Application certificate** for team CLFGDZUD7W: Xcode › Settings › Apple Accounts › *Manage Certificates* › **+**. It expires on 1 February 2027; releases signed before then keep opening, new ones need a renewed certificate.
- **Notarization credentials**, under the `PNotch` keychain profile, with an app-specific password from account.apple.com:
  ```sh
  xcrun notarytool store-credentials PNotch --apple-id <apple id> --team-id CLFGDZUD7W
  ```
- **Sparkle signing key**, made by `generate_keys` and kept in the keychain: back it up, it signs every update. Its public half is `SPARKLE_PUBLIC_ED_KEY` in `Configuration/Distribution.xcconfig`, next to `SPARKLE_FEED_URL`.
- **GitHub CLI** signed in to the account owning the updates repository (`gh auth login`).

## Project layout

The structure follows [boring.notch](https://github.com/TheBoredTeam/boring.notch):

```
PNotch/
├── PNotchApp.swift            App entry point, menu bar extra and AppDelegate
├── AppIcon.icon               App icon (Icon Composer); layers generated by scripts/generate-icon-layers.swift
├── Localizable.xcstrings      English and French strings
├── ContentView.swift          Root notch view: shape, hover, open/close animation
├── PNotchViewCoordinator.swift App-wide UI state (sneak peeks, Settings)
├── MediaControllers/          Now Playing through MediaRemoteAdapter (stream, commands, parsing)
├── animations/                Springs and transitions
├── components/
│   ├── Notch/                 Window, window controller (keyboard, focus), shape, header and tabs
│   ├── Music/                 Player page, artwork, progress, controls, equalizer, live activity
│   ├── System/                Metric tiles, sparklines, system page
│   ├── Companion/             Robot renderer (Canvas), animator, live view, companion page and customization
│   ├── ClaudeCode/            Sessions page, live activity and sneak peek, Claude's spinner
│   ├── Clipboard/
│   │   ├── Models/            ClipboardItem, ClipboardContent, ClipboardHistory, filters
│   │   ├── Services/          Pasteboard monitor/reader/writer, classifier, persistence, previews
│   │   ├── ViewModels/        ClipboardStateViewModel
│   │   └── Views/             List, rows, search field, filter chips, item menu, sneak peek
│   └── Settings/              Settings window (General, Tabs, Clipboard, Music, Shortcuts, About)
├── enums/                     Notch states
├── extensions/                NSScreen notch geometry, Color helpers
├── helpers/                   Image processing, syntax highlighting, app icons, artwork colors, metric readers,
│                              order-preserving JSON, Claude Code hook server and installer, process tree
├── managers/                  MusicManager, SystemMonitor, CompanionManager, ClaudeCodeManager, UpdateManager (Sparkle)
├── models/                    PNotchViewModel, NotchGeometry, tabs configuration, PlaybackState, SystemMetrics, companion moods,
│                              Claude Code events and sessions, Defaults keys
├── observers/                 NSEvent monitors
├── Shortcuts/                 Global keyboard shortcut names
├── sizing/                    Metrics
└── utils/                     Logging
Configuration/                 Distribution settings (Sparkle feed and key) and export options
scripts/                       Release pipeline, icon layer generator
PNotchTests/                   Swift Testing unit tests
Vendor/MediaRemoteAdapter/     Vendored adapter sources, built by the MediaRemoteAdapter target and embedded in the app
```

## Credits

- `NotchShape` is adapted from [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT).
- Now Playing relies on [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg (BSD 3-Clause), vendored in `Vendor/MediaRemoteAdapter`.
- Updates by [Sparkle](https://sparkle-project.org) (MIT).
