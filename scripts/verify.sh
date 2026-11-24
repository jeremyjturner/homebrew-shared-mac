#!/bin/bash
# Read-only checks. Run as any human user.
set -u
fail=0
bad=$(find /opt/homebrew ! -user homebrew 2>/dev/null | head -3)
if [[ -z $bad ]]; then echo "PASS ownership"; else echo "FAIL ownership:"; echo "$bad"; fail=1; fi
if /opt/homebrew/bin/brew --version >/dev/null 2>&1; then echo "PASS brew --version"; else echo "FAIL brew --version"; fail=1; fi
echo "Next (needs your sudo password): brew as-brew-user update"
exit $fail
