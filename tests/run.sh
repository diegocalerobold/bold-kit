#!/usr/bin/env bash
# Offline suite runner. `bash tests/run.sh` runs every test file in the fixed
# order; `bash tests/run.sh <name>` runs only tests/<name>.test.sh. Stops at the
# first failing file and exits non-zero. An empty suite is never green.

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cd "$root" || exit 1

ORDER="anti-cheat ledger hooks-static kit-structure"

run_one() {
  local file=$1
  if bash "$file"; then
    echo "PASS $file"
    return 0
  fi
  echo "FAIL $file"
  return 1
}

if [ "$#" -gt 1 ]; then
  echo "usage: bash tests/run.sh [name]" >&2
  exit 2
fi

if [ "$#" -eq 1 ]; then
  file="tests/$1.test.sh"
  if [ ! -f "$file" ]; then
    echo "FAIL no tests: $file does not exist" >&2
    exit 1
  fi
  run_one "$file" || exit 1
  exit 0
fi

ran=0
for name in $ORDER; do
  file="tests/$name.test.sh"
  [ -f "$file" ] || continue
  ran=$((ran + 1))
  run_one "$file" || exit 1
done

# Files outside the fixed order still run, after it, so none is silently skipped.
for file in tests/*.test.sh; do
  [ -f "$file" ] || continue
  known=0
  for name in $ORDER; do
    [ "$file" = "tests/$name.test.sh" ] && known=1
  done
  [ "$known" -eq 1 ] && continue
  ran=$((ran + 1))
  run_one "$file" || exit 1
done

if [ "$ran" -eq 0 ]; then
  echo "FAIL no tests: no tests/*.test.sh file found" >&2
  exit 1
fi
exit 0
