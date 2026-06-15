# Releasing NoDoze

Two repos are involved:

- **[`davidcjw/nodoze`](https://github.com/davidcjw/nodoze)** — source code + GitHub Releases (the `NoDoze.zip` artifact).
- **[`davidcjw/homebrew-tap`](https://github.com/davidcjw/homebrew-tap)** — the Homebrew cask (`Casks/nodoze.rb`) that points at that zip.

Users install/upgrade with `brew install --cask davidcjw/tap/nodoze` / `brew upgrade --cask nodoze`. Homebrew compares the cask `version`, re-downloads the zip, verifies its `sha256`, then runs a `postflight` that strips the Gatekeeper quarantine flag (the app is ad-hoc signed, not notarized).

## Cutting a new version

1. **Make the change**, then bump the version in `Info.plist` (both keys must match):
   ```
   CFBundleVersion          → X.Y.Z
   CFBundleShortVersionString → X.Y.Z
   ```
   Use semver: bug fix → patch (`1.0.1`), new feature → minor (`1.1.0`).

2. **Test:**
   ```bash
   bash tests/run_tests.sh
   ```

3. **Commit & push** `main`.

4. **Build the artifact** — this builds `NoDoze.app`, zips it with `ditto` (preserves the ad-hoc signature), and **prints the sha256**. Copy it.
   ```bash
   bash scripts/make-release.sh
   ```

5. **Tag & create the GitHub Release**, attaching the zip:
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z
   gh release create vX.Y.Z NoDoze.zip --title "vX.Y.Z" --notes "..."
   ```

6. **Update the cask** in `homebrew-tap/Casks/nodoze.rb`: bump `version` and paste the new `sha256` from step 4. The `url` uses `v#{version}`, so it auto-points at the new release — no need to edit it.

7. **Upgrade your own machine** through Homebrew (don't hand-copy the build — keep it identical to what users get):
   ```bash
   brew update && brew upgrade --cask nodoze   # or: brew tap --repair && brew upgrade --cask nodoze
   ```
   Then quit the old menu-bar app (Homebrew won't kill a running app) and relaunch from `/Applications`. Confirm with `brew info --cask nodoze`.

## Gotchas

- **The sha256 must match the exact uploaded zip.** If you rebuild and re-upload, the sha changes and users hit a checksum error until the cask is updated. Always: build → upload *that* zip → paste *that* sha.
- **Not notarized.** No Apple Developer account, so the app is only ad-hoc signed and the cask strips quarantine in a `postflight`. This works for the personal tap but is why NoDoze can't go in the official `homebrew/cask`. With a Developer ID + `notarytool` notarization you could drop the postflight hack and submit upstream.
