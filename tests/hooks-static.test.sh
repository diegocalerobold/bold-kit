#!/usr/bin/env bash
# Static test of the two hook sources. Neither may contain a network word or
# the token variable name, comments included. One PASS or FAIL line per hook;
# exits non-zero if any check fails.

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cd "$root" || exit 1

failed=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failed=1; }

# Each forbidden word is a literal. "nc " keeps its trailing space.
WORDS=("curl" "wget" "/dev/tcp" "nc " "http" "BOLD_TOKEN")

for hook in .claude/hooks/ledger.sh .claude/hooks/anti-cheat.sh; do
  if [ ! -f "$hook" ]; then
    fail "$hook does not exist"
    continue
  fi
  found=""
  for word in "${WORDS[@]}"; do
    if grep -qF -e "$word" "$hook"; then
      found="$found [$word]"
    fi
  done
  if [ -z "$found" ]; then
    pass "$hook holds no network word and no token name"
  else
    fail "$hook contains:$found"
  fi
done

exit "$failed"
