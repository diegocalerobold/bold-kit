#!/usr/bin/env bash
# Test of .claude/hooks/ledger.sh. One PASS or FAIL line per check; exits
# non-zero if any check fails. A missing tool fails, it never skips. All work
# happens in temp folders; the kit's own .bold/ is never touched.

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cd "$root" || exit 1

failed=0

for tool in grep jq mktemp cp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "FAIL 0 required tool missing: $tool"
    exit 1
  fi
done

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failed=1; }
detail() { echo "  $1"; }

HOOK="$root/.claude/hooks/ledger.sh"
FIXTURES="$here/fixtures"
TS_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/bold-ledger.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

if [ ! -f "$HOOK" ]; then
  fail "0 $HOOK does not exist"
  exit 1
fi

bad_exit=""
out=""

# run_hook <project-dir-or-UNSET> <stdin-file> [script]: runs the hook with the
# payload in the file on stdin; stdout and stderr land together in $out.
run_hook() {
  local dir=$1 input=$2 script=${3:-$HOOK} rc
  if [ "$dir" = UNSET ]; then
    out=$(env -u CLAUDE_PROJECT_DIR bash "$script" <"$input" 2>&1)
  else
    out=$(CLAUDE_PROJECT_DIR="$dir" bash "$script" <"$input" 2>&1)
  fi
  rc=$?
  [ "$rc" -eq 0 ] || bad_exit="$bad_exit $input($rc)"
  return 0
}

# line_count <file>: number of lines, 0 when the file is missing.
line_count() {
  if [ -f "$1" ]; then grep -c '' "$1"; else echo 0; fi
}

# blank_count <file>: number of empty or whitespace-only lines.
blank_count() {
  if [ -f "$1" ]; then grep -c '^[[:space:]]*$' "$1"; else echo 0; fi
}

# check_wrapped <ledger> <line-number> <input-file>: the line is the exact
# wrapper around the input without its newline, with a valid ts, valid JSON.
check_wrapped() {
  local ledger=$1 n=$2 input=$3 line payload rest ts tail
  line=$(sed -n "${n}p" "$ledger")
  payload=$(cat "$input")
  case $line in
    '{"ts":"'*) ;;
    *) echo "line does not start with {\"ts\":\""; return 1 ;;
  esac
  rest=${line#'{"ts":"'}
  ts=${rest%%\"*}
  tail=${rest#"$ts"}
  if ! [[ $ts =~ $TS_RE ]]; then echo "ts is not ISO 8601 UTC: $ts"; return 1; fi
  if [ "$tail" != '","payload":'"$payload"'}' ]; then echo "wrapper differs from the input"; return 1; fi
  if ! printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then echo "line is not valid JSON"; return 1; fi
  return 0
}

# ---- 1 and 2: both payload shapes, one wrapped line each -------------------
proj="$tmp/shapes"
mkdir -p "$proj"
ledger="$proj/.bold/ledger.jsonl"
[ ! -d "$proj/.bold" ] || fail "1 setup: .bold/ should not exist yet"

run_hook "$proj" "$FIXTURES/post-tool-use.json"
if [ -d "$proj/.bold" ]; then pass "1 .bold/ is created when missing"; else fail "1 .bold/ was not created"; fi
if [ "$(line_count "$ledger")" -eq 1 ] && why=$(check_wrapped "$ledger" 1 "$FIXTURES/post-tool-use.json"); then
  pass "2a PostToolUse payload gains exactly one wrapped line"
else
  fail "2a PostToolUse payload gains exactly one wrapped line"
  detail "lines: $(line_count "$ledger") ${why:-}"
fi
[ -z "$out" ] && pass "3a stdout and stderr are empty (PostToolUse)" || { fail "3a output on PostToolUse"; detail "$out"; }

run_hook "$proj" "$FIXTURES/post-tool-use-failure.json"
if [ "$(line_count "$ledger")" -eq 2 ] && why=$(check_wrapped "$ledger" 2 "$FIXTURES/post-tool-use-failure.json"); then
  pass "2b PostToolUseFailure payload gains exactly one wrapped line"
else
  fail "2b PostToolUseFailure payload gains exactly one wrapped line"
  detail "lines: $(line_count "$ledger") ${why:-}"
fi
[ -z "$out" ] && pass "3b stdout and stderr are empty (PostToolUseFailure)" || { fail "3b output on PostToolUseFailure"; detail "$out"; }

# ---- 4: a second run gives a second line, no blank line ---------------------
run_hook "$proj" "$FIXTURES/post-tool-use.json"
if [ "$(line_count "$ledger")" -eq 3 ] && check_wrapped "$ledger" 3 "$FIXTURES/post-tool-use.json" >/dev/null; then
  pass "4 a second run of the same payload gives a second line"
else
  fail "4 a second run of the same payload gives a second line"
fi
if [ "$(blank_count "$ledger")" -eq 0 ]; then pass "5 no blank line in the ledger"; else fail "5 blank line found in the ledger"; fi

# ---- 6: empty stdin adds nothing -------------------------------------------
: >"$tmp/empty.txt"
printf '\n' >"$tmp/newline.txt"
printf '  \n\n' >"$tmp/spaces.txt"
before=$(line_count "$ledger")
run_hook "$proj" "$tmp/empty.txt"
[ -z "$out" ] || fail "6 output on empty stdin"
run_hook "$proj" "$tmp/newline.txt"
run_hook "$proj" "$tmp/spaces.txt"
if [ "$(line_count "$ledger")" -eq "$before" ] && [ "$(blank_count "$ledger")" -eq 0 ]; then
  pass "6 empty stdin adds nothing"
else
  fail "6 empty stdin adds nothing"
fi

# ---- 7: a raw newline between tokens stays one line -------------------------
printf '{"hook_event_name":"PostToolUse",\n"tool_name":"mcp__bold__x"}\n' >"$tmp/multiline.txt"
before=$(line_count "$ledger")
run_hook "$proj" "$tmp/multiline.txt"
last=$(sed -n "$((before + 1))p" "$ledger")
expected_tail='","payload":{"hook_event_name":"PostToolUse", "tool_name":"mcp__bold__x"}}'
rest=${last#'{"ts":"'}
ts=${rest%%\"*}
if [ "$(line_count "$ledger")" -eq $((before + 1))  ] \
  && [ "${rest#"$ts"}" = "$expected_tail" ] \
  && printf '%s\n' "$last" | jq -e . >/dev/null 2>&1; then
  pass "7 a raw newline in the payload becomes a space and the record stays one line"
else
  fail "7 a raw newline in the payload becomes a space and the record stays one line"
  detail "$last"
fi

# ---- 8: root fallback two levels above the script ---------------------------
fb="$tmp/fallback"
mkdir -p "$fb/.claude/hooks"
cp "$HOOK" "$fb/.claude/hooks/ledger.sh"
fbl="$fb/.bold/ledger.jsonl"
run_hook UNSET "$FIXTURES/post-tool-use.json" "$fb/.claude/hooks/ledger.sh"
n1=$(line_count "$fbl")
run_hook "$tmp/not-a-directory" "$FIXTURES/post-tool-use-failure.json" "$fb/.claude/hooks/ledger.sh"
n2=$(line_count "$fbl")
if [ "$n1" -eq 1 ] && [ "$n2" -eq 2 ] && [ ! -e "$tmp/not-a-directory" ]; then
  pass "8 CLAUDE_PROJECT_DIR unset or not a directory falls back to the script's root"
else
  fail "8 root fallback (lines after unset: $n1, after non-directory: $n2)"
fi

# ---- 9: exit code 0 in every run --------------------------------------------
if [ -z "$bad_exit" ]; then pass "9 exit code 0 in every run"; else fail "9 non-zero exit:$bad_exit"; fi

exit "$failed"
