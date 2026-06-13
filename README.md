# NoDoze ☕

A dead-simple macOS menu bar app: one toggle to keep your Mac awake — built for
running agents on a laptop that must never sleep, even with the lid shut.

The toggle runs exactly the `pmset` commands behind the `turnoffsleep` /
`turnonsleep` shell aliases:

| Toggle | Commands |
|--------|----------|
| **On**  | `pmset -a sleep 0` · `pmset -a hibernatemode 0` · `pmset -a disablesleep 1` |
| **Off** | `pmset -a sleep 1` · `pmset -a hibernatemode 3` · `pmset -a disablesleep 0` |

`disablesleep 1` is the key bit — unlike `caffeinate` or Amphetamine, it
disables **lid-close (clamshell) sleep** too, so agents keep running with the
lid down.

## Stay awake only while a process runs

Flip on **"Stay awake while a process runs"** and type a process name
(`claude`, `ollama`, `node`, …). NoDoze polls every 8s via `pgrep -f -i` and:

- keeps the Mac awake while a match is alive, then
- restores normal sleep once it exits — but only the awake state it set itself,
  so a manual "Keep Mac Awake" is never undone behind your back.

The watched name and on/off state persist across launches.

## Why pmset, not caffeinate?

`caffeinate` / Amphetamine create a temporary *power assertion* — gone on reboot,
and they don't override lid-close sleep. NoDoze changes the persistent system
setting via `pmset`, including `disablesleep`, so it survives reboot and covers
clamshell. The trade-off: it applies to battery too, so toggle it **off** before
tossing the laptop in a bag.

## Build

```bash
./build.sh          # produces NoDoze.app (ad-hoc signed)
open NoDoze.app     # runs as a menu bar app (no dock icon)
```

Requires the Swift toolchain (`swiftc`) — already present with Xcode or the
Command Line Tools. macOS 13+.

## One-time setup (password-free toggling)

`pmset` needs root. To toggle silently, allow the current user to run `pmset`
without a password:

```bash
./scripts/install-sudoers.sh     # validates with visudo, then installs
```

This writes `/etc/sudoers.d/nodoze` containing:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset
```

Until you run this, NoDoze shows **"Setup required"** in the popover and the
toggle is a no-op. Undo anytime:

```bash
./scripts/uninstall-sudoers.sh
```

## Run at login (optional)

System Settings → General → Login Items → **+** → pick `NoDoze.app`.

## Distributing to others (Homebrew)

GUI apps ship as a **Homebrew Cask**, not a formula. Two routes:

1. **Your own tap (easiest, no review):** push the app as a GitHub Release,
   then a cask in a `homebrew-tap` repo lets anyone run
   `brew install --cask davidcjw/tap/nodoze`.
2. **Official `homebrew/cask`:** stricter — needs a stable versioned download
   URL and a reasonably notable/maintained app.

Two hard requirements before anyone else can run it cleanly:

- **Code signing + notarization.** The local build is *ad-hoc* signed
  (`codesign --sign -`), which only runs on the machine that built it. For
  distribution you need an Apple **Developer ID Application** cert ($99/yr
  Developer Program), then sign → `notarytool submit` → `stapler staple`.
  Without it, Gatekeeper blocks the app ("Apple cannot verify…").
- **The `pmset` privilege.** A **manual** toggle works out of the box: if
  passwordless sudo isn't set up, NoDoze falls back to a native macOS admin
  prompt (`do shell script … with administrator privileges`). The **auto-watch**
  mode needs passwordless sudo (`scripts/install-sudoers.sh`) so it never
  prompts on its 8s poll — surface that in the cask's `caveats`.

Example cask (`Casks/nodoze.rb` in your tap):

```ruby
cask "nodoze" do
  version "1.0"
  sha256 "<shasum -a 256 NoDoze.zip>"
  url "https://github.com/davidcjw/nodoze/releases/download/v#{version}/NoDoze.zip"
  name "NoDoze"
  desc "Menu bar toggle to keep your Mac awake"
  homepage "https://github.com/davidcjw/nodoze"
  app "NoDoze.app"
  caveats <<~EOS
    To toggle without a password prompt, run once:
      "#{staged_path}/NoDoze.app/Contents/Resources/install-sudoers.sh"
  EOS
end
```

## Tests

```bash
./tests/run_tests.sh
```

Unit-tests the `SleepDisabled` state parsing against real `pmset -g` formats.

## Project layout

```
Sources/SleepState.swift   pure pmset-output parser (also under test)
Sources/main.swift         SwiftUI MenuBarExtra app + model + shell runner
Info.plist                 LSUIElement (menu-bar-only, no dock icon)
build.sh                   compile + bundle + ad-hoc sign (builds icon if missing)
AppIcon.icns               app icon (coffee cup on #FF5700 squircle)
scripts/make_icon.swift    renders the 1024px master icon via AppKit
scripts/build_icns.sh      master PNG -> .iconset -> AppIcon.icns
scripts/                   install / uninstall passwordless sudo for pmset
tests/                     SleepState unit tests
```

## App icon

`AppIcon.icns` is generated from code — no design tool needed:

```bash
./scripts/build_icns.sh     # re-render the icon
```

`build.sh` rebuilds it automatically if `AppIcon.icns` is missing.
