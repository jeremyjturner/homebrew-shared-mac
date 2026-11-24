# Handoff

Private GitHub repo `homebrew-shared-mac`; CI (ShellCheck, markdownlint) passes. Not yet public.

## Done

- Tart tests (two rounds) passed: see `docs/test-results.md`.
- Scaffolding: README, LICENSE (MIT, copyright "homebrew-shared-mac contributors"), CONTRIBUTING, SECURITY, `scripts/` (setup, verify, brew-wrapper.zsh), `tests/tart-test.sh`, CI (ShellCheck, markdownlint), Dependabot, issue template.
- Wrapper read-only list was shortened to what tests showed works.
- Actions pinned to SHAs (checkout v7.0.1, markdownlint-cli2-action v25.1.0).
- shellcheck and markdownlint run clean inside the Tart VM (config in `.markdownlint-cli2.jsonc`).
- License confirmed: MIT.
- Host changes (user-approved): SSH signing key `~/.ssh/id_ed25519_signing`, global git signing config with the no-reply email, `gh` installed. Tart VM `hb-test` still exists (stopped).

## Not done / next

1. Done: `tests/tart-test.sh` and `setup.sh --apply` (plus `verify.sh`) run as real scripts in Tart; see round 3 in `docs/test-results.md`.
2. **Screenshots** of the Tart test for visual reference: run the VM with graphics (`tart run hb-test`), capture the key steps, put images in `docs/images/`, reference them from the README and docs.
3. Done: GitHub login, signing key uploaded, email privacy settings, repo created (private).
4. At the public flip (needs public repo or GitHub Pro): apply branch protection (signed commits required, no force-push/deletion, admins included).
5. Drift check: done. `scripts/drift-check.sh` compares raw upstream docs (Mac Admins, FAQ, Installation from Homebrew/brew) with `docs/upstream-snapshots/`; `.github/workflows/drift-check.yml` runs it weekly (Mondays) and opens or updates an `upstream-drift` issue. Refresh snapshots with `scripts/drift-check.sh --update` after review. Still open: scheduled Tart/latest-Homebrew re-test (needs a macOS runner). Verify the workflow once via `gh workflow run drift-check.yml`.
6. Not yet covered: macOS version matrix beyond 26.6.2, services alternative, brew.env path for HOMEBREW_* settings, uninstall section polish.

## Open items to pick up

- Dependabot PRs #1 and #2 are closed and their branches are gone.
- Git remote is SSH (`git@github.com:...`); the signing key is registered for both signing and authentication.
- Suggested next: screenshots (item 2); then item 6 coverage gaps.
- ssh-agent holds the signing key via keychain; if commits hang, re-run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519_signing` in a normal terminal.

## Rules from the user

- Use Tart for testing before making any change on this machine.
- Keep personal info out of the repo. Every commit is checked by local hooks (`.git/hooks/pre-commit`, `commit-msg`, patterns in the untracked `.git/hooks/private-patterns`). These hooks are not cloned: recreate them on any new clone. Do not use `--no-verify`.
- Make the repo public only when the user says it is ready.
