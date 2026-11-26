# Tart test results (2026-11-24)

## Round 1

VM: clone of `tahoe-base` (macOS 26.6.2), Homebrew 7.0.12 updated to 7.0.16. Users: `admin` (501), `bob` (502), `homebrew` (600), all admin. Draft steps from HANDOFF.md run as written, with `-password <pw>` in place of `-password -` (non-interactive).

PASS

- `sysadminctl -addUser ... -admin`, then `dscl` IsHidden=1 and UserShell=/usr/bin/false: accepted.
- chown/chmod: `find /opt/homebrew ! -user homebrew` empty, before and after installs and upgrades.
- `brew as-brew-user update|install|upgrade` works from both users with the `/usr/bin/false` shell, so no need to revert to /bin/zsh.
- Plain `brew install` as a non-owner fails with a permission error (as intended).
- `HOMEBREW_*` vars from the caller are dropped (confirmed).
- Bob's password-protected sudo blocked `as-brew-user` without a password (boundary holds).

FINDINGS

- Plain `brew update` as a non-owner prints a "chown back to your user" message, so the wrapper must send it through `as-brew-user`.
- `git -C /opt/homebrew` fails with "dubious ownership" for non-owners. `brew --version` then reports "shallow or no git repository" for the admin user (7.0.16 for bob). Don't rely on git in the prefix as a non-owner.
- Wrapper read-only list is untested; `brew list`, `--version` work for non-owners.

ROUND 2 (wrapper, doctor, password, casks, services)

PASS

- Real sudo password prompt (pty, no sudoers rule): correct password lets `brew as-brew-user install` run; a wrong password fails after 3 tries and installs nothing. The boundary holds.
- Wrapper in a real zsh as the second user: `--version`, `list`, `install`, `uninstall`, `update` all work.
- Casks: `as-brew-user install --cask rectangle` works; the app lands in /Applications owned by `homebrew:admin`.
- `find /opt/homebrew ! -user homebrew` stayed empty throughout.

FINDINGS

- The draft read-only list is too long. As a non-owner, `info`, `search`, `config`, `outdated`, `deps`, `uses`, `leaves`, `desc` fail with a lock-file permission error (they download API data into the prefix). Only `--prefix --cellar --repository --version list ls home` run directly. Everything else must go through `as-brew-user`. Wrapper in HANDOFF.md needs that shorter list.
- `brew as-brew-user doctor` warnings seen were environmental (PATH order, /usr/local/lib dylibs, untrusted taps, cert.pem), not ownership-related.
- Services: `brew services start` as the owner fails to bootstrap (`launchctl bootstrap user/600 ... exited with 5`) because the hidden account has no GUI session. Root services need `sudo brew`, which this design forbids. Treat services as unsupported; the audited host uses none.
- Casks that are installed as the owner may differ in ownership from a normal install (app is owned by `homebrew`).

CAVEATS

- The VM's `admin` has passwordless sudo; the password prompt was tested only for `bob`.
- Tested on one macOS version (26.6.2) and Homebrew 7.0.16.

ROUND 3 (scripts run as real scripts, 2026-11-24)

PASS

- `tests/tart-test.sh` runs end to end from a fresh clone of the base VM (about 52 s) and ends with `PASS ownership`.
- `scripts/setup.sh` in a fresh VM: plan mode changes nothing; `--apply` creates the hidden `homebrew` account (UID 600, shell `/usr/bin/false`, `IsHidden 1`); a second run refuses with "User homebrew already exists."
- `scripts/verify.sh` afterwards: `PASS ownership`, `PASS brew --version`.

NOTES

- `sysadminctl` prints "No clear text password ... (will not allow user to use FDE)" when the password is passed with `-password`. This is expected and harmless for a hidden service account.

ROUND 4 (single script, fixes after a manual test, 2026-11-25)

Setup: fresh clone of `ghcr.io/cirruslabs/macos-tahoe-base:latest` (macOS 26.6.2, Homebrew 7.0.12). The repo is private, so the files were copied into the VM.

PASS

- `tests/tart-test.sh` from a fresh clone: ends with `PASS ownership`. New checks pass: the wrapper loads in a new login shell (admin and a second user); `brew doctor` through the wrapper shows no `sudo chown` advice; install and uninstall of `hello` through the wrapper.
- `setup.sh` ends with `PASS a new Terminal window loads the wrapper`.
- Manual test by the maintainer: `--check`, then the full interactive setup in a fresh VM, then the wrapper test. No problems.

FINDINGS

- A first manual test (private repo, files typed in by hand) ended with brew's "not writable ... `sudo chown -R admin /opt/homebrew`" advice. That text comes from `brew doctor` and the pre-install check (`diagnostic.rb`, `check_access_directories`), and also from `brew update` (`cmd/update.sh`, which checks `Cellar` and the repository and names that folder). It appears when a plain `brew` command runs as a non-owner, for example in a Terminal window opened before the wrapper was added. `brew list` and `brew --version` do not print it. The guide and `setup.sh` now tell the reader to open a new window and not to run that command.
- Plain `brew doctor` as a non-owner prints the advice. The test uses this as a negative control.
- Brew 7.0.12 prints a "taps are not trusted" warning for taps in the base image. A normal Mac may not see it. Not covered in the guide.

NOT TESTED

- `shellcheck` and `markdownlint` did not run on the host (CI runs them).
- The `git clone` step (the repo is private).
- GIFs and casts still show the old Part 5 wording. Re-record clip 05 after the public flip.

ROUND 5 (owner as a standard account, 2026-11-25)

Setup: fresh clone of `ghcr.io/cirruslabs/macos-tahoe-base:latest` (macOS 26.6.2, Homebrew 7.0.12). Created `stdbrew` with `sysadminctl -addUser` and no `-admin` flag (not in group `admin`). Changed `/opt/homebrew` to `stdbrew:admin`. Ran each command as `stdbrew` with no terminal (`sudo -u stdbrew`). `setup.sh` was not used.

PASS

- `brew update`, `brew install hello`, `brew upgrade`, `brew doctor`.

FAIL

- `brew install --cask rectangle`: brew runs `sudo cp -pR ... /Applications/Rectangle.app`. A standard account has no `sudo`, so the install stops (`sudo: a password is required`). `/Applications` is `root:admin` mode 775.

RESULT

- This supports the reason in the README: the owner is an administrator so casks can install into `/Applications`.
- Not tested: a cask with a `.pkg` installer (`powershell` is not a cask in this brew version). Also not tested: a standard owner with a terminal and a sudo password.

ROUND 6 (random owner password, 2026-11-25)

Setup: fresh clone of `ghcr.io/cirruslabs/macos-tahoe-base:latest` (macOS 26.6.2, Homebrew 7.0.12). The owner password is random and was never shown. Passwordless sudo was removed for the admin account. A second user ran `brew` through the wrapper in a pty (`su - bob`).

PASS

- `brew install --cask rectangle` asked for the second user's own password once. It asked for nothing else. The app landed in `/Applications`, owned by `homebrew:admin`. So the owner's password is not needed, even for a cask that copies into `/Applications` with `sudo`.
- `sudo dscl . -passwd /Users/homebrew <new>` followed by `dscl . -authonly` works (now a check in `tests/tart-test.sh`).
- `tests/tart-test.sh` passes with `setup.sh` (no `--password-stdin` option any more).

NOT TESTED

- A `.pkg` cask that runs an installer as the owner.

ROUND 7 (new-Mac path, 2026-11-25)

Setup: fresh clone of the base image. `/opt/homebrew` removed, then the official installer from brew.sh run as `admin` (Homebrew 7.0.16). The installer printed the `echo` and `eval` lines under `Next steps`.

PASS

- After the install, `/opt/homebrew` is owned by `admin`, and `setup.sh --check` reports the same problem state as path A. So the new-Mac guide hands over to the getting-started guide at Part 2.

NOT TESTED

- The installer's prompts (Return key, sudo password) were skipped (no terminal; the base image has passwordless sudo). The Command Line Tools were already present.

ROUND 8 (brew.env and rollback, 2026-11-25)

Setup: the VM left by `tests/tart-test.sh` (base image, macOS 26.6.2, Homebrew 7.0.16, setup done).

PASS

- `/etc/homebrew/brew.env` with `HOMEBREW_NO_AUTO_UPDATE=1` and `HOMEBREW_NO_ANALYTICS=1`: `brew as-brew-user config` shows both as set. The README now names this file.
- Rollback steps from the guide, as the admin: `chown -R`, wrapper line removed, `sysadminctl -deleteUser homebrew` (account and `/Users/homebrew` gone). Then `brew update`, `install` and `uninstall` work for the admin with no `sudo`. `find /opt/homebrew ! -user admin` is empty.
- Left over after the first three steps: `/usr/local/share/homebrew-shared-mac`. The guide now has a step to remove it.
- A second user who keeps the wrapper line in `~/.zshrc` still gets a working `brew` after rollback (`--version`, `install`). The wrapper is harmless.

NOT TESTED

- Older macOS versions. Decision (2026-11-25): tests run only on the newest macOS that Tart offers.

ROUND 9 (casks that need sudo, 2026-11-25)

Setup: `tests/tart-test.sh` in a fresh clone of the base image. A first run on a real Mac showed that a cask whose uninstall step calls `sudo` (Steam, launchctl service) asked for a password. The hidden account has a random password, so no one could answer.

PASS

- Steam installed in bob's `~/Applications`, then moved to `/Applications` by `setup.sh` with no password prompt. Brew still manages it. The temporary sudo rule (`/etc/sudoers.d/homebrew-shared-mac-temp`) is gone after the move. Rollback puts the app back. 43 checks passed, 0 failed.
- Control: the same test with the previous `setup.sh` fails at `Removing launchctl service ... Password:`. So the new check catches the bug.
- `--check` and the "Quit these apps" error now name the account that has the app open.

NOT TESTED

- The "Terminal would like to administer your computer" window (needs a GUI session).

ROUND 10 (first successful real-Mac run, 2026-11-25)

Setup: the user's own Mac (macOS 27.2.1, Homebrew 7.0.16, installed with the `.pkg`). The hidden account `homebrew` already owned `/opt/homebrew`. Two people accounts, both use Homebrew. Steam was in one user's `~/Applications`.

PASS

- `--check` found the Steam app and changed nothing. The full run moved Steam to `/Applications` with no password prompt, and all 5 PASS lines came back (owner, `brew --version`, wrapper, new Terminal window, no `--appdir`).
- The user logged in to the second account and started Steam with no problem.
- The temporary sudo rule is removed after the move (round 9 control).

Found and fixed

- Brew printed "running through sudo, using `user/*` instead of `gui/*`" and an `HOMEBREW_NO_ENV_HINTS` hint during the Steam uninstall. Both are harmless but look like errors. `setup.sh` now sets `HOMEBREW_SERVICES_NO_DOMAIN_WARNING=1` and `HOMEBREW_NO_ENV_HINTS=1`.
- "1 cask app(s)" now reads "1 cask app is" or "N cask apps are".

Tart check after the fix: `tests/tart-test.sh`, 44 checks passed, 0 failed. A new check confirms the setup output has no sudo-domain warning or hint.

NOT TESTED

- Steam's launch services under the user's GUI session in Tart. The real-Mac run covers this: Steam started.

## Round 11 (real-Mac report: wrapper from a private folder)

Found

- On a real Mac, `brew update` through the wrapper failed from a folder inside the user's home: "The current working directory must exist to run brew". The owner account cannot enter the user's home folder. All earlier tests ran from `/tmp`, so they missed it.

Fixed

- `brew-wrapper.zsh` runs the owner-run commands from `/tmp`.
- `setup.sh` now finds an out-of-date installed wrapper (`--check` reports it, the plan lists it, a normal run replaces it and says so).
- `setup.sh --rollback` now skips empty and used backup folders. Before, a re-run that changed nothing (for example only a wrapper refresh) left an empty newest backup, and `--rollback` stopped with "No backup found". The new test steps exposed this.
- New checks in `tests/tart-test.sh`: `brew update` through the wrapper from a mode-700 folder; `--check` flags a planted old wrapper; setup replaces it.

Tart check: the full `tests/tart-test.sh` passed (52 PASS, 0 FAIL). One earlier run hung for about 8 minutes at `brew uninstall --cask rectangle` (a macOS Automation prompt for the login item, inside the VM) and was killed; the rerun did not hang. Not done: running the new private-folder check against the old wrapper to see it fail.

## Round 12 (real-Mac report: cask upgrade asks for a password)

Found

- On a real Mac, `brew upgrade --cask` through the wrapper asked for a `sudo` password three times and failed for two apps (`bambu-studio`, `chatgpt`): `sudo -E -- touch /Applications/NAME.app/.homebrew-write-test` exited with 1. Those apps were owned by the person (mode 755), so the hidden owner account could not write to them. Brew then asks for the owner's password, and nobody knows it. The first checks only looked at `/opt/homebrew` and `~/Applications`.

Fixed

- `setup.sh` finds brew apps in `/Applications` that another account owns (`--check` reports them, the plan lists them) and gives them to the owner account. The change is saved in the backup and `--rollback` gives the old owner back (`app_chowned`). The final check has a new PASS line.
- New checks in `tests/tart-test.sh`: a person-owned app is flagged, setup fixes the owner, and `brew reinstall --cask` then works with no password. The script rollback runs twice (the newest backup is the owner change, then the main setup).

Tart check: the full `tests/tart-test.sh` passed (64 PASS, 0 FAIL). The known cask-uninstall hang appeared once and cleared by itself. Not done: the check against the old script to see it fail.

## Round 13: adopted casks

- Real Mac: `bambu-studio` and `chatgpt` had a real app copy in the Caskroom instead of a symlink, so `brew upgrade --cask` failed with "already an App at".
- `setup.sh` now lists those apps (also when the owner is right), moves the copy to the backup and puts the usual symlink in its place. `--rollback` puts the copy back (`caskroom_link`).
- New Tart checks: `--check` flags the second copy, setup makes it a link, rollback restores it, a second setup fixes it again, `brew reinstall` works. Full run: 82 PASS, 0 FAIL.

## Round 14: `brew update-all` (one password)

- Problem: the maintainer's update chain (`brew update && brew upgrade && brew upgrade --cask && brew autoremove && brew cleanup`) asked for a password five times. Homebrew 7 runs `sudo --reset-timestamp` at every user switch, so each `brew as-brew-user` call asks again.
- Manual run in a VM (second user, real sudo password): the old chain asks once per command. The new `brew update-all` asked once, ran update, upgrade, autoremove and cleanup, and exited 0. `find /opt/homebrew ! -user homebrew` stayed empty.
- Homebrew 7 asks `Do you want to proceed with the upgrade? [y/n]` before it upgrades. The first helper did not answer it and waited. `brew update-all --yes` skips it. `brew upgrade` already upgrades casks, so there is no separate `--cask` step.
- New check: `tests/pty-update-all.py` (run by `tests/tart-test.sh`) logs in as the second user, sets a custom sudo prompt, runs `brew update-all --yes`, and fails unless there is exactly one prompt, four step headings and exit 0.
- Tart check: the full `tests/tart-test.sh` passed (83 PASS, 0 FAIL).
- Not tested: a cask that needs `sudo` during `update-all`.
