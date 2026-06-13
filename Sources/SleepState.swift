import Foundation

/// Source of truth for the toggle: pmset reports `SleepDisabled  1` when
/// `disablesleep 1` is active (the lid-close-safe state set by `turnoffsleep`).
func parseSleepDisabled(_ pmsetOutput: String) -> Bool {
    pmsetOutput.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
}

/// What the process-watcher should do on a given tick.
enum WatchAction: Equatable { case keepAwake, allowSleep, doNothing }

/// Shell command (run once, as root) that installs the passwordless-sudo rule
/// for pmset — so the watcher can act silently. Validates with visudo before
/// installing. Pure builder so it can be unit-tested; executed via an osascript
/// admin prompt in the app.
func sudoersInstallCommand(user: String) -> String {
    "t=$(mktemp); echo '\(user) ALL=(root) NOPASSWD: /usr/bin/pmset' > \"$t\"; " +
    "/usr/sbin/visudo -cf \"$t\" && /usr/bin/install -m 0440 -o root -g wheel \"$t\" /etc/sudoers.d/nodoze; rm -f \"$t\""
}

/// Subtitle shown under the "stay awake while a process runs" toggle.
func watchSubtitle(enabled: Bool, running: Bool, pattern: String) -> String {
    guard enabled else { return "e.g. claude, ollama, node" }
    let name = pattern.trimmingCharacters(in: .whitespaces)
    return running ? "‘\(name)’ running — keeping awake"
                   : "‘\(name)’ not running — sleep normal"
}

/// Pure decision for the watcher so it stays unit-testable.
/// - running: is the watched process alive?
/// - isAwake: is sleep currently disabled?
/// - owned:   did the watcher (not the user) set the current awake state?
///
/// The watcher only *re-enables* sleep for state it set itself, so a manual
/// "keep awake" toggle is never undone behind the user's back.
func watchDecision(running: Bool, isAwake: Bool, owned: Bool) -> WatchAction {
    if running && !isAwake { return .keepAwake }
    if !running && isAwake && owned { return .allowSleep }
    return .doNothing
}
