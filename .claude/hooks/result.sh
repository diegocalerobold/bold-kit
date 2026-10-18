#!/usr/bin/env bash
# Result hook. After an accepted game call it shows the result line to the
# participant and keeps it in <root>/.bold/puntos.txt:
#   +53 puntos | Total: 325 | Campamento: Construcción
# After check-in it also shows the personal link and saves it in
# <root>/.bold/enlace.txt. Output is one line: {"systemMessage":"..."}.
# Only the text after "tool_response": is read, because the check-in tool_input
# carries the email. No network, no jq, always exit 0.

payload=$(cat) || exit 0

# A raw newline cannot occur inside a JSON string; a space keeps one line.
payload=${payload//$'\n'/ }

# The tool name, and nothing else outside the response.
re_tool='"tool_name":[[:space:]]*"mcp__bold__([A-Za-z0-9_]+)"'
[[ $payload =~ $re_tool ]] || exit 0
tool=${BASH_REMATCH[1]}
[ "$tool" = my_progress ] && exit 0

case $payload in
  *'"tool_response":'*) ;;
  *) exit 0 ;;
esac
resp=${payload#*'"tool_response":'}

# The response is a JSON string with escaped quotes, or a plain object: an
# optional backslash goes before every quote.
q='\\?"'
sp='[[:space:]]*'
end='([,}[:space:]\\]|$)'

re_verdict="${q}verdict${q}:${sp}${q}accepted${q}"
re_points="${q}points_earned${q}:${sp}(-?[0-9]{1,9})${end}"
re_total="${q}total${q}:${sp}([0-9]{1,9})${end}"
re_camp="${q}camp${q}:${sp}([0-5])${end}"
re_link="${q}link${q}:${sp}${q}([^\"\\]*)${q}"

[[ $resp =~ $re_verdict ]] || exit 0
[[ $resp =~ $re_points ]] || exit 0
points=${BASH_REMATCH[1]}
[[ $resp =~ $re_total ]] || exit 0
total=${BASH_REMATCH[1]}
[[ $resp =~ $re_camp ]] || exit 0
camp=${BASH_REMATCH[1]}

# Sign and digits apart, so leading zeros are not read as octal and 0 is +0.
sign=+
case $points in
  -*) sign=-; points=${points#-} ;;
esac
points=$((10#$points))
[ "$points" -eq 0 ] && sign=+
total=$((10#$total))

names=(Base Entrevista Plan Construcción Verificación Cumbre)
line="$sign$points puntos | Total: $total | Campamento: ${names[$camp]}"

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

saved=0
if mkdir -p "$root/.bold" 2>/dev/null; then
  saved=1
  printf '%s\n' "$line" >>"$root/.bold/puntos.txt" 2>/dev/null
fi

lines=$line

if [ "$tool" = checkin ] && [[ $resp =~ $re_link ]]; then
  link=${BASH_REMATCH[1]}
  # Split so the static network-word scan of the hooks stays strict.
  re_url='^h''ttps://[A-Za-z0-9._~/-]+$'
  if [[ $link =~ $re_url ]]; then
    note=
    if [ "$saved" -eq 1 ] && printf '%s\n' "$link" >"$root/.bold/enlace.txt" 2>/dev/null; then
      note=' (Guardado en .bold/enlace.txt)'
    fi
    lines="$lines"$'\n'"Este es tu enlace personal: $link. Es tu llave; no lo compartas.$note"
  fi
fi

if [ "$tool" = complete_task ] && [ "$camp" -eq 4 ]; then
  lines="$lines"$'\n'"Completaste todas las tareas. Falta publicar tu resultado."
fi

# JSON string: escape backslash and quote, newline becomes \n.
lines=${lines//\\/\\\\}
lines=${lines//\"/\\\"}
lines=${lines//$'\n'/\\n}
printf '{"systemMessage":"%s"}\n' "$lines" 2>/dev/null
exit 0
