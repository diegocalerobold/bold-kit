#!/usr/bin/env bash
# Test of .claude/hooks/result.sh. One PASS or FAIL line per check; exits
# non-zero if any check fails. A missing tool fails, it never skips. All work
# happens in temp folders; the kit's own .bold/ is never touched. jq is used
# here to decode the hook output; the hook itself never uses it.

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cd "$root" || exit 1

failed=0

for tool in grep jq mktemp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "FAIL 0 required tool missing: $tool"
    exit 1
  fi
done

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failed=1; }
detail() { echo "  $1"; }

HOOK="$root/.claude/hooks/result.sh"
FIXTURES="$here/fixtures"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/bold-result.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

if [ ! -f "$HOOK" ]; then
  fail "0 $HOOK does not exist"
  exit 1
fi

bad_exit=""
out=""
err=""
proj=""
n=0

# run_hook <stdin-file>: runs the hook in a fresh project folder ($proj) with
# the file on stdin; stdout lands in $out, stderr in $err.
run_hook() {
  local input=$1 rc
  n=$((n + 1))
  proj="$tmp/p$n"
  mkdir -p "$proj"
  out=$(CLAUDE_PROJECT_DIR="$proj" bash "$HOOK" <"$input" 2>"$tmp/err.txt")
  rc=$?
  err=$(cat "$tmp/err.txt")
  [ "$rc" -eq 0 ] || bad_exit="$bad_exit $input($rc)"
  return 0
}

# message: the decoded systemMessage of the last run; empty when it does not parse.
message() { printf '%s\n' "$out" | jq -er '.systemMessage' 2>/dev/null; }

# check <label> <expected>: stdout is one JSON line whose message equals expected.
check_message() {
  local label=$1 expected=$2 got lines
  got=$(message)
  lines=$(printf '%s\n' "$out" | grep -c '')
  if [ "$got" = "$expected" ] && [ "$lines" -eq 1 ] && [ -z "$err" ]; then
    pass "$label"
  else
    fail "$label"
    detail "got: $out"
    [ -z "$err" ] || detail "stderr: $err"
  fi
}

# check_silent <label>: no stdout, no stderr, no file under .bold/.
check_silent() {
  local label=$1
  if [ -z "$out" ] && [ -z "$err" ] && [ ! -e "$proj/.bold/puntos.txt" ] && [ ! -e "$proj/.bold/enlace.txt" ]; then
    pass "$label"
  else
    fail "$label"
    detail "stdout: $out"
  fi
}

LINK=https://example.test/p/fixtureparticipant01

# ---- 1: checkin: line plus link, the email stays out -------------------------
run_hook "$FIXTURES/result-checkin.json"
expected=$'+50 puntos | Total: 50 | Campamento: Base\nEste es tu enlace personal: '"$LINK"'. Es tu llave; no lo compartas. (Guardado en .bold/enlace.txt)'
check_message "1a checkin prints the result line and the personal link" "$expected"
if [ "$(cat "$proj/.bold/enlace.txt" 2>/dev/null)" = "$LINK" ] && [ "$(grep -c '' "$proj/.bold/enlace.txt")" -eq 1 ]; then
  pass "1b enlace.txt holds exactly the link"
else
  fail "1b enlace.txt holds exactly the link"
fi
if [ "$(cat "$proj/.bold/puntos.txt" 2>/dev/null)" = '+50 puntos | Total: 50 | Campamento: Base' ]; then
  pass "1c puntos.txt holds the result line"
else
  fail "1c puntos.txt holds the result line"
fi
leak=""
for needle in 'm2-x@example.test' 'm2-x'; do
  if printf '%s\n' "$out" | grep -qF -e "$needle" \
    || grep -qF -e "$needle" "$proj/.bold/puntos.txt" "$proj/.bold/enlace.txt" 2>/dev/null; then
    leak="$leak [$needle]"
  fi
done
if [ -z "$leak" ]; then pass "1d the email appears in none of stdout, puntos.txt, enlace.txt"; else fail "1d email leaked:$leak"; fi

# ---- 2 to 4: other tools -----------------------------------------------------
run_hook "$FIXTURES/result-complete-task.json"
check_message "2 complete_task at camp 3 prints the single line" '+53 puntos | Total: 325 | Campamento: Construcción'
if [ "$(cat "$proj/.bold/puntos.txt" 2>/dev/null)" = '+53 puntos | Total: 325 | Campamento: Construcción' ] && [ ! -e "$proj/.bold/enlace.txt" ]; then
  pass "2b puntos.txt gets the line, enlace.txt is not written"
else
  fail "2b puntos.txt gets the line, enlace.txt is not written"
fi

run_hook "$FIXTURES/result-complete-task-camp4.json"
check_message "3 complete_task at camp 4 adds the publish sentence" $'+60 puntos | Total: 410 | Campamento: Verificación\nCompletaste todas las tareas. Falta publicar tu resultado.'
if [ "$(cat "$proj/.bold/puntos.txt" 2>/dev/null)" = '+60 puntos | Total: 410 | Campamento: Verificación' ]; then
  pass "3b puntos.txt holds only the result line"
else
  fail "3b puntos.txt holds only the result line"
fi

run_hook "$FIXTURES/result-report-flag.json"
check_message "4 report_flag keeps the negative sign" '-25 puntos | Total: 100 | Campamento: Plan'

# ---- 5 to 9: nothing to show -------------------------------------------------
run_hook "$FIXTURES/result-my-progress.json"
check_silent "5 my_progress prints nothing and writes nothing"

run_hook "$FIXTURES/result-missing-total.json"
check_silent "6 a missing total prints nothing and writes nothing"

run_hook "$FIXTURES/result-rejected.json"
check_silent "7 a rejected verdict prints nothing and writes nothing"

run_hook "$FIXTURES/result-game-over.json"
check_silent "7b a game_over rejection (delta 0) prints nothing and writes nothing"

run_hook "$FIXTURES/result-link-bad.json"
check_message "8a a link with a disallowed character gives no link line" '+50 puntos | Total: 50 | Campamento: Base'
[ ! -e "$proj/.bold/enlace.txt" ] && pass "8b no enlace.txt for a disallowed link" || fail "8b enlace.txt was written for a disallowed link"

# ---- 9: the link capture stops at the escaped quote -------------------------
run_hook "$FIXTURES/result-link-quote.json"
check_message "9a the link capture stops at the escaped quote" $'+50 puntos | Total: 50 | Campamento: Base\nEste es tu enlace personal: '"$LINK"'. Es tu llave; no lo compartas. (Guardado en .bold/enlace.txt)'
if [ "$(cat "$proj/.bold/enlace.txt" 2>/dev/null)" = "$LINK" ]; then pass "9b enlace.txt stops at the quote"; else fail "9b enlace.txt stops at the quote"; fi

# ---- 10: malformed input -----------------------------------------------------
: >"$tmp/empty.txt"
printf '  \n\n' >"$tmp/spaces.txt"
printf 'not json at all {{{' >"$tmp/garbage.txt"
printf '{"tool_name":"mcp__bold__complete_task","tool_response":"{\\"verdict\\":\\"accepted\\",\\"points_earned\\":5' >"$tmp/truncated.txt"
printf '{"tool_name":"Bash","tool_response":"{\\"verdict\\":\\"accepted\\",\\"points_earned\\":5,\\"total\\":5,\\"camp\\":1}"}\n' >"$tmp/other-tool.txt"
printf '{"tool_name":"mcp__bold__complete_task","tool_response":"{\\"verdict\\":\\"accepted\\",\\"points_earned\\":5,\\"total\\":5,\\"camp\\":9}"}\n' >"$tmp/bad-camp.txt"
printf '{"tool_name":"mcp__bold__complete_task","tool_response":"{\\"verdict\\":\\"accepted\\",\\"points_earned\\":5.5,\\"total\\":5,\\"camp\\":1}"}\n' >"$tmp/bad-int.txt"
for f in empty spaces garbage truncated other-tool bad-camp bad-int; do
  run_hook "$tmp/$f.txt"
  check_silent "10 $f input prints nothing and writes nothing"
done

# ---- 11: the unescaped response shape ----------------------------------------
run_hook "$FIXTURES/result-unescaped.json"
check_message "11 an unescaped tool_response gives the same line" '+53 puntos | Total: 325 | Campamento: Construcción'

# ---- 12: the message round trips through JSON --------------------------------
run_hook "$FIXTURES/result-checkin.json"
if printf '%s\n' "$out" | grep -qF -e '\n' && [ "$(message | grep -c '')" -eq 2 ] \
  && [ "$(printf '%s\n' "$out" | jq -c 'keys')" = '["systemMessage"]' ]; then
  pass "12 the lines are joined by an escaped newline in a one-key JSON object"
else
  fail "12 the lines are joined by an escaped newline in a one-key JSON object"
  detail "$out"
fi

# ---- 13: all six camp names ---------------------------------------------------
NAMES=(Base Entrevista Plan Construcción Verificación Cumbre)
for camp in 0 1 2 3 4 5; do
  printf '{"tool_name":"mcp__bold__report_question","tool_response":"{\\"verdict\\":\\"accepted\\",\\"points_earned\\":0,\\"total\\":7,\\"camp\\":%s}"}\n' "$camp" >"$tmp/camp.txt"
  run_hook "$tmp/camp.txt"
  check_message "13 camp $camp is ${NAMES[$camp]}" "+0 puntos | Total: 7 | Campamento: ${NAMES[$camp]}"
done

# ---- 14: root fallback two levels above the script ---------------------------
fb="$tmp/fallback"
mkdir -p "$fb/.claude/hooks"
cp "$HOOK" "$fb/.claude/hooks/result.sh"
env -u CLAUDE_PROJECT_DIR bash "$fb/.claude/hooks/result.sh" <"$FIXTURES/result-complete-task.json" >/dev/null 2>&1 || bad_exit="$bad_exit fallback"
if [ "$(cat "$fb/.bold/puntos.txt" 2>/dev/null)" = '+53 puntos | Total: 325 | Campamento: Construcción' ]; then
  pass "14 an unset CLAUDE_PROJECT_DIR falls back to the script's root"
else
  fail "14 an unset CLAUDE_PROJECT_DIR falls back to the script's root"
fi

# ---- 15: two runs append two lines -------------------------------------------
CLAUDE_PROJECT_DIR="$proj" bash "$HOOK" <"$FIXTURES/result-complete-task.json" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$proj" bash "$HOOK" <"$FIXTURES/result-complete-task.json" >/dev/null 2>&1
if [ "$(grep -c '' "$proj/.bold/puntos.txt")" -eq 3 ]; then pass "15 puntos.txt appends one line per run"; else fail "15 puntos.txt appends one line per run"; fi

# ---- 16: exit code 0 in every run --------------------------------------------
if [ -z "$bad_exit" ]; then pass "16 exit code 0 in every run"; else fail "16 non-zero exit:$bad_exit"; fi

exit "$failed"
