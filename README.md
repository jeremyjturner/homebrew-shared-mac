# homebrew-shared-mac

Fix `Error: /opt/homebrew is not writable` when two or more people share one Mac.

## Did you see this error?

```text
Error: /opt/homebrew is not writable
```

You are in the right place.
Do not run the `sudo chown` command that Homebrew shows.
It fixes the problem for one person only.
The next person gets the same error.

## Why this happens

Homebrew keeps all its files in one folder: `/opt/homebrew`.
That folder has one owner.
Only the owner can install software with `brew`.
When a second person uses the Mac, they are not the owner.
So `brew` stops with the error.

## The fix

Homebrew's own guide for Mac administrators gives the answer:
use one dedicated account to own the Homebrew folder,
and run `brew` commands as that account.
Read it here: [Homebrew for Mac Admins](https://docs.brew.sh/Homebrew-for-Mac-Admins).

What that guide says:

- Choose one account to own the Homebrew folder.
  It can be a person's account or a dedicated account.
- That account needs write access to the Homebrew folders.
- Use `brew as-brew-user <command>` to run a command as the owner.
  `brew` uses `sudo` to switch accounts.
- Do not let independent users manage the same installation at the same time.
- Homebrew gives no security guarantee when the users who can write to the folder are not trusted.

This repository does that for you:

- One script creates a hidden account. You choose its name. The script sets a random password.
- That account owns `/opt/homebrew`.
- A small helper, the wrapper, goes in each person's `~/.zshrc`.
  It sends `brew` commands to the hidden account.
- Each person types their own password to install software.

A copy of the Homebrew page is in [docs/upstream-snapshots](docs/upstream-snapshots/Homebrew-for-Mac-Admins.snapshot).
A weekly check shows when the original page changes.

## Choose your path

### Path A: you already have the error

Homebrew and two or more accounts exist.
The folder has the wrong owner, or several owners.

1. Open the [getting started guide](docs/getting-started.md).
2. Start at Part 1.
3. In Part 3, run the check first. It changes nothing.
4. In Part 4, the script fixes the owner.

### Path B: you set up a new Mac

You want to avoid the problem from the start.

1. Open the [new Mac guide](docs/new-mac.md).
2. It installs Homebrew and adds the second account.
3. It then sends you to the [getting started guide](docs/getting-started.md), Part 2.

## Quick look

```sh
git clone https://github.com/jeremyjturner/homebrew-shared-mac.git
cd homebrew-shared-mac
sudo ./scripts/setup.sh --check   # reads only; writes a report file
sudo ./scripts/setup.sh           # asks, then creates the account and fixes the owner
```

The script is the only script you need. It:

- checks your Homebrew,
- creates the hidden account,
- changes the owner of `/opt/homebrew`,
- adds the wrapper to your `~/.zshrc`,
- writes a report file that you can give to your own AI agent.

Each other person then adds the wrapper to their `~/.zshrc`. The script prints the command.
After the setup, close the Terminal window and open a new one. Only a new window loads the wrapper.

> **Warning:** The script changes who owns `/opt/homebrew`.
> Close all `brew` commands and Claude Code sessions first.
> Never run `sudo brew`.
> We tested it in virtual machines. Read each step in the guide before you use it on a Mac that you need.

## Details for administrators

### Threat model

| Choice | Why |
| --- | --- |
| Dedicated owner account | No person's daily session owns code that another person later runs with sudo. |
| Password-protected sudo kept | The sudo password prompt is the only real boundary. Tested: a wrong password installs nothing. |
| No passwordless sudoers rule | It would remove that boundary. |
| Not a group-writable prefix | Homebrew does not support it. It drifts under umask 022. Git reports "dubious ownership". |

Administrator users can already become root.
This setup protects against accidents and drift,
and against one user's session silently changing code that the other user trusts.
It does not defend against a malicious administrator.

### The hidden account

The script creates one account to own `/opt/homebrew`. It is the dedicated owner that Homebrew's guide describes.

- It is hidden, so it does not show on the login window.
- Its shell is `/usr/bin/false`, so nobody can log in with it.
- Its user ID is 600 or the next free number. Its type is administrator.
  This lets apps (casks) install into `/Applications` and run installers that need `sudo`.
  Homebrew's own example uses a standard account, which cannot do this.
- You choose its name. The script sets a random password that nobody sees.
  Homebrew does not need it (tested: casks that need `sudo` install without it).
  An administrator can set a new password with `sudo dscl . -passwd /Users/homebrew <new-password>`.

### Known limits (tested)

- Only `--prefix --cellar --repository --version list ls home` run directly as a non-owner. `info`, `search`, `outdated` and others need `as-brew-user`. The wrapper does this for you.
- `git` inside `/opt/homebrew` fails for non-owners ("dubious ownership").
- `HOMEBREW_*` variables from your shell are dropped. Put settings in `/etc/homebrew/brew.env`, one `NAME=value` per line (tested with `HOMEBREW_NO_AUTO_UPDATE` and `HOMEBREW_NO_ANALYTICS`). Create the file with `sudo`.
- `brew services` does not work. The hidden account has no GUI session, and root services need `sudo brew`.
- Casks install owned by the hidden account.
- Upgrade the `claude-code` cask only with no Claude Code session open.
- If `brew` shows "not writable" and a `sudo chown` command, the window does not have the wrapper. Do not run the command. Open a new Terminal window.

### Rollback

```sh
sudo chown -R <your-user> /opt/homebrew
```

Then remove the wrapper line from `~/.zshrc`.
To delete the account: `sudo sysadminctl -deleteUser homebrew`
(use the name that you chose).

### Compatibility

| macOS | Homebrew | Result |
| --- | --- | --- |
| 26.6.2 (Apple silicon, Tart VM) | 7.0.12 | Passed |
| 26.6.2 (Apple silicon, Tart VM) | 7.0.16 | Passed (earlier rounds) |

Tests run on the newest macOS that Tart offers. Older macOS versions are not tested.

### Testing

`tests/tart-test.sh` clones a Tart base VM and runs the setup there.
See [docs/test-results.md](docs/test-results.md).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
Licensed under [MIT](LICENSE).
