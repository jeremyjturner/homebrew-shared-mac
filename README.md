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
- `brew update-all` updates and cleans everything with one command and one password. See [Update everything](#update-everything-with-one-command).

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

1. Open the [getting started guide](docs/getting-started.md).
2. In Part 1, it shows you how to install Homebrew.
3. Then follow Part 2 and the parts after it. The script creates the hidden account for you.
   You do not need to create a second account first.

### Path C: let your AI assistant do it

You use an AI assistant that can run commands on your Mac.

1. Open the [AI assistant guide](docs/llm-prompt.md).
2. Copy the prompt and paste it into your assistant.
3. Read the plan. Say yes only if you agree. Type your own password when `sudo` asks.

## Update everything with one command

Homebrew asks for your password at every `brew` command.
A full update is four commands, so it asks four times.
The wrapper adds `brew update-all`. It asks one time.

```sh
brew update-all
```

![One password. The four steps run one after the other.](docs/images/08-update-all.gif)

How it works:

1. The wrapper switches to the hidden account one time. This is the one password.
2. That account runs `brew update`, `brew upgrade`, `brew autoremove` and `brew cleanup`, one after the other.
3. It stops at the first step that fails.
4. Homebrew shows the list of upgrades and asks `[y/n]`. Add `--yes` (or `-y`) to skip the question.

The script adds no sudo rule, so the password prompt stays the only boundary.
`update-all` is not a Homebrew command. It works in a new Terminal window after the setup.
Details: [getting started guide](docs/getting-started.md#update-everything-with-one-command).

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
| No permanent passwordless sudoers rule | It would remove that boundary. Setup adds one for a short time only when it moves apps. See the next section. |
| Wrapper file owned by root | The wrapper runs in every person's shell. Only root can change it (`/usr/local/share/homebrew-shared-mac`). |
| Not a group-writable prefix | Homebrew does not support it. It drifts under umask 022. Git reports "dubious ownership". |

Administrator users can already become root.
This setup protects against accidents and drift,
and against one user's session silently changing code that the other user trusts.
It does not defend against a malicious administrator.

### Does this reduce security?

**Short answer:** a little, compared with one person who uses Homebrew alone.
It is better than the usual ways to share Homebrew.
It does not help if you do not trust the other people on the Mac.

#### Where it is weaker than one person on one Mac

| Change | Why it matters | When it matters |
| --- | --- | --- |
| One more administrator account. | `brew` runs formula scripts and cask installers as this account. An administrator can write to `/Applications` and other shared places. | When you want Homebrew code to have no administrator rights. A standard-account owner cannot install casks (tested). |
| A temporary sudo rule for the owner. | While setup moves apps out of `~/Applications`, `/etc/sudoers.d/homebrew-shared-mac-temp` lets the owner use `sudo` without a password. Setup removes it when it ends. | Only if setup stops hard (power loss or `kill -9`). Then delete that file. `setup.sh --check` counts `NOPASSWD` rules. |
| The sudo cache. | After you type your password, any program in that Terminal window can run `brew` as the owner for about 5 minutes. | It works like any `sudo` command, so it is not new. Run `sudo -k` to end it. |

The account is hard to misuse.
Nobody knows its password: it is random, 24 characters, never shown, never saved, and not in command arguments.
Its shell is `/usr/bin/false` and it is hidden from the login window.

#### Where it is stronger than the usual ways to share

- Make the prefix group-writable: any administrator can change code that another person runs, with no prompt.
- Run `chown` for whoever needs `brew` now: the next person gets the same error, and the last person's session owns the code.
- Add a passwordless sudo rule: any program can change the shared code with no prompt.

Here, a program that runs as one person cannot change Homebrew without that person's password.
Tested: a wrong password installs nothing.

#### What it does not change

- Every person who runs `brew` must be an administrator. `sudo` is how they switch to the owner. A standard account has no `sudo` (not tested).
- Administrators can become root, set the owner's password and change the wrapper. There is no protection against a malicious administrator.
- Software is shared. A package that one person installs runs for everyone. Homebrew does not check formulas or casks for you. Install only what you trust.
- If you do not trust the other people on the Mac, do not share one Homebrew install.

### The hidden account

The script creates one account to own `/opt/homebrew`. It is the dedicated owner that Homebrew's guide describes.

- It is hidden, so it does not show on the login window.
- Its shell is `/usr/bin/false`, so nobody can log in with it.
- Its user ID is 600 or the next free number. Its type is administrator.
  This lets apps (casks) install into `/Applications` and run installers that need `sudo`.
  Homebrew's own example uses a standard account, which cannot do this.
- You choose its name. The script sets a random password that nobody sees.
  Homebrew does not need it to install casks (tested), even casks that copy into `/Applications` with `sudo`.
  An administrator can set a new password with `sudo dscl . -passwd /Users/homebrew <new-password>`.

### Known limits (tested)

- Only `--prefix --cellar --repository --version list ls home` run directly as a non-owner. `info`, `search`, `outdated` and others need `as-brew-user`. The wrapper does this for you.
- `git` inside `/opt/homebrew` fails for non-owners ("dubious ownership").
- `HOMEBREW_*` variables from your shell are dropped. Put settings in `/etc/homebrew/brew.env`, one `NAME=value` per line (tested with `HOMEBREW_NO_AUTO_UPDATE` and `HOMEBREW_NO_ANALYTICS`). Create the file with `sudo`.
- `brew services` does not work. The hidden account has no GUI session, and root services need `sudo brew`.
- Casks install owned by the hidden account.
- A cask that calls `sudo` when it is removed (Steam is one) can ask for a password that nobody has. Setup works around this only for apps that it moves.
- Upgrade the `claude-code` cask only with no Claude Code session open.
- If `brew` shows "not writable" and a `sudo chown` command (for example `/opt/homebrew/Cellar is not writable` after `brew update`), the window does not have the wrapper. Do not run the command. Open a new Terminal window.

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
| 27.2.1 (Apple silicon, real Mac) | 7.0.16 | Passed: setup, wrapper, cask move, `brew update-all` |

Tests run on the newest macOS that Tart offers. Older macOS versions are not tested.

### Security checks

Every push and pull request runs these scans in GitHub Actions. They need no secrets and cost nothing:

| Check | What it looks at |
| --- | --- |
| ShellCheck | The shell scripts. |
| markdownlint | The docs. |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Passwords and keys in the whole git history. |
| [zizmor](https://github.com/zizmorcore/zizmor) | Unsafe patterns in the workflow files. |
| [CodeQL](https://codeql.github.com/) | The workflow files and the Python helpers. |
| [OpenSSF Scorecard](https://scorecard.dev/) | The repository's own habits: pinned actions, branch protection, security policy. |
| Dependabot | Updates for the pinned actions. |

GitHub secret scanning and push protection are also on.
Tools for languages this repository does not use (Rust, JavaScript and so on) are left out on purpose.

### Testing

`tests/tart-test.sh` clones a Tart base VM and runs the setup there.
See [docs/test-results.md](docs/test-results.md).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
Licensed under [MIT](LICENSE).
