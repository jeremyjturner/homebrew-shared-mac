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

- A first manual test (private repo, files typed in by hand) ended with brew's "not writable ... `sudo chown -R admin /opt/homebrew`" advice. That text comes only from `brew doctor` and the pre-install check (`diagnostic.rb`, `check_access_directories`). It appears when a plain `brew` command runs as a non-owner, for example in a Terminal window opened before the wrapper was added. `brew list` and `brew --version` do not print it. The guide and `setup.sh` now tell the reader to open a new window and not to run that command.
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
