# homebrew-shared-mac

Share one Homebrew install between several macOS users without `/opt/homebrew is not writable` errors or permission juggling.

> **Status: draft.** The core flow was tested in a Tart VM (macOS 26.6.2, Homebrew 7.0.16). See [docs/test-results.md](docs/test-results.md). Test it in a VM before using it on a real machine.

## The problem

Two admin users share one Mac. Whoever last ran `sudo chown -R <me> /opt/homebrew` owns the prefix; the other user gets `Error: /opt/homebrew is not writable`.

## The approach

A dedicated hidden account, `homebrew`, owns `/opt/homebrew`. Every human runs `brew as-brew-user <command>`, which runs Homebrew as the owner after a normal sudo password prompt. A small shell function in each user's `~/.zshrc` does this automatically.

## Quick start

New to this? Follow the step-by-step [getting started guide](docs/getting-started.md). It has animated recordings of every step.

```sh
sudo ./scripts/setup.sh           # prints the plan only
sudo ./scripts/setup.sh --apply   # creates the account and changes ownership
```

Then add [scripts/brew-wrapper.zsh](scripts/brew-wrapper.zsh) to each user's `~/.zshrc`, open a new terminal, and run `./scripts/verify.sh`.

Close all brew and Claude Code sessions before running setup. Never run `sudo brew`.

## Threat model

| Choice | Why |
| --- | --- |
| Dedicated owner account | No human's daily session owns code the other user will later run with sudo. |
| Password-protected sudo kept | The sudo password prompt is the only real boundary. Tested: a wrong password installs nothing. |
| No passwordless sudoers rule | It would remove that boundary. |
| Not a group-writable prefix | Unsupported by Homebrew; drifts under umask 022; git "dubious ownership". |

Admin users can already become root, so this protects against accidents and drift, and against one user's session silently modifying code the other trusts. It does not defend against a malicious admin.

## Known limits (tested)

- Only `--prefix --cellar --repository --version list ls home` run directly as a non-owner. `info`, `search`, `outdated`, etc. need `as-brew-user`.
- `git` inside `/opt/homebrew` fails for non-owners ("dubious ownership").
- `HOMEBREW_*` variables are dropped; put settings in the owner's environment file.
- `brew services` does not work: the hidden account has no GUI session, and root services need `sudo brew`.
- Casks install owned by `homebrew`.
- Upgrade the `claude-code` cask only with no Claude Code session open.

## Rollback

```sh
sudo chown -R <your-user> /opt/homebrew
```

Then remove the wrapper from `~/.zshrc`. To delete the account: `sudo sysadminctl -deleteUser homebrew`.

## Compatibility

| macOS | Homebrew | Result |
| --- | --- | --- |
| 26.6.2 (Apple Silicon, Tart VM) | 7.0.16 | Passed |

## Testing

`tests/tart-test.sh` clones a Tart base VM and runs the setup there. See [docs/test-results.md](docs/test-results.md).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Licensed under [MIT](LICENSE).
