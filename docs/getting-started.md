# Getting started

This guide shows you how to share one Homebrew installation between two users on one Mac.
It starts from a Mac where Homebrew is already installed.
Follow the steps in order.
Do not skip a step.

> **Warning:** This guide changes the owner of the Homebrew folder.
> Read each step before you do it.

## What you get

- One hidden account owns Homebrew. You choose its name. The script sets a random password for it.
- Each person uses their own account for daily work.
- Each person types their own password to install software.
- No person must change the owner of the Homebrew folder again.

## What you need

- A Mac with Apple silicon (M1 or later).
- Homebrew installed in `/opt/homebrew`.
- Two administrator accounts on the Mac. Two people can use them, or one person can use both.
- About 20 minutes.

## Words used in this guide

| Word | Meaning |
| --- | --- |
| Terminal | The app where you type commands. |
| Command | A line of text that you type in Terminal and send with the Return key. |
| Administrator | An account that is allowed to change the Mac. |
| Prefix | The folder where Homebrew keeps its files: `/opt/homebrew`. |
| Owner | The account that controls a folder. |
| Wrapper | A short text that sends your `brew` command to the owner account. |
| Report | A text file that the script writes. It shows the state of Homebrew on your Mac. |

## How to read the pictures

Each picture is an animation of the step.
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

![brew --version shows the version. ls -ld shows who owns /opt/homebrew.](images/01-start-state.gif)

## Part 2: Get the files

1. Close all `brew` commands that are running.
   Close all Claude Code sessions.
2. Check that Git is on your Mac:

   ```sh
   git --version
   ```

   You see a line that starts with `git version`.
   If a window asks you to install the command line developer tools, click **Install**.
   Wait until it finishes. Then type the command again.

   ![git --version shows the version of Git.](images/02-git.gif)

3. Go to your home folder:

   ```sh
   cd ~
   ```

4. Download the files:

   ```sh
   git clone https://github.com/jeremyjturner/homebrew-shared-mac.git
   ```

5. Go into the new folder:

   ```sh
   cd homebrew-shared-mac
   ```

## Part 3: Check Homebrew

The setup script is the only script that you need.
Run it first with `--check`.
In this mode, it only reads. It changes nothing.

1. Type this command and press Return:

   ```sh
   sudo ./scripts/setup.sh --check
   ```

2. Type your password and press Return.
3. Wait. The check can take one minute.
4. Read the result.

![The check shows what the script found and does not change anything.](images/03-check.gif)

The script looks at these things:

- The macOS version and the Homebrew version.
- How Homebrew was installed.
- Who owns the files in `/opt/homebrew`.
- Which accounts exist and which accounts use Homebrew.

You see text like this:

```text
Result
  - A person's account ('admin') owns /opt/homebrew. Other users get 'not writable' errors.
```

The script also writes a report file in your home folder.
Its name is `shared-brew-report-<date>.txt`.

> **Note:** The report shows the account names on your Mac.
> Read it before you give it to another person or to an AI agent.
> If something goes wrong, give this file to your AI agent. It shows the state of your Mac.

## Part 4: Fix Homebrew

> **Warning:** This step changes the owner of every file in `/opt/homebrew`.
> Do not stop the script while it runs.

1. Type this command and press Return:

   ```sh
   sudo ./scripts/setup.sh
   ```

2. Type your password and press Return.
3. The script asks for a name for the hidden account.
   Press Return to use `homebrew`, or type your own name.
4. Read the plan.
   Type `y` and press Return to continue.
5. The script asks if it can add the wrapper to your `~/.zshrc` file.
   Type `y` and press Return.
6. Wait for the lines that start with `PASS`.

The script sets a random password for the hidden account.
Nobody sees it and nobody can log in with it.
You do not need to save it.
If you ever need a new password for the account, an administrator can set one:
`sudo dscl . -passwd /Users/homebrew <new-password>`.

![The script creates the hidden account, changes the owner, and checks the result.](images/04-setup.gif)

If you see `FAIL`, stop.
Go to [Rollback](#rollback).

> **Note:** You can see more lines than in the picture.
> Lines from `sysadminctl` about FDE or `IOServiceMatching` are not a problem.

## Part 5: Test the wrapper

After the change, your account cannot write in `/opt/homebrew`.
The plain `brew install` command fails.
The wrapper sends your command to the hidden account.
Homebrew asks for your password first.

1. Close the Terminal window that you used for the setup.
   Open a new Terminal window.
   Only a new window loads the wrapper.
2. Check that the wrapper is loaded:

   ```sh
   type brew
   ```

   You see `brew is a shell function`.
   If you do not, type `source ~/.zshrc` and press Return.
3. Install a small test package:

   ```sh
   brew install hello
   ```

4. Type your password when `brew` asks for it.
   The first `brew` command can take one or two minutes.
   Homebrew updates itself first.
5. Run the test package:

   ```sh
   hello
   ```

   You see `Hello, world!`.

> **Warning:** Sometimes `brew` says that directories are "not writable".
> It then shows a `sudo chown` command.
> Do not run that command. It undoes the fix.
> It means that the window does not have the wrapper.
> Open a new Terminal window and try again.

![Install and run the hello package.](images/05-wrapper.gif)

## Part 6: Do the same for the second user

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

![The second user sees the same packages and installs a new one.](images/06-second-user.gif)

> **Note:** Only these commands run without a password:
> `--prefix`, `--cellar`, `--repository`, `--version`, `list`, `ls`, and `home`.
> All other `brew` commands ask for your password.

## Part 7: See what a wrong password does

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

![Three wrong passwords stop the install.](images/07-wrong-password.gif)

## Rules for daily use

- Always use the `brew` command from the wrapper.
- Do not use `sudo brew`. It breaks the owner of the files.
- Close all Claude Code sessions before you upgrade the `claude-code` cask.
- Do not use `brew services`. It does not work with this design.
- If the "not writable" error comes back, run `sudo ./scripts/setup.sh` again.
  The script finds the problem and fixes it.

## Rollback

Use these steps to go back to the old state.

1. Give the prefix back to your account:

   ```sh
   sudo chown -R "$(whoami)" /opt/homebrew
   ```

2. Remove the line that has `brew-wrapper.zsh` from the `~/.zshrc` file of each user.
3. To delete the hidden account, type this command.
   Use the name that you chose. The default name is `homebrew`.

   ```sh
   sudo sysadminctl -deleteUser homebrew
   ```
