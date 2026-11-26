# Getting started

This guide shows you how to share one Homebrew installation between the people who use one Mac.
It works for a new Mac and for a Mac that already shows the "not writable" error.
Follow the steps in order.
Do not skip a step.
Prefer that an AI assistant does it for you? Use the [AI assistant guide](llm-prompt.md) instead.

> **Warning:** This guide changes the owner of the Homebrew folder.
> Read each step before you do it.

## What you get

- One hidden account owns Homebrew. You choose its name. The script sets a random password for it.
- Each person uses their own account for daily work.
- Each person types their own password to install software.
- No person must change the owner of the Homebrew folder again.

## What you need

- A Mac with Apple silicon (M1 or later).
- One administrator account. This is your own account.
- An internet connection.
- About 20 minutes.

You do not need a second account now.
The script creates the hidden owner account.
Add the account of another person at any time (see Part 6).

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
   If you see `command not found`, Homebrew is not installed.
   Install it first. See [Install Homebrew](#install-homebrew-new-mac-only).
3. Type this command and press Return:

   ```sh
   ls -ld /opt/homebrew
   ```

   You see your user name in the third column.
   This is the problem state. Your account owns the prefix.

![brew --version shows the version. ls -ld shows who owns /opt/homebrew.](images/01-start-state.gif)

[Watch this clip with pause and copy](https://asciinema.org/a/cuTxKvYQrP1mUc4J)

### Install Homebrew (new Mac only)

Skip this section if `brew --version` worked.
Do these steps with your own account.

1. Copy this line, paste it in Terminal, and press Return:

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Type your password when it asks and press Return.
   No characters show on the screen. This is normal.
3. Press Return when the installer asks.
4. If a window asks you to install the command line developer tools, click **Install**.
   Wait until it finishes. The installer then continues.
5. Wait for the line `Installation successful!`.
   This can take several minutes.
6. Find the heading `Next steps` at the end of the text.
   Copy the lines under it that start with `echo` and `eval`, one at a time.
   Paste each line in Terminal and press Return.
7. Check the result:

   ```sh
   brew --version
   ```

   You see a line that starts with `Homebrew`.

Your account now owns Homebrew.
This is the state that the script fixes.
Do not run `sudo chown` on the Homebrew folder. Go on to Part 2.

> **Note:** Homebrew's own page shows the newest install steps: <https://brew.sh>.

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

   ![Steps 2 to 5: check Git, go to the home folder, download the files, go into the new folder.](images/02-get-files.gif)

   [Watch this clip with pause and copy](https://asciinema.org/a/qp9CmFCo9DBxyHxI)

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

[Watch this clip with pause and copy](https://asciinema.org/a/7yCWcC8XCpU8ACBk)

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
5. macOS can show this window: "Terminal would like to administer your computer."
   Click **Allow**.
   The script needs it to create the hidden account.
6. Wait for the lines that start with `PASS`.

The script also does these steps for you, and the plan lists them:

- It adds the wrapper to the `~/.zshrc` file of each account that uses Homebrew.
- It turns off a `HOMEBREW_CASK_OPTS="--appdir=..."` line.
  Homebrew now ignores that line, because the hidden account installs apps.
- It moves the apps that Homebrew put in a `~/Applications` folder.
  Homebrew installs them again in `/Applications`.
  The old copies stay in the backup folder.
  The script stops and tells you if one of these apps is open.
  It also tells you which account has the app open.
  Quit the app in that account and run the script again.

After the script moves an app, its icon in the Dock can show a question mark.
The Dock still points to the old place.
Fix it in each account that had the app in the Dock:

1. Drag the icon with the question mark out of the Dock.
2. Open the app from the `/Applications` folder.
3. Right-click the app icon in the Dock.
4. Choose **Options**, then **Keep in Dock**.

The script saves every change in `/usr/local/share/homebrew-shared-mac/backups`.
To undo all of it, go to [Rollback](#rollback).

The script sets a random password for the hidden account.
Nobody sees it and nobody can log in with it.
You do not need to save it.
If you ever need a new password for the account, an administrator can set one:
`sudo dscl . -passwd /Users/homebrew <new-password>`.

![The script creates the hidden account, changes the owner, and checks the result.](images/04-setup.gif)

[Watch this clip with pause and copy](https://asciinema.org/a/KZPjfhk9FZ7zwfBD)

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

> **Warning:** Sometimes `brew` says that a directory is "not writable".
> For example: `/opt/homebrew/Cellar is not writable`.
> It then shows a `sudo chown` command.
> Do not run that command. It undoes the fix.
> It means that the window does not have the wrapper.
> Open a new Terminal window and try again.

![Install and run the hello package.](images/05-wrapper.gif)

[Watch this clip with pause and copy](https://asciinema.org/a/zk3HDtHI7GUKHcPZ)

## Part 6: Add and check another user (optional)

Skip this part if you are the only person on this Mac.
You can come back to it when another person needs Homebrew.

If the account of the other person exists, the script already added the wrapper to its `~/.zshrc`.
If the account does not exist yet, add it first:

1. Open **System Settings**.
2. Click **Users & Groups**.
3. Click **Add Account**.
4. Set **New Account** to **Administrator**.
5. Type a name and a password. Click **Create User**.

Do these steps as the other user.

1. Switch to the other user.
   In Terminal, type `su - <account-name>` and press Return.
   Type the password of that account.
   Or use the Fast User Switching menu and open Terminal.
2. Open a new Terminal window and check that the wrapper is loaded:

   ```sh
   type brew
   ```

   You see `brew is a shell function`.
   If you do not, this user did not use Homebrew before.
   Add the wrapper, then open a new Terminal window:

   ```sh
   echo 'source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh' >> ~/.zshrc
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

[Watch this clip with pause and copy](https://asciinema.org/a/EvoxKJIRGuCRPTkt)

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

[Watch this clip with pause and copy](https://asciinema.org/a/dTf6BluHA2MX9g2T)

## Update everything with one command

Homebrew asks for your password at every `brew` command.
Four commands for a full update mean four passwords.
Use one command instead:

```sh
brew update-all
```

![One password. The four steps run one after the other.](images/08-update-all.gif)

[Watch this clip with pause and copy](https://asciinema.org/a/D6cg5alR39xlBc6H)

It runs these steps in order:

1. `brew update` gets the list of new versions.
2. `brew upgrade` upgrades packages and apps.
3. `brew autoremove` removes packages that nothing needs.
4. `brew cleanup` removes old files.

It asks for your password one time.
Homebrew shows the list of upgrades and asks: `Do you want to proceed with the upgrade? [y/n]`.
Type `y` and press Return.
To skip that question, type `brew update-all --yes` (or `-y`).
The command stops at the first step that fails.

> **Note:** `update-all` is part of the wrapper. It is not a Homebrew command.
> It works only in a new Terminal window after the setup.
> An older wrapper does not have it. Run `sudo ./scripts/setup.sh` again to get the new one.

## Rules for daily use

- Always use the `brew` command from the wrapper.
- Do not use `sudo brew`. It breaks the owner of the files.
- Close all Claude Code sessions before you upgrade the `claude-code` cask.
- Do not use `brew services`. It does not work with this design.
- If the "not writable" error comes back, run `sudo ./scripts/setup.sh` again.
  The script finds the problem and fixes it.

## Rollback

### Rollback with the script

The script saves a backup of every change.
This command undoes the last run:

```sh
sudo ./scripts/setup.sh --rollback
```

It does these things, from the last change to the first:

- It puts the moved apps back in `~/Applications`.
- It turns the `HOMEBREW_CASK_OPTS` line back on.
- It removes the wrapper lines it added.
- It gives `/opt/homebrew` back to the account that owned it.
- It deletes the hidden account, if the script made it.

A Dock icon of a moved app shows a question mark again.
Drag it out of the Dock and add the app again from `~/Applications`.

Homebrew does not manage the apps that go back to `~/Applications`.
Install them again with `brew install --cask --appdir=~/Applications NAME`
if you want Homebrew to manage them.

### Rollback by hand

Use these steps if the script does not run.

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

4. Remove the wrapper files:

   ```sh
   sudo rm -r /usr/local/share/homebrew-shared-mac
   ```

After these steps, Homebrew works as before for your account only.
A second user must use `sudo` or ask you, as in any normal Homebrew install.
