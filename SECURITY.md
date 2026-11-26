# Security policy

## Report a vulnerability

Report vulnerabilities in private. Do not open a public issue.

1. Open the [Security tab](https://github.com/jeremyjturner/homebrew-shared-mac/security) of this repository.
2. Click "Report a vulnerability".
3. Describe the class of problem and the files it affects. Do not post a working exploit.

This is GitHub's private vulnerability reporting. Only the maintainer can read your report.

## What to expect

- The maintainer reads each report and answers within 7 days.
- If the report is valid, the maintainer works on a fix and tells you when it is merged.
- After the fix is merged, the maintainer publishes a security advisory. The advisory names you if you want that.
- Please give the maintainer 90 days to fix the problem before you disclose it in public.

## Supported versions

Only the latest commit on `main` is supported. The project has no numbered releases.

## What is in scope

- `scripts/setup.sh` and `scripts/brew-wrapper.zsh`. They run as root and change account and file ownership.
- The workflows in `.github/workflows/`.

Problems in Homebrew itself belong to the [Homebrew project](https://github.com/Homebrew/brew/security/policy).

## Before you run the scripts

This project changes account and file ownership on a system. Read the scripts first and test them in a VM.
