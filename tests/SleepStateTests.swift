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

        // pmset steps — single source of truth for commands and the sudoers rule.
        check("pmsetSteps on ends with disablesleep 1",
              pmsetSteps(enable: true).last == ["-a", "disablesleep", "1"])
        check("pmsetSteps off ends with disablesleep 0",
              pmsetSteps(enable: false).last == ["-a", "disablesleep", "0"])

        // Scoped sudoers allowlist: -g probe + 6 on/off steps, all argument-bound.
        let allow = sudoersPmsetCommands()
        check("sudoers allowlist is the 7 exact commands", allow.count == 7)
        check("sudoers allowlist includes the read-only probe", allow.contains("/usr/bin/pmset -g"))
        check("sudoers allowlist includes disablesleep on/off",
              allow.contains("/usr/bin/pmset -a disablesleep 1") && allow.contains("/usr/bin/pmset -a disablesleep 0"))
        check("sudoers allowlist is NOT a blanket pmset grant",
              !allow.contains("/usr/bin/pmset") && allow.allSatisfy { $0.hasPrefix("/usr/bin/pmset ") })

        // Sudoers install command builder.
        let cmd = sudoersInstallCommand(user: "alice")
        check("sudoers cmd: scoped rule for alice, not blanket pmset",
              cmd.contains("alice ALL=(root) NOPASSWD: /usr/bin/pmset -g,") && !cmd.contains("NOPASSWD: /usr/bin/pmset\n"))
        check("sudoers cmd: validates with visudo",
              cmd.contains("/usr/sbin/visudo -cf"))
        check("sudoers cmd: installs to /etc/sudoers.d/nodoze with 0440",
              cmd.contains("-m 0440 -o root -g wheel") && cmd.contains("/etc/sudoers.d/nodoze"))

        if failures > 0 { print("\(failures) test(s) failed"); exit(1) }
        print("All tests passed")
    }
}
