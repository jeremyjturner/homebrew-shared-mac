# CLAUDE.md

Guidance for Claude Code in this repository. Read `HANDOFF.md` first for the current state.

## Purpose

One Homebrew install shared by several macOS users. The reader is probably not an IT expert. They found this repo because they hit `Error: /opt/homebrew is not writable` and want a step-by-step fix. Ease and accessibility come first. A wall of text scares people.

Tart, asciinema and the recordings are **test and maintainer tooling**. They are never part of what the user sees or does.

## Rules from the user

- Test every change in Tart before you run anything on this Mac. Never follow the guide's steps on the host.
- Ask before you change the host (installing or removing packages, global git config, and so on). Remove what you installed when it is no longer needed.
- Keep personal data out of the repo. Local hooks check every commit (`.git/hooks/pre-commit`, `commit-msg`, patterns in the untracked `.git/hooks/private-patterns`). They are not cloned, so recreate them on a new clone. Never use `--no-verify`. Never put the pattern list in a tracked file. Look at every frame of a GIF and every line of a `.cast` file before you commit.
- Make the repo public only when the user says it is ready.
- Do not commit the user's own files (for example the `.mp4` in the repo root).

## Project decisions

- **One script**: `scripts/setup.sh` checks, fixes, creates the owner account (the user chooses name and password) and writes a report file for the user's own AI agent. Do not add a second script for the user. `scripts/drift-check.sh` is maintainer tooling.
- User docs use short imperative sentences, about 80% ASD-STE100. One action per step. Copy-paste lines use the full repository URL. No Tart in user docs.
- `README.md` links to `docs/getting-started.md`. It should cover two paths: set up right first (new Mac), and already broken (existing users with the error). It should summarize and link <https://docs.brew.sh/Homebrew-for-Mac-Admins>.

## Testing

- Base image: `ghcr.io/cirruslabs/macos-tahoe-base:latest`. **Never** clone from the local `tahoe-base`. It is modified and carries old session state, so a clone looks like "a previous session".
- Regression test: `tests/tart-test.sh` (uses `setup.sh --yes --password-stdin --owner NAME`).
- `tart exec` without `-t` has no terminal, so `/dev/tty` reads fail. Test interactive prompts through a pty (`docs/demo/record.py` does this).
- The VM `admin` password is `admin`.

## Recording the clips

- `docs/demo/render.sh` makes a fresh VM and runs `docs/demo/record.py`. It uses asciinema and agg. Casts go to `docs/casts/`, GIFs to `docs/images/`. Speed is `SPEED` in `record.py`.
- A full render takes about 5 minutes. Render **one clip first**: `python3 docs/demo/record.py 04-setup` (the VM must be prepared). Check that GIF before you render all.
- Do not kill a render mid-run. The script's trap stops the VM, and you start over.
- If a trim or speed problem appears, fix it from the saved casts. Do not re-render everything.
- Wait on text in the output stream. Do not wait on screen pixels (VHS did, and it failed). Do not use a clock to find where to cut. Cut by content (the last `$ ` prompt). <!-- markdownlint-disable-line MD038 -->
- Clips that run in a nested shell (`su - bob`) need more than one `exit`.

## Shell gotchas on this Mac

- macOS `/bin/bash` is 3.2: no associative arrays, no `mapfile`, empty arrays break under `set -u`.
- zsh stops a `&&` chain when a glob matches nothing (for example `rm *.gif` with no files). Use `ls` or `find` to test first.
- Run long jobs with `run_in_background` and wait for the notification. Do not poll with `sleep`.
- Do not chain edits and a render in one command. If an early step fails, the later step can still run an old version.

## Before you finish a session

1. Run `bash -n` on scripts. Run shellcheck and markdownlint if they are available (CI runs them).
2. Update `HANDOFF.md` and, if the test results change, `docs/test-results.md`.
3. Commit with a clear message. The harness adds the attribution lines.
