# Contributing

- Test every change in a Tart VM (`tests/tart-test.sh`) before touching a real machine.
- Run `shellcheck` on scripts and `markdownlint` on docs.
- Keep personal data (usernames, emails, hostnames) out of commits and test output.
- Sign your commits. Open an issue first for larger changes.
- CI also runs gitleaks, zizmor, CodeQL and Scorecard. Fix what they report before you merge.
