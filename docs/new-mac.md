# Set up a new Mac

This guide is for a Mac where Homebrew is not installed yet.
You install Homebrew once, then share it between users.
It takes about 15 minutes.

## What you need

- A Mac with Apple silicon (M1 or later).
- An administrator account. This is your first account.
- An internet connection.

## Part 1: Install Homebrew

Do these steps with your first account.

1. Open Terminal.
   Press Command + Space, type `Terminal`, and press Return.
2. Copy this line, paste it in Terminal, and press Return:

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. Type your password when it asks and press Return.
   No characters show on the screen. This is normal.
4. Press Return when the installer asks.
5. If a window asks you to install the command line developer tools, click **Install**.
   Wait until it finishes. The installer then continues.
6. Wait for the line `Installation successful!`.
   This can take several minutes.
7. Find the heading `Next steps` at the end of the text.
   Copy the lines under it that start with `echo` and `eval`, one at a time.
   Paste each line in Terminal and press Return.
8. Check the result:

   ```sh
   brew --version
   ```

   You see a line that starts with `Homebrew`.

> **Note:** Homebrew's own page shows the newest install steps.
> Read it here: <https://brew.sh>.

## Part 2: Add the second account

Skip this part if the second administrator account exists.

1. Open **System Settings**.
2. Click **Users & Groups**.
3. Click **Add Account**.
4. Set **New Account** to **Administrator**.
5. Type a name and a password. Click **Create User**.

## Part 3: Share Homebrew

Your first account now owns Homebrew.
This is the state that the setup script fixes.
Do this before anyone runs `sudo chown` on the Homebrew folder.

1. Open the [getting started guide](getting-started.md).
2. Start at Part 2 ("Get the files").
3. Follow the steps in order.
