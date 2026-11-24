# Handoff

Folder: `homebrew-shared-mac` (matches the planned GitHub repo name). Not yet a git repo.

## Done

- Tart tests (two rounds) passed: see `docs/test-results.md`.
- Scaffolding: README, LICENSE (MIT, copyright "homebrew-shared-mac contributors"), CONTRIBUTING, SECURITY, `scripts/` (setup, verify, brew-wrapper.zsh), `tests/tart-test.sh`, CI (ShellCheck, markdownlint), Dependabot, issue template.
- Wrapper read-only list was shortened to what tests showed works.
- shellcheck and markdownlint run clean inside the Tart VM (config in `.markdownlint-cli2.jsonc`).
- License confirmed: MIT.
- Host changes (user-approved): SSH signing key `~/.ssh/id_ed25519_signing`, global git signing config with the no-reply email, `gh` installed. Tart VM `hb-test` still exists (stopped).

## Not done / next

1. `tests/tart-test.sh` and `setup.sh --apply` have not been executed as scripts; the commands were tested by hand.
2. **Screenshots** of the Tart test for visual reference: run the VM with graphics (`tart run hb-test`), capture the key steps, put images in `docs/images/`, reference them from the README and docs.
3. GitHub (user to do): `gh auth login`; upload the signing public key as a *signing* key; enable "Keep my email addresses private" and "Block command line pushes that expose my email". Git `user.name` is not set yet.
4. Create repo `homebrew-shared-mac`, branch protection requiring signed commits, pin Actions to SHAs.
5. Drift-check workflow: scheduled Action that fetches <https://docs.brew.sh/Homebrew-for-Mac-Admins> plus FAQ/Installation pages, diffs against a stored snapshot, opens an issue on change; also scheduled Tart/latest-Homebrew re-test (needs a macOS runner).
6. Not yet covered: macOS version matrix beyond 26.6.2, services alternative, brew.env path for HOMEBREW_* settings, uninstall section polish.

## Rules from the user

- Use Tart for testing before making any change on this machine.
- Keep personal info out of the repo.
