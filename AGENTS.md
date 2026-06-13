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

## Conventions / gotchas
- The toggle MUST keep matching the aliases exactly:
  on = `sleep 0` / `hibernatemode 0` / `disablesleep 1`;
  off = `sleep 1` / `hibernatemode 3` / `disablesleep 0`.
- State source of truth is `pmset -g` → `SleepDisabled 1`. Don't track state in
  app memory; always re-read after a toggle (`SleepModel.refresh()`).
- Process-watch mode: `watchDecision(running:isAwake:owned:)` in
  `SleepState.swift` is pure — keep the logic there and unit-tested. The
  watcher only re-enables sleep for state it set (`owned`), never overriding a
  manual toggle. Polls every 8s via `processRunning()` (`pgrep -f -i`). Watch
  state persists in `UserDefaults` (`watchEnabled`, `watchPattern`).
- Privilege: app shells `sudo -n /usr/bin/pmset …`. `-n` fails fast when the
  sudoers rule is absent. Manual toggles then fall back to a native admin
  prompt (`applyPmsetElevated` via osascript, `allowPrompt: true`); the watcher
  passes `allowPrompt: false` so its 8s poll never prompts — it just sets
  `needsSetup`. Keep that split: only user-initiated actions may prompt.
- Run shell work off the main actor (`Task.detached`), hop back via
  `MainActor.run`. Keep it Swift 6 concurrency-clean (no captured `var`s across
  the actor hop).
- Theme accent is orange (`#FF5700`) to match the user's other projects.

## After changes
Update this file and `README.md` in the same pass (build/test commands, layout,
the toggle command table).
