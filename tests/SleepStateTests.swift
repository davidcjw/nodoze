import Foundation

@main
struct Tests {
    static func main() {
        var failures = 0
        func check(_ name: String, _ cond: Bool) {
            print(cond ? "ok   - \(name)" : "FAIL - \(name)")
            if !cond { failures += 1 }
        }

        // Real `pmset -g` formats use padded spaces or tabs.
        check("SleepDisabled 1 -> awake",   parseSleepDisabled(" SleepDisabled    1") == true)
        check("SleepDisabled 0 -> asleep",  parseSleepDisabled(" SleepDisabled    0") == false)
        check("key absent -> asleep",       parseSleepDisabled(" hibernatemode 3\n standby 1") == false)
        check("tab separated -> awake",     parseSleepDisabled("SleepDisabled\t1") == true)
        check("multiline real-ish output",
              parseSleepDisabled(" System-wide power settings:\n SleepDisabled        1\n Currently in use:\n hibernatemode        0") == true)

        // Process-watcher decision logic.
        check("running + asleep -> keepAwake",
              watchDecision(running: true,  isAwake: false, owned: false) == .keepAwake)
        check("running + already awake -> nothing",
              watchDecision(running: true,  isAwake: true,  owned: true)  == .doNothing)
        check("stopped + we forced awake -> allowSleep",
              watchDecision(running: false, isAwake: true,  owned: true)  == .allowSleep)
        check("stopped + user forced awake -> nothing (don't override)",
              watchDecision(running: false, isAwake: true,  owned: false) == .doNothing)
        check("stopped + asleep -> nothing",
              watchDecision(running: false, isAwake: false, owned: false) == .doNothing)

        // Watch subtitle text.
        check("subtitle: disabled -> hint",
              watchSubtitle(enabled: false, running: false, pattern: "claude") == "e.g. claude, ollama, node")
        check("subtitle: running -> keeping awake",
              watchSubtitle(enabled: true, running: true, pattern: "claude") == "‘claude’ running — keeping awake")
        check("subtitle: not running -> sleep normal",
              watchSubtitle(enabled: true, running: false, pattern: "ollama") == "‘ollama’ not running — sleep normal")

        if failures > 0 { print("\(failures) test(s) failed"); exit(1) }
        print("All tests passed")
    }
}
