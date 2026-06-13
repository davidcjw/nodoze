# AGENTS.md — NoDoze

Minimalist macOS menu bar app. One toggle to disable/enable system sleep via
`pmset`, mirroring the user's `turnoffsleep` / `turnonsleep` shell aliases.
Purpose: keep a laptop awake (incl. lid-closed) while AI agents run.

## Stack
- Swift + SwiftUI `MenuBarExtra` (macOS 13+), compiled with `swiftc` — **no
  Xcode project**. `LSUIElement` = menu-bar-only, no dock icon.
- No third-party dependencies.

## Build / test / run
- Build:  `./build.sh`  → `NoDoze.app` (ad-hoc signed via `codesign --sign -`).
- Test:   `./tests/run_tests.sh`  (compiles `SleepState.swift` + tests, runs them).
- Run:    `open NoDoze.app`.
- Always run `./tests/run_tests.sh` and a clean `./build.sh` before calling a
  change done.

## Layout
- `Sources/SleepState.swift` — `parseSleepDisabled(_:)`, the pure parser of
  `pmset -g` output. Keep logic here pure so it stays unit-testable; it is
  compiled into both the app and the test target.
- `Sources/main.swift` — `run()` shell helper, `SleepModel` (state + toggle),
  `PopoverView`, `@main NoDozeApp`.
- `scripts/install-sudoers.sh` / `uninstall-sudoers.sh` — manage
  `/etc/sudoers.d/nodoze` (NOPASSWD for `/usr/bin/pmset`).
- `scripts/make_icon.swift` + `scripts/build_icns.sh` — render `AppIcon.icns`
  from code (coffee cup on #FF5700 squircle). `build.sh` regenerates it if the
  `.icns` is absent; delete `AppIcon.icns` and rebuild to refresh the art.
- `Sources/PopoverContent.swift` — pure, value-driven popover UI (no model).
  `PopoverView` in main.swift is just a thin wrapper binding the model to it.
- `scripts/make_demo_gif.swift` + `scripts/build_demo_gif.sh` — render
  `docs/demo.gif`. NOTE: `ImageRenderer` can't rasterize AppKit controls
  (NSSwitch/NSTextField/NSButton) headlessly — they come out blank — and it
  blooms `.shadow` onto every child. So the demo uses a `DemoPopover` of pure
  SwiftUI shapes mirroring PopoverContent, with no shadows. Keep it in sync with
  PopoverContent if the real UI changes.

## Conventions / gotchas
- The toggle MUST keep matching the aliases exactly:
  on = `sleep 0` / `hibernatemode 0` / `disablesleep 1`;
  off = `sleep 1` / `hibernatemode 3` / `disablesleep 0`.
- `pmsetSteps` (SleepState.swift) is the single source of truth for these
  commands AND feeds `sudoersPmsetCommands()`, which scopes the sudoers rule to
  exactly those invocations + the `/usr/bin/pmset -g` probe (NOT a blanket pmset
  grant). If you change the commands, the allowlist and `passwordlessReady()`'s
  probe must stay consistent — sudoers matches the full argument vector.
- State source of truth is `pmset -g` → `SleepDisabled 1`. Don't track state in
  app memory; always re-read after a toggle (`SleepModel.refresh()`).
- Process-watch mode: `watchDecision(running:isAwake:owned:)` in
  `SleepState.swift` is pure — keep the logic there and unit-tested. The
  watcher only re-enables sleep for state it set (`owned`), never overriding a
  manual toggle. Polls every 8s via `processRunning()` (`pgrep -f -i`). Watch
  state persists in `UserDefaults` (`watchEnabled`, `watchPattern`).
- Privilege: app shells `sudo -n /usr/bin/pmset …`. `-n` fails fast when the
  sudoers rule is absent. Manual toggles fall back to a native admin prompt
  (`applyPmsetElevated`, `allowPrompt: true`). The watcher never prompts
  per-tick (`allowPrompt: false`); instead, when the user *interactively* flips
  watch mode on, `reschedule()` installs the passwordless rule once via
  `installSudoersElevated()` (osascript admin prompt). This is gated on
  `didInit` so launch-restore never prompts, and on `passwordlessReady()` so an
  already-configured machine doesn't re-prompt. Keep that split: only
  user-initiated actions may prompt; the 8s poll must stay silent.
- Run shell work off the main actor (`Task.detached`), hop back via
  `MainActor.run`. Keep it Swift 6 concurrency-clean (no captured `var`s across
  the actor hop).
- Theme accent is orange (`#FF5700`) to match the user's other projects.

## After changes
Update this file and `README.md` in the same pass (build/test commands, layout,
the toggle command table).
