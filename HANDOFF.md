# Handoff

Public GitHub repo `homebrew-shared-mac` (made public 2026-11-25). Branch protection on `main`: signed commits required, no force-push or deletion, admins included. CI (ShellCheck, markdownlint) passed on earlier commits; check the latest run.

## Done

- Tart tests (two rounds) passed: see `docs/test-results.md`.
- Scaffolding: README, LICENSE (MIT, copyright "homebrew-shared-mac contributors"), CONTRIBUTING, SECURITY, `scripts/` (setup, verify, brew-wrapper.zsh), `tests/tart-test.sh`, CI (ShellCheck, markdownlint), Dependabot, issue template.
- Wrapper read-only list was shortened to what tests showed works.
- Actions pinned to SHAs (checkout v7.0.1, markdownlint-cli2-action v25.1.0).
- shellcheck and markdownlint run clean inside the Tart VM (config in `.markdownlint-cli2.jsonc`).
- License confirmed: MIT.
- Host changes (user-approved): SSH signing key `~/.ssh/id_ed25519_signing`, global git signing config with the no-reply email, `gh` installed. Tart VM `hb-test` still exists (stopped).

## Not done / next

1. Done: `tests/tart-test.sh` and `setup.sh` (now the only script; `verify.sh` was folded in) run as real scripts in Tart; see round 3 in `docs/test-results.md`.
2. Done (terminal recordings instead of GUI screenshots): `docs/demo/record.py` (asciinema + agg, driven through a pty) makes seven GIFs in `docs/images/` (speed 0.75, set by `SPEED` in the script) and keeps the casts in `docs/casts/` (they play in the asciinema player; GIFs cannot pause); `docs/demo/render.sh` rebuilds them in a fresh Tart VM (`hb-demo`) cloned from the pristine OCI image, not from the old `tahoe-base`. Step-by-step guide for a new user: `docs/getting-started.md` (simplified-English style, about 80% ASD-STE100). Still open: GUI screenshots (needs Screen Recording permission) and a second guide for the problem state (users and Homebrew already exist, wrong owner).
3. Done: GitHub login, signing key uploaded, email privacy settings, repo created (private).
4. At the public flip (needs public repo or GitHub Pro): apply branch protection (signed commits required, no force-push/deletion, admins included).
5. Drift check: done. `scripts/drift-check.sh` compares raw upstream docs (Mac Admins, FAQ, Installation from Homebrew/brew) with `docs/upstream-snapshots/`; `.github/workflows/drift-check.yml` runs it weekly (Mondays) and opens or updates an `upstream-drift` issue. Refresh snapshots with `scripts/drift-check.sh --update` after review. Still open: scheduled Tart/latest-Homebrew re-test (needs a macOS runner). Verify the workflow once via `gh workflow run drift-check.yml`.
6. Coverage gaps: closed (see item 5 below). No macOS version matrix by decision.

## Open items to pick up

- **Single script (2026-11-25):** `scripts/setup.sh` checks Homebrew (install method, owners, accounts, who uses brew), fixes the wrong-owner/mixed-owner problem, creates the hidden owner account (user picks name and password), installs the wrapper, and writes a report file for the user's own AI agent. `--check` changes nothing. `--yes --password-stdin --owner NAME` is for tests. Tested in Tart: problem, mixed owners, fix, re-run (no-op), drift. The interactive prompts (read from `/dev/tty`) were recorded in `docs/images/04-setup.gif`; `tart exec` without a tty cannot test them.
- `docs/getting-started.md` was rewritten for this flow (Parts 1-7, no Tart mentions). Still to do: README rewrite (Mac Admins summary and link, greenfield path vs. already-broken path, plain language), guide for the greenfield path, test-results round 4, shellcheck/markdownlint (not run on the host).
- The `git clone` URL in the guide needs the repo to be public. The clip for Part 2 (`02-get-files`) shows steps 2 to 5 with a real clone from GitHub.
- The pristine image's Homebrew is 7.0.12; `docs/test-results.md` still says 7.0.16 (from the old `tahoe-base`). Update the compatibility table after a new test round.
- The user's own video `2026-11-24 23-46-35.mp4` sits untracked in the repo root. Do not commit it.
- Dependabot PRs #1 and #2 are closed and their branches are gone.
- Git remote is SSH (`git@github.com:...`); the signing key is registered for both signing and authentication.
- Suggested next: guide for the problem state (existing users, Homebrew already installed); then item 6 coverage gaps.
- Demo clips: `record.py` refuses to run if `hb-demo` is down. VHS was dropped: `Wait+Screen` read stale screens. Recording now waits on the text stream.
- `asciinema` and `agg` are installed on the host (user-approved 2026-11-25); `vhs`/`ttyd` from before are no longer used.
- ssh-agent holds the signing key via keychain; if commits hang, re-run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_signing` in a normal terminal.

## Appdir migration and rollback (2026-11-25, after the first real-Mac look)

- `scripts/setup.sh` now also: adds the wrapper to every account that uses brew (no manual per-user step), comments out `HOMEBREW_CASK_OPTS=...--appdir...` lines (marker: `# homebrew-shared-mac disabled:` and a space), and moves brew-managed apps from a user's `~/Applications` to `/Applications` with `brew as-brew-user reinstall --cask --appdir=/Applications NAME`. Without the explicit `--appdir`, brew reuses the folder saved at first install (Tart caught this).
- Every change goes into `/usr/local/share/homebrew-shared-mac/backups/TIMESTAMP/manifest` (apps in `apps/`, file copies in `files/`). `sudo ./scripts/setup.sh --rollback [--backup DIR]` reverses it from last to first. Rollback leaves moved apps unmanaged by brew.
- Apps are found through the Caskroom symlinks that point into `~/Applications`. A running app stops the script before any change.
- Full `tests/tart-test.sh` passed (run 5): new checks for the report, migration, wrapper lines, script rollback, then re-setup and the manual rollback.
- Still open: clips 04 (no wrapper question any more) and 06 (wrapper is already added) are out of date and need re-recording; `docs/test-results.md` needs a round for this; not committed yet; the first real-Mac run is described below.

## Rules from the user

- Use Tart for testing before making any change on this machine.
- Keep personal info out of the repo. Every commit is checked by local hooks (`.git/hooks/pre-commit`, `commit-msg`, patterns in the untracked `.git/hooks/private-patterns`). These hooks are not cloned: recreate them on any new clone. Do not use `--no-verify`.
- Make the repo public only when the user says it is ready.

## Status after the public flip (2026-11-25)

- Pre-public checks done: private-pattern scan of files, history and casts; every GIF reviewed (frames sampled every 3 s).
- Clean test from a real `git clone` (HTTPS) in a fresh VM passed: setup, new-window wrapper check, `brew install hello`, second user, ownership.
- Clips 04 and 05 re-recorded (new "Next" text; `type brew` step). Clips 01-03, 06, 07 are unchanged and still match the guide.
- Why the hidden owner is an administrator (stated in the README): casks must install into `/Applications` (group `admin` can write there) and some need `sudo`. Source: the Mac Admins snapshot and test round 1 (rectangle landed owned by `homebrew:admin`). A standard owner has not been tested here.
- README rewritten (two paths, Mac Admins summary). Still open: shellcheck and markdownlint in a VM (not on the host); README rewrite; greenfield guide; the "taps are not trusted" warning in brew 7.0.12 (only seen with the base image's taps).
- Remember: the base image's admin has passwordless sudo; `docs/demo/prepare.sh` removes it so the clips show real prompts. A manual test VM needs the same removal to see real prompts.

## Manual test status (2026-11-25)

The user's second manual test (fresh VM, scripts copied in) worked with no issues after the wrapper fixes (new-window check in `setup.sh`, Part 5 note, extra checks in `tests/tart-test.sh`). Round 4 is in `docs/test-results.md`. Next: shellcheck/markdownlint in a VM, re-record clip 05, then the public flip (see steps below). The pre-public scan of files, history and casts was clean; the GIF frames still need a look.

## Previous manual test instructions (user)

Start a clean VM: `tart delete hb-manual 2>/dev/null; tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest hb-manual && tart run hb-manual`. Create a second admin user in System Settings (the guide says two admin accounts are needed), then follow `docs/getting-started.md`. The repo is private, so the `git clone` step will not work until it is public. Copy the repo into the VM another way for now.

## Next steps (in order, saved 2026-11-25, end of day)

Last commit: see `git log` (signed, pushed). Check the latest CI run. Working tree clean except the user's untracked `.mp4` (do not commit). The repo is public and `main` is protected (signed commits required, no force-push or deletion, admins included): every push must be signed.

**State at the end of the 2026-11-25 session: the only open item is 1 (a real-Mac test by the user). CI is green and the working tree is clean. Everything else below is done.**

1. User task, later: follow `docs/new-mac.md` and `docs/getting-started.md` on a real Mac. Tart cannot test the installer prompts (Return key, sudo password) or the Command Line Tools install.
2. Done (2026-11-25): all seven casts uploaded to asciinema.org as unlisted (private-pattern scan: 0 hits). Each GIF in `docs/getting-started.md` has a "Watch this clip with pause and copy" link. After you re-record a clip, upload it again (`asciinema upload --visibility unlisted docs/casts/NAME.cast`) and update its link. Old uploads stay online until the user deletes them on asciinema.org.
3. Done (2026-11-25): `gh workflow run drift-check.yml` ran green and opened no `upstream-drift` issue (snapshots match upstream). The weekly run is on. When an issue appears, review it, then refresh with `scripts/drift-check.sh --update`.
4. Dropped by the user (2026-11-25): GUI screenshots, a `.pkg` cask test, a scheduled macOS-runner re-test, changing the demo passwords.
5. This session also: Part 2 clip re-recorded (`02-get-files`, real clone; `prepare.sh` now waits for the VM), pty prompt tests and a rollback test added to `tests/tart-test.sh`, `CLAUDE.md` got the Tart and lint rules. All Tart test VMs are deleted; only the OCI base image remains.
6. Test rules: tests run on the newest macOS that Tart offers. No version matrix (user decision). Read the Tart rules in `CLAUDE.md` before a test run (VM start wait, pty timeouts, delete VMs after).

Details of finished work:

1. Done: `docs/new-mac.md` (install Homebrew, add the second account, then Part 2 of the getting-started guide). Round 7 in `docs/test-results.md`. A reader who follows it on a real Mac is the missing test (installer prompts, Command Line Tools).
   Also done: the hidden owner now gets a random password (round 6); no password prompt, `--password-stdin` removed. Only clip 04 changed. The other clips never showed that prompt.
2. Done (round 5 in `docs/test-results.md`): a standard-account owner runs `update`, `install`, `upgrade`, but a cask fails (needs `sudo` for `/Applications`). This confirms the README reason. Not tested: a `.pkg` cask.
3. Done (2026-11-25): the "untrusted" label in brew 7.0.12 is only for third-party taps (`buildkite/buildkite`, `equinix-labs/otel-cli`, `openai/tools`, `yq`, all added by the base image). The full warning ("brew trust ...", lists only those taps) did show in the full test run, on `brew install` as the second user, and not in a plain root-less `brew install hello` as admin. It names only the base image's third-party taps. A normal Mac has no third-party taps, so no guide note is needed. A user who added their own tap may see the label.
4. Done (2026-11-25): `tests/pty-test.py` (run by `tests/tart-test.sh`) drives `setup.sh` through a pty with real sudo passwords: wrong password stops it, `n` at the plan changes nothing, Enter at the name prompt gives `homebrew` and `y` finishes. It removes the image's passwordless sudo for these checks and puts it back at the end. `tart-test.sh` also now waits until the VM is listed as running (it failed before when `tart ip` ran too early). Full run passed.
5. **Coverage gaps:** brew.env and rollback done (round 8: `/etc/homebrew/brew.env` works through `as-brew-user`; guide rollback works and now removes the wrapper files). Services: documented as unsupported (round 2). No macOS version matrix: the user decided (2026-11-25) that tests on the newest macOS that Tart offers are enough. The rollback is now tested in `tests/tart-test.sh` (full run passed, 5 new checks).
6. **Open questions:** is playback speed 0.75 right? Link a player for the `.cast` files (asciinema.org needs the user's approval, or self-host)?
7. **Housekeeping:** old Tart VMs were deleted 2026-11-25 with user approval. Playback speed 0.75 is confirmed. The `.cast` player is the user's task for another day. `asciinema` and `agg` are still installed on the host (user-approved; the clips need them).
8. **Lint on the host:** `shellcheck` and `markdownlint-cli2` are installed (user-approved 2026-11-25) and run clean. CI also runs them.
9. `tests/tart-test.sh` now makes random passwords per run. `docs/demo/prepare.sh` and `record.py` still use fixed demo passwords (`bobpw`, `demo-password`) because they are typed on screen in the clips. Changing them means re-recording.

## First real-Mac run (2026-11-25)

- Result: setup failed on Steam. Brew runs as the hidden account, and Steam's uninstall calls `sudo`. Fix: `migrate_apps` writes a temporary `/etc/sudoers.d/homebrew-shared-mac-temp` rule for the owner, removed at the end and by an EXIT trap. `tests/tart-test.sh` now installs Steam; it fails with the old script and passes with the new one (round 9).
- `--check` and the open-app error now name the account (`ps` user). Guide mentions the "Terminal would like to administer your computer" window.
- Real Mac state after the failed run: the hidden account and owner change were done; Steam stayed in `~/Applications` and brew's Steam record may be half removed. The user should run `sudo ./scripts/setup.sh --rollback` or check `brew list --cask`, quit Firefox and Claude Code in both accounts, then run the new script.
- Open: a failed reinstall should leave a clear message about the cask's brew state.

## Session end (2026-11-25, after the Steam fix)

- Pushed: `e2e89a3` (sudo fix, account names, docs, round 9) and `5173b88`, `ceb1380` (clips 03, 04, 06 re-recorded; `prepare.sh` now makes bob a Homebrew user, `record.py` clip 06 starts with `type brew`). Clips 04 and 06 match the current script. Clip 05 is unchanged.
- Next: the user runs the new script on the real Mac and brings the results back. Steps: `sudo ./scripts/setup.sh --rollback` (or check `brew list --cask`), quit Firefox and Claude Code in both accounts, `sudo ./scripts/setup.sh --check`, then `sudo ./scripts/setup.sh`. Things to look at in the results: the Steam move with no password prompt, the temporary rule `/etc/sudoers.d/homebrew-shared-mac-temp` is gone, the account names in `--check`, the final PASS lines.
- Open: CI result for the pushed commits not checked; a failed reinstall message; the "administer your computer" window cannot be tested in Tart.

## Second real-Mac run (2026-11-25)

- The user ran `--check` and the full `setup.sh` on the real Mac: Steam moved with no password prompt, all PASS lines, and Steam starts in the second account. Recorded as round 10 in `docs/test-results.md`.
- Changes after that run (committed and pushed as `3cdca42`; CI passed): `setup.sh` sets `HOMEBREW_SERVICES_NO_DOMAIN_WARNING=1` and `HOMEBREW_NO_ENV_HINTS=1`, and the "cask app(s)" wording is fixed. `tests/tart-test.sh` has a new check for the warning (full run: 44 PASS, 0 FAIL; `hb-test` deleted).
- Open: the user still has the old-app backup in `/usr/local/share/homebrew-shared-mac/backups/` (delete when happy). A failed reinstall should leave a clear message about the cask's brew state. The "administer your computer" window cannot be tested in Tart.
- Dock note (2026-11-25): the user saw a question-mark icon in the Dock for a moved app (Firefox). `setup.sh` "Next" step 4 and `docs/getting-started.md` (after the move list, and in Rollback) now tell the user to drag the icon out and add the app again from its new place. Tart run: 44 PASS. Clip 04 does not move apps, so it is unaffected. Not automated: the Dock cannot be tested in Tart.
