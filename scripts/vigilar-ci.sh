#!/usr/bin/env bash
# Revisa el CI de un pull request y imprime una sola palabra:
#   en_curso | exitoso | fallido | sin_ci
# Uso: scripts/vigilar-ci.sh <numero-o-url-del-pr> [owner/repo]
set -u

pr="${1:?uso: vigilar-ci.sh <numero-o-url-del-pr> [owner/repo]}"
[ -n "${2:-}" ] && export GH_REPO="$2"

# `gh pr checks` sale con código distinto de 0 si hay checks fallidos o pendientes;
# por eso se ignora el código y se juzga por el contenido.
buckets=$(gh pr checks "$pr" --json bucket --jq '[.[].bucket] | join(" ")' 2>/dev/null)

if [ -z "$buckets" ]; then
  echo "sin_ci"
elif echo "$buckets" | grep -Eq '(^| )(fail|cancel)( |$)'; then
  echo "fallido"
elif echo "$buckets" | grep -Eq '(^| )pending( |$)'; then
  echo "en_curso"
else
  echo "exitoso"
fi
