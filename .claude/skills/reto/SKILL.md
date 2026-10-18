---
name: reto
description: Start or resume the game: check the setup, register the participant, create the baseline and route to the next step by camp. Run it first.
---

# Reto

Entry point of the game. Everything said to the participant is Spanish (neutral `tú`, no voseo). Quoted lines are shown exactly as written. Status, camp, total and kickoff time come only from a server answer read in this run (`checkin` or `my_progress`), never from the clock or a local file. One call, one answer, no automatic retry. After every game call except `my_progress` print the result line of `CLAUDE.md`; `my_progress` prints no result line.

## Steps

0. Announce, before anything else: "Durante el juego Claude Code te pedirá permiso varias veces: para ejecutar comandos como git, curl o claude, y para crear o editar archivos (tu registro, PLAN.md y los skills, agentes y hooks que construyas). Es normal: puedes aprobarlos. Más adelante, al publicar, te pedirá permiso una vez para ejecutar curl; también puedes aprobarlo." Only `mcp__bold__*` is pre-approved.

1. Setup check. Print one line per item, `OK` or `FALLO` plus the fix. The first failure stops the flow. Run each check as its own separate command, exactly the commands listed, one Bash call each; never chain them with `;`, `&&` or pipes.
   - Claude Code version: run `claude --version` and compare with the minimum in the README. Failure: "Tu versión de Claude Code es {v}; necesitas {min} o superior. Actualízala y vuelve a ejecutar /reto."
   - Token present: run `grep -c BOLD_TOKEN .claude/settings.local.json`. Never read the value into the conversation. Use `grep -c`, which prints only the number of matching lines (participants may not have `rg`); never use a command that prints the file. Pass: the printed count is 1 or more. Fail: the count is 0, or there is an error such as "No such file or directory". Failure: "No encuentro BOLD_TOKEN en .claude/settings.local.json. Copia el fragmento del README, pega tu token y reinicia Claude Code."
   - Token pasted: run `grep -c '<paste-the-token-here>' .claude/settings.local.json`; it prints only a count. A count of 0 passes. A count of 1 or more means the placeholder is still there: "Tu .claude/settings.local.json todavía tiene el texto de ejemplo. Reemplaza <paste-the-token-here> por tu token y reinicia Claude Code."
   - Judge both token checks by the printed number, never by the absence of output.
   - `bold` tools in the session: the `checkin` tool of `bold` is available. Failure: "No veo las herramientas del juego. Acepta los avisos de confianza de la carpeta y del servidor MCP del proyecto; si ya los aceptaste, reinicia Claude Code."
   - `git`: run `git --version`. Failure: "Necesitas git. En Windows instala Git for Windows y reinicia Claude Code."
   - `curl`: run `curl --version`. Failure: "Necesitas curl para subir tu captura. En Windows 10 o superior ya viene incluido; actualiza o instala curl."

2. Registered? If `.bold/participant_id` exists, call `my_progress`. On `unknown_participant` say "No encuentro tu registro en el servidor. Voy a registrarte de nuevo." and continue at step 3 (the file is replaced). If accepted, go to step 4.

3. Check-in. Ask for the email and the alias. Normalize the email (trim, lowercase). Refuse an email over 254 characters or an alias over 40 before calling. Say: "Tu alias aparecerá en la pantalla de la sala. No uses tu nombre real ni el de tu empresa." Call `checkin`.
   - Accepted: create `.bold/` and write the `participant_id` and a newline to `.bold/participant_id`, nothing else. Then, right away, BEFORE the baseline and the routing, in this order: print the result line of the `checkin` answer (`+{points_earned} puntos | Total: {total} | Campamento: {camp name}`) and then "Este es tu enlace personal: {link}. Es tu llave; no lo compartas." This step is mandatory and is never skipped, whatever `game.status` is, including when the game is already open and the flow goes straight on to `entrevista`. If `repeat` is true and the returned alias differs from the typed one, say "Ya estabas registrado; se conserva tu primer alias: {alias}." Never store the email and never send it again.
   - Rejected (`empty_email`, `empty_alias`, `text_too_long`, `invalid_argument`): say "Ese texto no es válido: {field}. Escríbelo de nuevo, más corto o completo." and ask for corrected text.

4. Baseline, once: skip it when the tag `bold-baseline` exists. Each command below is its own Bash call.
   - Look for an earlier baseline commit: run `git log --format=%H --grep='^chore: bold baseline$' -n 1`. If it prints a hash and the tag does not exist (an earlier run was denied the tag), run `git tag bold-baseline <that hash>` and make no new commit. Commit only when neither the tag nor the commit exists. In a Download-ZIP folder with no `.git` there is no history to search: go straight to `git init`.
   - Before committing, read `git config user.name` and `git config user.email`, once each. Only when one is empty, set it with `git config --local user.name "Bold participant"` or `git config --local user.email "participant@bold.invalid"`. Never use the participant's email, never global, never probe the same key twice.
   - In a `git clone` (a `.git` exists and the tree is clean, so a plain commit would fail): run `git commit --allow-empty -m "chore: bold baseline"` and then `git tag bold-baseline`.
   - In a Download-ZIP folder (no `.git`): run `git init`, `git add -A` and `git commit -m "chore: bold baseline"` first, then `git tag bold-baseline`.
   - Never `push`, never `git remote add`.

5. Route by the `game.status` of the answer read in this run (step 2 or 3), never by the clock.
   - `closed`: print "Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto. Mientras tanto puedes hacer preguntas al guía del juego (escribe tu pregunta sobre agentes, skills, comandos, hooks, MCP o rutinas); preguntar no cuesta puntos." Add "Tu bono de registro: 50 puntos" only when this run's `checkin` carried `points_earned` 50. Stop. The only calls allowed are `checkin`, `my_progress` and `report_question` (through `game-guide`). While closed, never call `start_interview`, `finish_interview`, `close_plan`, `complete_task`, `report_resource`, `request_upload` or `publish_result`.
   - `open`: route by camp.
     - Camp 0 (Base): `entrevista` skill.
     - Camp 1 (Entrevista): `entrevista` skill, resumed (skips `start_interview`).
     - Camp 2 (Plan): `planificar` skill.
     - Camp 3 (Construcción): build with the participant, following `PLAN.md` task by task, with the `verifier` subagent after each task. The main thread applies the status gate first (`my_progress`, read `game.status`; if `closed`, print the wait message above and stop). When the participant says a task is done, compute the added files with `git diff --name-only --diff-filter=A bold-baseline` plus `git ls-files --others --exclude-standard`, minus `PLAN.md`, and the diffs of `.claude/settings.json` and `.mcp.json` against `git show bold-baseline:<path>`. Never open `.claude/settings.local.json`. Launch the `verifier` with the task position, its criterion and evidence from `PLAN.md`, both lists, the resource types already reported (from `my_progress`) and the participant's evidence of a run for each new resource (command output or a produced file). Show each result line the verifier returns. The participant registers their own hooks in `.claude/settings.json`. When the last task is completed the camp becomes 4: "Completaste todas las tareas. Falta publicar tu resultado."
     - Camp 4 (Verificación): `publicar` skill.
     - Camp 5 (Cumbre): show the final state and the link; nothing earns points.

6. Idempotence: a repeat run creates no second participant (the id file short-circuits to `my_progress`), no second baseline (the tag, or the existing commit when the tag was denied) and no points (`my_progress` earns 0).

Never print the token, the email after check-in, the `identity_hash` or anything about other participants.
