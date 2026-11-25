# Let your AI assistant do it

You can give the fix to an AI assistant that can run commands on your Mac.
For example: Claude Code, Codex or Gemini CLI.
The assistant reads this repository, checks your Mac, and asks you before it changes anything.
You type your own password when `sudo` asks.

> **Warning:** The fix changes who owns `/opt/homebrew`.
> Close all `brew` commands and AI sessions that use `brew` first.
> Read what the assistant plans to do before you say yes.

## What to do

1. Open Terminal.
2. Start your AI assistant in an empty folder, for example `~/Documents`.
3. Copy the prompt below.
4. Paste it into your assistant.
5. Read the plan that the assistant shows.
6. Say yes only if you agree with the plan.
7. Type your password when `sudo` asks for it.
8. Close the Terminal window and open a new one when the assistant tells you to.

## The prompt

````text
I share one Mac with other people. When we use Homebrew, we see
"Error: /opt/homebrew is not writable". Please fix it with the repository
https://github.com/jeremyjturner/homebrew-shared-mac

Follow these rules. They are strict.

1. Clone the repository: git clone https://github.com/jeremyjturner/homebrew-shared-mac.git
2. Read scripts/setup.sh, scripts/brew-wrapper.zsh and docs/getting-started.md before you run anything.
   Tell me in plain words what the script will change.
3. Use only scripts/setup.sh. Do not write your own commands to change owners,
   accounts, sudo rules or shell files.
4. Never run "sudo chown" on /opt/homebrew, even if brew shows it. Never run "sudo brew".
5. Run "sudo ./scripts/setup.sh --check" first. It changes nothing.
   Show me the "What I found" and "Result" parts in plain words.
6. If a fix is needed, ask me to choose the name of the hidden owner account.
   Never ask me to type a password into the chat. The script asks for passwords itself.
   If you cannot answer a script prompt, tell me to run the command myself.
   In some tools, I can type "! sudo ./scripts/setup.sh" in the prompt.
7. Show me the plan from the script. Wait for my yes before you make the changes.
8. After the script ends, tell me to close the Terminal window and open a new one.
   Then run "brew --version" and "brew update" with me, and tell me
   if any step fails.
9. Do not share or upload the report file. It lists the account names on this Mac.
   Read it for yourself only.
10. If anything fails or looks odd, stop. Show me the error. Tell me about
    "sudo ./scripts/setup.sh --rollback". Do not try other fixes by yourself.

Finally, tell me what changed, where the backups are, and how to undo it.
````

## What the assistant should not do

If your assistant does one of these, stop it:

- It runs `sudo chown` on `/opt/homebrew`.
- It runs `sudo brew`.
- It asks you to type a password in the chat.
- It changes the script to make it pass.
- It sends the report file to a website.

## Undo

```sh
sudo ./scripts/setup.sh --rollback
```

Run it from the folder that the assistant cloned.
