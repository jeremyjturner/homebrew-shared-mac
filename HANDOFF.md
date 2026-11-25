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

**Remaining (2026-11-25, after rollback tests and the no-matrix decision). Everything else below is done.**

1. User task, later: follow `docs/new-mac.md` and `docs/getting-started.md` on a real Mac. Tart cannot test the installer prompts (Return key, sudo password) or the Command Line Tools install.
2. Done (2026-11-25): all seven casts uploaded to asciinema.org as unlisted (private-pattern scan: 0 hits). Each GIF in `docs/getting-started.md` has a "Watch this clip with pause and copy" link. After you re-record a clip, upload it again (`asciinema upload --visibility unlisted docs/casts/NAME.cast`) and update its link. Old uploads stay online until the user deletes them on asciinema.org.
3. Check once that the drift workflow works: `gh workflow run drift-check.yml`, then `gh run list --workflow drift-check.yml --limit 1` and `gh issue list --label upstream-drift`. Refresh snapshots with `scripts/drift-check.sh --update` after review when upstream changes.
4. Dropped by the user (2026-11-25): GUI screenshots, a `.pkg` cask test, a scheduled macOS-runner re-test, changing the demo passwords.
5. Test rules: tests run on the newest macOS that Tart offers. No version matrix (user decision). Read the Tart rules in `CLAUDE.md` before a test run (VM start wait, pty timeouts, delete VMs after).

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
