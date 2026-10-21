#!/usr/bin/env bash
# Revisa el CI de un pull request y imprime una sola palabra:
#   en_curso | exitoso | fallido | sin_ci | error
# Usa solo la API REST (`gh api`): GraphQL no está disponible en las rutinas en la nube.
# Uso: scripts/vigilar-ci.sh <numero-del-pr> [owner/repo]
set -u

pr="${1:?uso: vigilar-ci.sh <numero-del-pr> [owner/repo]}"
if [ -n "${2:-}" ]; then
  base="repos/$2"
else
  base='repos/{owner}/{repo}'
fi

sha=$(gh api "$base/pulls/$pr" --jq .head.sha 2>/dev/null) || { echo "error"; exit 1; }
[ -n "$sha" ] || { echo "error"; exit 1; }

# Checks (GitHub Actions y apps) y estados clásicos (CI externos), normalizados a pass | fail | pending.
runs=$(gh api "$base/commits/$sha/check-runs" --jq '
  [.check_runs[] |
    if .status != "completed" then "pending"
    elif (.conclusion == "success" or .conclusion == "neutral" or .conclusion == "skipped") then "pass"
    else "fail" end] | join(" ")' 2>/dev/null) || { echo "error"; exit 1; }
estados=$(gh api "$base/commits/$sha/status" --jq '
  [.statuses[].state |
    if . == "success" then "pass"
    elif . == "pending" then "pending"
    else "fail" end] | join(" ")' 2>/dev/null) || { echo "error"; exit 1; }

buckets="$runs $estados"

if [ -z "${buckets// /}" ]; then
  echo "sin_ci"
elif echo "$buckets" | grep -Eq '(^| )fail( |$)'; then
  echo "fallido"
elif echo "$buckets" | grep -Eq '(^| )pending( |$)'; then
  echo "en_curso"
else
  echo "exitoso"
fi
