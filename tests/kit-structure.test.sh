#!/usr/bin/env bash
# Structural test of the kit (checks 1 to 8). One PASS or FAIL line per check;
# exits non-zero if any check fails. A missing tool fails, it never skips.
# Check 4 and 6b scan everything outside tests/, because this file names the
# patterns it looks for.

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cd "$root" || exit 1

failed=0

for tool in grep sed awk git jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "FAIL 0 required tool missing: $tool"
    exit 1
  fi
done

pass() { echo "PASS $1 $2"; }
fail() { echo "FAIL $1 $2"; failed=1; }
detail() { echo "  $1"; }

# has_line <file> <literal>: the literal text appears in the file.
has_line() { [ -f "$1" ] && grep -qF -e "$2" "$1"; }

# layout_ok <file>: 2-space indentation steps, no tabs, at most one key per line.
layout_ok() {
  [ -f "$1" ] || return 1
  if grep -q "$(printf '\t')" "$1"; then return 1; fi
  if grep -vE '^( {2})*[^ ]' "$1" | grep -q .; then return 1; fi
  if grep -E '"[^"]+":.*"[^"]+":' "$1" | grep -q .; then return 1; fi
  return 0
}

# token_scan: reads text on stdin, prints each line that looks like a token.
token_scan() {
  awk '
    {
      line = $0
      gsub(/Bearer \$\{BOLD_TOKEN\}/, "", line)
      if (line ~ /Bearer/) { print $0; next }
      if (line ~ /BOLD_TOKEN"?[ \t]*[:=][ \t]*"?[^<$" \t]/) print $0
    }
  '
}

# ---- 1: .mcp.json ---------------------------------------------------------
c1=ok
if [ ! -f .mcp.json ]; then
  c1=".mcp.json does not exist"
elif ! layout_ok .mcp.json; then
  c1=".mcp.json layout is not 2-space, one key per line"
elif ! jq -e '(.mcpServers | keys) == ["bold"]' .mcp.json >/dev/null 2>&1; then
  c1="mcpServers must hold exactly one key, bold"
elif ! has_line .mcp.json '"Authorization": "Bearer ${BOLD_TOKEN}"'; then
  c1="Authorization header line is missing"
elif ! has_line .mcp.json 'https://server-dqzrurq6pa-ue.a.run.app/mcp'; then
  c1="endpoint URL is missing"
fi
if [ "$c1" = ok ]; then pass 1 ".mcp.json declares only bold with the token placeholder"; else fail 1 ".mcp.json: $c1"; fi

# ---- 2: .claude/settings.json --------------------------------------------
s=.claude/settings.json
c2=ok
if [ ! -f "$s" ]; then
  c2="$s does not exist"
elif ! layout_ok "$s"; then
  c2="$s layout is not 2-space, one key per line"
elif ! jq -e '(.hooks | keys) == ["PostToolUse","PostToolUseFailure","UserPromptSubmit"]' "$s" >/dev/null 2>&1; then
  c2="hook events must be exactly PostToolUse, PostToolUseFailure, UserPromptSubmit"
elif ! jq -e '.permissions.allow == ["mcp__bold__*"]' "$s" >/dev/null 2>&1; then
  c2="permissions.allow must hold exactly mcp__bold__*"
elif ! jq -e 'has("env") | not' "$s" >/dev/null 2>&1; then
  c2="env key is not allowed"
elif ! jq -e '[.. | objects | select(has("command")) | .command] | unique
    == ["bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/anti-cheat.sh\"","bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/ledger.sh\""]' "$s" >/dev/null 2>&1; then
  c2="command strings must be exactly the two script calls"
fi
if [ "$c2" = ok ]; then pass 2 "settings.json holds the three registrations and the single allow rule"; else fail 2 "settings.json: $c2"; fi

# ---- 3: ignore rules and line endings -------------------------------------
if has_line .gitignore '**/.claude/settings.local.json' \
  && has_line .gitignore '.bold/' \
  && has_line .gitattributes '*.sh text eol=lf'; then
  pass 3 ".gitignore and .gitattributes carry the required rules"
else
  fail 3 ".gitignore or .gitattributes lacks a required rule"
fi

# ---- 4: no token-like value in the tree or in history --------------------
hits=$(grep -rIh --exclude-dir=.git --exclude-dir=tests -e 'Bearer' -e 'BOLD_TOKEN' . 2>/dev/null | token_scan)
hist=$(git log -p --all -- . ':(exclude)tests' 2>/dev/null | grep -e '^+' | token_scan)
if [ -z "$hits" ] && [ -z "$hist" ]; then
  pass 4 "no token-like value in the working tree or in history"
else
  fail 4 "token-like value found"
  [ -n "$hits" ] && detail "working tree: $hits"
  [ -n "$hist" ] && detail "history: $hist"
fi

# ---- 5: no remote ---------------------------------------------------------
remotes=$(git remote 2>&1)
if [ -z "$remotes" ]; then pass 5 "git remote prints nothing"; else fail 5 "git remote lists: $remotes"; fi

# ---- 6a: the file tree ----------------------------------------------------
EXPECTED="CLAUDE.md README.md .gitignore .gitattributes .mcp.json
.claude/settings.json
.claude/hooks/ledger.sh .claude/hooks/anti-cheat.sh
.claude/skills/reto/SKILL.md .claude/skills/mi-progreso/SKILL.md
.claude/skills/game-guide/SKILL.md .claude/skills/publicar/SKILL.md
.claude/skills/entrevista/SKILL.md .claude/skills/planificar/SKILL.md
.claude/agents/verifier.md
tests/run.sh tests/anti-cheat.test.sh tests/ledger.test.sh
tests/hooks-static.test.sh tests/kit-structure.test.sh"
missing=""
for f in $EXPECTED; do
  [ -f "$f" ] || missing="$missing $f"
done
extra=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in tests/fixtures/*) continue ;; esac
  known=0
  for e in $EXPECTED; do
    [ "$f" = "$e" ] && known=1
  done
  [ "$known" -eq 1 ] || extra="$extra $f"
done <<EOF
$(git ls-files --cached --others --exclude-standard)
EOF
if [ -z "$missing" ] && [ -z "$extra" ]; then
  pass 6a "the tree holds exactly the listed files"
else
  fail 6a "tree differs from kit-files.md"
  [ -n "$missing" ] && detail "missing:$missing"
  [ -n "$extra" ] && detail "unexpected:$extra"
fi

# ---- 6b: no admin tool names or infrastructure words ----------------------
leak=$(grep -rIiE --exclude-dir=.git --exclude-dir=tests --exclude-dir=.bold \
  'ranking|recent_events|stuck|publish_narration|adjust_points|terraform|firestore' . 2>/dev/null)
if [ -z "$leak" ]; then
  pass 6b "no admin tool name or infrastructure word outside tests/"
else
  fail 6b "forbidden word found"
  detail "$leak"
fi

# ---- 7: generic text rule marker in 5 files -------------------------------
c7=""
for f in CLAUDE.md .claude/skills/entrevista/SKILL.md .claude/skills/planificar/SKILL.md \
  .claude/skills/game-guide/SKILL.md .claude/skills/publicar/SKILL.md; do
  has_line "$f" 'Generic text rule:' || c7="$c7 $f"
done
if [ -z "$c7" ]; then pass 7 "Generic text rule: present in 5 of 5 files"; else fail 7 "Generic text rule: missing in:$c7"; fi

# ---- 8: pinned Spanish lines (source: contracts/flow.md) ------------------
c8=""
pin() {
  has_line "$1" "$2" || c8="$c8
  $1 lacks: $2"
}

R=.claude/skills/reto/SKILL.md
E=.claude/skills/entrevista/SKILL.md
P=.claude/skills/planificar/SKILL.md
G=.claude/skills/game-guide/SKILL.md
U=.claude/skills/publicar/SKILL.md
M=.claude/skills/mi-progreso/SKILL.md

pin "$R" 'Durante el juego Claude Code te pedirá permiso varias veces: para ejecutar comandos como git, curl o claude, y para crear o editar archivos (tu registro, PLAN.md y los skills, agentes y hooks que construyas). Es normal: puedes aprobarlos. Más adelante, al publicar, te pedirá permiso una vez para ejecutar curl; también puedes aprobarlo.'
pin "$R" 'Tu alias aparecerá en la pantalla de la sala. No uses tu nombre real ni el de tu empresa.'
pin "$R" 'Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto.'
pin "$E" 'Cuando escribas el título y el resumen, déjalos genéricos: describe la automatización, no tu empresa ni sus sistemas.'
pin "$P" 'El plan admite de 1 a 5 tareas. Después de cerrarlo ya no se cambia.'
pin "$P" '¿Cerramos este plan?'
pin "$G" 'Esta pregunta no cuenta: ya tienes 3 preguntas válidas en esa categoría.'
pin "$G" 'Esta pregunta no cuenta: ya registraste una igual.'
pin "$G" 'Esta pregunta no cuenta para el juego, pero te la respondo.'
pin "$U" 'Para subir tu captura, Claude Code te pedirá permiso una vez para ejecutar curl. Puedes aprobarlo.'
pin "$U" 'Antes de la captura: que no aparezcan datos internos de tu empresa (nombres, clientes, sistemas, cifras). Usa un ejemplo genérico.'
pin "$U" 'La imagen pesa más de 5 MiB. Haz una captura más pequeña (menor resolución u otro formato).'
pin "$U" 'Escribe una conclusión de una sola línea (máximo 280 caracteres), genérica: qué lograste, sin nombres de tu empresa.'
pin "$U" 'Recuerda: tu captura y tu conclusión se proyectan en la sala, en la galería de cierre, junto a tu alias. Deben ser genéricas y no contener datos de tu empresa.'
pin "$M" 'Aún no te has registrado. Ejecuta /reto.'
pin CLAUDE.md '+{points_earned} puntos | Total: {total} | Campamento: {camp name}'
pin CLAUDE.md '{delta} puntos | Total: {total} | Campamento: {camp name}'
pin CLAUDE.md 'Sin puntos: {reason in Spanish} | Total: {total} | Campamento: {camp name}'
pin .claude/agents/verifier.md 'Criterio no cumplido:'
for f in "$E" "$P" "$U" CLAUDE.md; do
  pin "$f" 'Status gate:'
done

if [ -z "$c8" ]; then
  pass 8 "all pinned Spanish lines and Status gate: markers are present"
else
  fail 8 "pinned lines missing"
  printf '%s\n' "$c8"
fi

# ---- 9: token check lines and no grep -q in reto (source: the reto skill) --
c9=""
pin9() {
  has_line "$1" "$2" || c9="$c9
  $1 lacks: $2"
}

pin9 "$R" 'grep -c BOLD_TOKEN .claude/settings.local.json'
pin9 "$R" "grep -c '<paste-the-token-here>' .claude/settings.local.json"
pin9 "$R" 'Judge both token checks by the printed number'
if [ -f "$R" ] && grep -qF -e 'grep -q' "$R"; then
  c9="$c9
  $R contains: grep -q"
fi

if [ -z "$c9" ]; then
  pass 9 "reto carries the token check lines and no grep -q"
else
  fail 9 "reto token checks differ"
  printf '%s\n' "$c9"
fi

exit "$failed"
