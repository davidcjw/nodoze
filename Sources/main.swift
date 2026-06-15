import SwiftUI
import AppKit

// MARK: - Shell

/// Runs a process to completion and returns (exitCode, combined stdout+stderr).
/// Free function so it is safe to call from a detached (off-main) task.
@discardableResult
func run(_ launchPath: String, _ args: [String]) -> (Int32, String) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: launchPath)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    do { try proc.run() } catch { return (-1, "\(error)") }
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

/// True if any process matches `pattern` (case-insensitive, full command line).
func processRunning(_ pattern: String) -> Bool {
    let trimmed = pattern.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    let (code, _) = run("/usr/bin/pgrep", ["-f", "-i", trimmed])
    return code == 0
}

/// Passwordless attempt. Returns true if sudo lacked permission (needs setup).
func applyPmset(enable: Bool) -> Bool {
    for step in pmsetSteps(enable: enable) {
        let (code, _) = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + step)
        if code != 0 { return true }   // -n fails fast if a password is required
    }
    return false
}

/// Fallback for machines without the passwordless-sudo setup: run all three
/// pmset commands under one native admin prompt via osascript. Returns true on
/// failure (e.g. the user cancelled the auth dialog). Used only for manual
/// toggles — never the 8s watcher, which must not prompt.
func applyPmsetElevated(enable: Bool) -> Bool {
    let cmd = pmsetSteps(enable: enable)
        .map { "/usr/bin/pmset " + $0.joined(separator: " ") }
        .joined(separator: " && ")
    let script = "do shell script \"\(cmd)\" with administrator privileges"
    let (code, _) = run("/usr/bin/osascript", ["-e", script])
    return code != 0
}

/// True if pmset can already be run without a password (sudoers rule present).
/// `pmset -g` is read-only, so this probes permission without changing state.
func passwordlessReady() -> Bool {
    run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-g"]).0 == 0
}

/// Installs the passwordless-sudo rule via one native admin prompt, so the
/// watcher can act silently afterwards. Returns true on failure/cancel.
func installSudoersElevated() -> Bool {
    let cmd = sudoersInstallCommand(user: NSUserName())
    let escaped = cmd
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let script = "do shell script \"\(escaped)\" with administrator privileges"
    let (code, _) = run("/usr/bin/osascript", ["-e", script])
    return code != 0
}

// MARK: - Model

@MainActor
final class SleepModel: ObservableObject {
    @Published var isAwake = false      // true == system sleep disabled
    @Published var busy = false
    @Published var needsSetup = false   // passwordless sudo not configured

    @Published var watchEnabled = false { didSet { persist(); reschedule() } }
    @Published var watchPattern = "claude" { didSet { persist() } }
    @Published var watchRunning = false

    private var owned = false            // did the watcher set the current awake state?
    private var timer: Timer?
    private var didInit = false          // true once init() finished restoring state
    private let defaults = UserDefaults.standard

    init() {
        if let saved = defaults.string(forKey: "watchPattern"), !saved.isEmpty {
            watchPattern = saved
        }
        refresh()
        // Restore the saved toggle WITHOUT prompting — only a deliberate flip
        // (after init) should trigger the one-time admin prompt.
        watchEnabled = defaults.bool(forKey: "watchEnabled")
        didInit = true
    }

    var statusText: String {
        if needsSetup { return "Setup required" }
        return isAwake ? "Sleep off · lid-close safe" : "Normal sleep"
    }

    func refresh() {
        let (_, out) = run("/usr/bin/pmset", ["-g"])
        isAwake = parseSleepDisabled(out)
    }

    /// Manual toggle from the switch. Allows an admin prompt if passwordless
    /// sudo isn't set up. Clears watcher ownership so the watcher won't later
    /// undo a deliberate choice.
    ///
    /// Turning NoDoze *off* is a kill switch: it also disables watch mode.
    /// Otherwise the 8s watcher would re-grab keep-awake within seconds while the
    /// watched process is still running, leaving the Mac unable to sleep.
    func toggle() {
        let enable = !isAwake
        if !enable {
            owned = false           // before watchEnabled=false so reschedule() won't re-apply
            watchEnabled = false    // stops the watcher's timer
        }
        apply(enable: enable, allowPrompt: true) { self.owned = false }
    }

    /// - allowPrompt: if passwordless sudo fails, fall back to a native admin
    ///   prompt. True for manual toggles, false for the watcher (no nagging).
    private func apply(enable: Bool, allowPrompt: Bool = false, then: (() -> Void)? = nil) {
        guard !busy else { return }
        busy = true
        Task.detached(priority: .userInitiated) {
            var failed = applyPmset(enable: enable)
            if failed && allowPrompt {
                failed = applyPmsetElevated(enable: enable)
            }
            let didFail = failed
            await MainActor.run {
                self.needsSetup = didFail
                self.refresh()
                self.busy = false
                then?()
            }
        }
    }

    // MARK: Process watcher

    private func persist() {
        defaults.set(watchEnabled, forKey: "watchEnabled")
        defaults.set(watchPattern, forKey: "watchPattern")
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard watchEnabled else {
            watchRunning = false
            if owned { owned = false; apply(enable: false) }   // restore sleep we forced
            return
        }
        // When the user flips watch mode on, install the passwordless-sudo rule
        // once (a single admin prompt) so the 8s poll can act silently. Skipped
        // on launch-restore (didInit == false) and when already set up.
        if didInit {
            Task.detached(priority: .userInitiated) {
                let needsInstall = !passwordlessReady()
                if needsInstall { _ = installSudoersElevated() }
                await MainActor.run { self.startWatchTimer() }
            }
        } else {
            startWatchTimer()
        }
    }

    private func startWatchTimer() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func tick() {
        let running = processRunning(watchPattern)
        watchRunning = running
        refresh()
        switch watchDecision(running: running, isAwake: isAwake, owned: owned) {
        case .keepAwake:  apply(enable: true)  { self.owned = true }
        case .allowSleep: apply(enable: false) { self.owned = false }
        case .doNothing:  break
        }
    }
}

// MARK: - UI

struct PopoverView: View {
    @ObservedObject var model: SleepModel

    var body: some View {
        PopoverContent(
            isAwake: model.isAwake,
            statusText: model.statusText,
            needsSetup: model.needsSetup,
            busy: model.busy,
            watchEnabled: model.watchEnabled,
            watchRunning: model.watchRunning,
            watchPattern: $model.watchPattern,
            onToggleAwake: { model.toggle() },
            onToggleWatch: { model.watchEnabled = $0 },
            onRefresh: { model.refresh() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
    }
}

// MARK: - App

@main
struct NoDozeApp: App {
    @StateObject private var model = SleepModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            Image(systemName: model.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}
