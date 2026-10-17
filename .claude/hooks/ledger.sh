#!/usr/bin/env bash
# Ledger hook. Appends one line per game call to <root>/.bold/ledger.jsonl,
# wrapping the raw hook payload with a local timestamp:
#   {"ts":"2026-10-17T18:30:00Z","payload":<payload, unchanged>}
# The payload is never parsed or changed. No output, no network, always exit 0.

payload=$(cat) || exit 0

# Whitespace only means there is nothing to record.
case $payload in
  *[![:space:]]*) ;;
  *) exit 0 ;;
esac

# A raw newline cannot occur inside a JSON string, so a space keeps the record
# the same JSON value on a single line.
payload=${payload//$'\n'/ }

# Root: the project folder, or two levels above this script when it is not set.
root=$CLAUDE_PROJECT_DIR
if [ -z "$root" ] || [ ! -d "$root" ]; then
  src=${BASH_SOURCE[0]}
  case $src in
    */*) dir=${src%/*} ;;
    *) dir=. ;;
  esac
  root=$(cd "$dir/../.." 2>/dev/null && pwd) || exit 0
fi

mkdir -p "$root/.bold" 2>/dev/null || exit 0
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
printf '{"ts":"%s","payload":%s}\n' "$ts" "$payload" 2>/dev/null >>"$root/.bold/ledger.jsonl"
exit 0
