#!/usr/bin/env bash
# Structural test of the kit (checks 1 to 4 and 6 to 12). One PASS or FAIL line per check;
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
      gsub(/\{"env": \{"BOLD_TOKEN": "K7P4-Q9MX"\}\}/, "", line)
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
    == ["bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/anti-cheat.sh\"","bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/ledger.sh\"","bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/result.sh\""]' "$s" >/dev/null 2>&1; then
  c2="command strings must be exactly the three script calls"
elif ! jq -e '[.hooks.PostToolUse[].hooks[].command] == ["bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/ledger.sh\"","bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/result.sh\""]' "$s" >/dev/null 2>&1; then
  c2="PostToolUse must run ledger.sh and then result.sh"
elif ! jq -e '[.hooks.PostToolUseFailure[].hooks[].command] == ["bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/ledger.sh\""]' "$s" >/dev/null 2>&1; then
  c2="PostToolUseFailure must run only ledger.sh"
elif ! jq -e '[.hooks.UserPromptSubmit[].hooks[].command] == ["bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/anti-cheat.sh\""]' "$s" >/dev/null 2>&1; then
  c2="UserPromptSubmit must run only anti-cheat.sh"
fi
if [ "$c2" = ok ]; then pass 2 "settings.json holds the three registrations, result.sh on PostToolUse only, and the single allow rule"; else fail 2 "settings.json: $c2"; fi

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

# ---- 6a: the file tree ----------------------------------------------------
EXPECTED="CLAUDE.md README.md .gitignore .gitattributes .mcp.json
.claude/settings.json .claude/settings.local.json
.claude/hooks/ledger.sh .claude/hooks/anti-cheat.sh .claude/hooks/result.sh
.claude/skills/reto/SKILL.md .claude/skills/mi-progreso/SKILL.md
.claude/skills/game-guide/SKILL.md .claude/skills/publicar/SKILL.md
.claude/skills/entrevista/SKILL.md .claude/skills/planificar/SKILL.md
.claude/agents/verifier.md
tests/run.sh tests/anti-cheat.test.sh tests/ledger.test.sh
tests/hooks-static.test.sh tests/kit-structure.test.sh tests/result.test.sh"
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
pin "$R" 'Criterio no cumplido: {reason}'
pin "$R" 'No encuentro BOLD_TOKEN en .claude/settings.local.json. Vuelve a dejar el archivo como viene en el kit (sección 3 del README), escribe el código que aparece en pantalla y reinicia Claude Code.'
pin "$R" 'Tu .claude/settings.local.json todavía tiene el texto de ejemplo. Reemplaza <paste-the-token-here> por el código que aparece en pantalla y reinicia Claude Code.'
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

# ---- 10: result hook, judge-only verifier, Spanish-only (source: the result hook slice)
c10=""
pin10() {
  has_line "$1" "$2" || c10="$c10
  $1 lacks: $2"
}
V=.claude/agents/verifier.md

# The verifier frontmatter lists exactly Read, Grep, Glob: no mcp tool.
vtools=$(awk '/^---$/ { n++; next } n == 1 && /^tools:/ { sub(/^tools:[ \t]*/, ""); print; exit }' "$V" 2>/dev/null)
[ "$vtools" = 'Read, Grep, Glob' ] || c10="$c10
  $V tools must be exactly 'Read, Grep, Glob', found: $vtools"
if [ -f "$V" ] && grep -qF -e 'mcp__' "$V"; then
  c10="$c10
  $V names an mcp tool"
fi
pin10 "$V" 'You make no game call'
pin10 "$V" 'cumple'
pin10 "$V" 'no cumple'

# reto camp 3: foreground, wait, calls after the verdict, and the rejection line.
pin10 "$R" 'in the FOREGROUND'
pin10 "$R" 'never run it in the background'
pin10 "$R" 'before the verdict arrives'
pin10 "$R" 'judged `cumple`'

# CLAUDE.md rules.
pin10 CLAUDE.md "The kit's result hook shows the result line of every accepted game call, and the personal link after check-in. Do not repeat them."
pin10 CLAUDE.md 'Always answer the participant in Spanish, even when they write in English.'
pin10 CLAUDE.md 'The one exception is `my_progress`'

# Pinned decision: the camp 4 sentence is hook output only, so no instruction file quotes it.
for f in CLAUDE.md "$V" .claude/skills/*/SKILL.md; do
  if has_line "$f" 'Completaste todas las tareas'; then
    c10="$c10
  $f quotes the camp 4 sentence; only result.sh prints it"
  fi
  if [ -f "$f" ] && grep -qiE -e 'print (exactly one|the) result line' -e 'Este es tu enlace personal' "$f"; then
    c10="$c10
  $f tells Claude to print a result line or the link; the hook does"
  fi
done

if [ -z "$c10" ]; then
  pass 10 "verifier is judge-only, reto camp 3 waits for the verdict, CLAUDE.md carries the hook and Spanish rules"
else
  fail 10 "result hook slice pins differ"
  printf '%s\n' "$c10"
fi

# ---- 11: the tracked token file is exactly the placeholder ----------------
T=.claude/settings.local.json
if git ls-files --error-unmatch "$T" >/dev/null 2>&1 \
  && [ "$(cat "$T")" = '{"env": {"BOLD_TOKEN": "<paste-the-token-here>"}}' ] \
  && [ "$(wc -c < "$T" | tr -d ' ')" -eq 50 ] \
  && git diff --quiet HEAD -- "$T"; then
  pass 11 "the tracked $T is byte-identical to the placeholder line"
else
  fail 11 "$T is not tracked, differs from the placeholder line, or differs from HEAD"
fi

# ---- 12: a real code never enters the baseline commit ----------------------
# Runs in a temp dir only; the kit's own tree and history are never touched.
tmp=$(mktemp -d 2>/dev/null)
c12=""
if [ -z "$tmp" ] || [ ! -d "$tmp" ]; then
  c12="could not create a temp dir"
else
  fake="TEST-""CODE"
  gitq() { git -c user.name=Test -c user.email=test@example.com "$@"; }

  # Clone path.
  if ! git clone -q "$root" "$tmp/clone" >/dev/null 2>&1; then
    c12="$c12
  clone failed"
  elif [ ! -f "$tmp/clone/$T" ]; then
    c12="$c12
  the clone does not carry $T"
  else
    printf '{"env": {"BOLD_TOKEN": "%s"}}\n' "$fake" > "$tmp/clone/$T"
    (cd "$tmp/clone" && gitq commit -q --allow-empty -m "chore: bold baseline" >/dev/null 2>&1)
    if (cd "$tmp/clone" && git show --stat HEAD) | grep -qF 'settings.local.json'; then
      c12="$c12
  clone path: the baseline commit lists settings.local.json"
    fi
    if (cd "$tmp/clone" && git log -p --all) | grep -qF "$fake"; then
      c12="$c12
  clone path: the fake code reached the history"
    fi
  fi

  # ZIP path: the tree without .git.
  mkdir -p "$tmp/zip"
  git ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    mkdir -p "$tmp/zip/$(dirname "$f")"
    cp "$f" "$tmp/zip/$f"
  done
  mkdir -p "$tmp/zip/.claude"
  printf '{"env": {"BOLD_TOKEN": "%s"}}\n' "$fake" > "$tmp/zip/$T"
  (
    cd "$tmp/zip" && git init -q >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
      && gitq commit -q -m "chore: bold baseline" >/dev/null 2>&1
  )
  if [ ! -d "$tmp/zip/.git" ]; then
    c12="$c12
  zip path: git init failed"
  elif (cd "$tmp/zip" && git ls-files) | grep -qF 'settings.local.json'; then
    c12="$c12
  zip path: git ls-files lists settings.local.json"
  fi
  rm -rf "$tmp"
fi
if [ -z "$c12" ]; then
  pass 12 "the on-screen code never enters the baseline commit (clone and ZIP paths)"
else
  fail 12 "baseline path leaks the code"
  printf '%s\n' "$c12"
fi

exit "$failed"
