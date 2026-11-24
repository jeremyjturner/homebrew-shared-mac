# Getting started

This guide shows you how to share one Homebrew installation between two users on one Mac.
It starts from a new Homebrew installation.
Follow the steps in order.
Do not skip a step.

> **Warning:** This guide changes the owner of the Homebrew folder.
> Read each step before you do it.
> Test the steps in a virtual machine first. See [Test results](test-results.md).

## What you get

- One hidden account named `homebrew` owns Homebrew.
- Each person uses their own account for daily work.
- Each person types their own password to install software.
- No person must change the owner of the Homebrew folder again.

## What you need

- A Mac with Apple silicon (M1 or later).
- Homebrew installed in `/opt/homebrew`.
- Two people, or two accounts for one person. Both accounts must be administrator accounts.
- About 20 minutes.

## Words used in this guide

| Word | Meaning |
| --- | --- |
| Terminal | The app where you type commands. |
| Command | A line of text that you type in Terminal and send with the Return key. |
| Administrator | An account that is allowed to change the Mac. |
| Prefix | The folder where Homebrew keeps its files: `/opt/homebrew`. |
| Owner | The account that controls a folder. |
| Wrapper | A short text that sends your `brew` command to the `homebrew` account. |

## How to read the pictures

Each picture is an animation of a real test in a virtual machine.
The `$` symbol is the prompt. Do not type it.
When a command asks for a password, no characters show on the screen. This is normal.

## Part 1: Check your start state

1. Open Terminal.
   Press Command + Space, type `Terminal`, and press Return.
2. Type this command and press Return:

   ```sh
   brew --version
   ```

   You see a line that starts with `Homebrew`.
   If you see `command not found`, install Homebrew first. Go to <https://brew.sh>.
3. Type this command and press Return:

   ```sh
   ls -ld /opt/homebrew
   ```

   You see your user name in the third column.
   This is the problem state. Your account owns the prefix.

## Part 2: Create the second administrator account

Do this part only if the second account does not exist.

1. Open System Settings.
2. Click **Users & Groups**.
3. Click **Add User…** and type your password.
4. Set **Account Type** to **Administrator**.
5. Type a full name, an account name, and a password.
6. Click **Create User**.

> **Note:** This guide does not show pictures for these steps.
> The steps can look different in other versions of macOS.

## Part 3: Get the files

1. Close all `brew` commands that are running.
   Close all Claude Code sessions.
2. In Terminal, go to your home folder:

   ```sh
   cd ~
   ```

3. Download the files. Use the address of this repository:

   ```sh
   git clone <repository-address>
   ```

   Copy the address from the green **Code** button on the repository page.
4. Go into the new folder:

   ```sh
   cd homebrew-shared-mac
   ```

## Part 4: Read the plan

The setup script has two modes.
Without `--apply`, it only prints a plan. It changes nothing.

1. Type this command and press Return:

   ```sh
   sudo ./scripts/setup.sh
   ```

2. Type your password and press Return.
3. Read the plan.

![The plan: create the homebrew account, hide it, and change the owner of /opt/homebrew.](images/01-plan.gif)

You see this text:

```text
Plan (re-run with --apply):
  1. create admin user 'homebrew' (UID 600), prompting for a password
  2. hide it and set its shell to /usr/bin/false
  3. chown -R homebrew:admin /opt/homebrew ; chmod -R g-w,o-w /opt/homebrew
Rollback: sudo chown -R <user> /opt/homebrew
```

If you see an error, read it.
The script stops if the `homebrew` account exists.
The script also stops if the number 600 is in use.

## Part 5: Make the changes

> **Warning:** This step changes the owner of every file in `/opt/homebrew`.
> Do not stop the script while it runs.

1. Type this command and press Return:

   ```sh
   sudo ./scripts/setup.sh --apply
   ```

2. The script asks for a password for the new `homebrew` account.
   Type a new password and press Return.
3. Save this password in your password manager.
   You do not use it every day.
   You need it if you must change the account later.
4. Wait for the line `Done.`

![The script creates the homebrew account and changes the owner.](images/02-apply.gif)

> **Note:** You can see more lines than in the picture.
> Lines from `sysadminctl` about FDE or `IOServiceMatching` are not a problem.

## Part 6: Check the result

1. Type this command and press Return:

   ```sh
   ls -ld /opt/homebrew
   ```

   You see `homebrew` and `admin` in the third and fourth columns.
2. Type this command and press Return:

   ```sh
   ./scripts/verify.sh
   ```

   You see `PASS ownership` and `PASS brew --version`.

![The checks pass: homebrew owns the prefix.](images/03-verify.gif)

If you see `FAIL`, stop.
Go to [Rollback](#rollback).

## Part 7: Install the wrapper for your account

After the change, your account cannot write in `/opt/homebrew`.
The plain `brew install` command fails.
The wrapper sends your command to the `homebrew` account.
Homebrew asks for your password first.

First, put one copy of the wrapper where all users can read it.
Only an administrator can change this copy.

1. Type these commands. Press Return after each one:

   ```sh
   sudo mkdir -p /usr/local/share/homebrew-shared-mac
   sudo cp scripts/brew-wrapper.zsh /usr/local/share/homebrew-shared-mac/
   ```

2. Add the wrapper to your own `~/.zshrc` file:

   ```sh
   echo 'source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh' >> ~/.zshrc
   ```

3. Load the file in this Terminal window:

   ```sh
   source ~/.zshrc
   ```

4. Install a small test package:

   ```sh
   brew install hello
   ```

5. Type your password when `brew` asks for it.
   The first `brew` command can take one or two minutes.
   Homebrew updates itself first.
6. Run the test package:

   ```sh
   hello
   ```

   You see `Hello, world!`.

![Install the wrapper, then install and run the hello package.](images/04-wrapper.gif)

> **Note:** The tap warning that you can see on a real Mac is not in the picture.
> The test machine has extra taps that cause that warning.

## Part 8: Do the same for the second user

Do these steps as the second user.

1. Switch to the second user.
   In Terminal, type `su - <account-name>` and press Return.
   Type the password of that account.
   Or use the Fast User Switching menu and open Terminal.
2. Add the wrapper to this user's `~/.zshrc`:

   ```sh
   echo 'source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh' >> ~/.zshrc
   source ~/.zshrc
   ```

3. Show the installed packages:

   ```sh
   brew list
   ```

   You see the `hello` package that the first user installed.
   Both users share one Homebrew.
4. Install a package:

   ```sh
   brew install tree
   ```

5. Type the password of the second user when `brew` asks for it.

![The second user sees the same packages and installs a new one.](images/05-second-user.gif)

> **Note:** Only these commands run without a password:
> `--prefix`, `--cellar`, `--repository`, `--version`, `list`, `ls`, and `home`.
> All other `brew` commands ask for your password.

## Part 9: See what a wrong password does

A wrong password does not install anything.
This is the safety limit of this design.

1. Type this command and press Return:

   ```sh
   brew install cowsay
   ```

2. Type a wrong password three times.
3. Make sure that the package is not installed:

   ```sh
   brew list | grep cowsay || echo 'cowsay is not installed'
   ```

![Three wrong passwords stop the install.](images/06-wrong-password.gif)

## Rules for daily use

- Always use the `brew` command from the wrapper.
- Do not use `sudo brew`. It breaks the owner of the files.
- Close all Claude Code sessions before you upgrade the `claude-code` cask.
- Do not use `brew services`. It does not work with this design.

## Rollback

Use these steps to go back to the old state.

1. Give the prefix back to your account:

   ```sh
   sudo chown -R "$(whoami)" /opt/homebrew
   ```

2. Remove the line that has `brew-wrapper.zsh` from the `~/.zshrc` file of each user.
3. To delete the `homebrew` account, type this command:

   ```sh
   sudo sysadminctl -deleteUser homebrew
   ```
