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
