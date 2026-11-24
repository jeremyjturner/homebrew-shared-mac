#!/bin/bash
# Compare upstream Homebrew docs with stored snapshots.
# Usage: scripts/drift-check.sh            diff only; exit 1 on drift, 2 on fetch error
#        scripts/drift-check.sh --update   refresh snapshots (review the diff, then commit)
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
SNAP="$HERE/docs/upstream-snapshots"
BASE=https://raw.githubusercontent.com/Homebrew/brew/HEAD/docs
PAGES=(Homebrew-for-Mac-Admins FAQ Installation)
UPDATE=0
[[ ${1:-} == --update ]] && UPDATE=1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$SNAP"
drift=0

for page in "${PAGES[@]}"; do
  if ! curl -fsSL --retry 3 --retry-delay 5 -o "$tmp/$page.raw" "$BASE/$page.md"; then
    echo "ERROR: could not fetch $BASE/$page.md" >&2; exit 2
  fi
  # last_review_date changes on every upstream review without content changes.
  grep -v '^last_review_date:' "$tmp/$page.raw" > "$tmp/$page.snapshot"
  snap="$SNAP/$page.snapshot"
  if (( UPDATE )); then
    cp "$tmp/$page.snapshot" "$snap"; echo "updated $page"
  elif [[ ! -f $snap ]]; then
    echo "ERROR: no snapshot for $page; run with --update" >&2; exit 2
  elif ! diff -u --label "snapshot/$page" --label "upstream/$page" "$snap" "$tmp/$page.snapshot"; then
    drift=1
  fi
done

(( UPDATE )) && exit 0
if (( drift )); then echo "DRIFT detected" >&2; exit 1; fi
echo "No drift."
