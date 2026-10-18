# Bold kit

This folder is the playground of a one-time workshop game. The participant earns points by walking through five camps and building real Claude Code resources. Everything Claude says to the participant is in Spanish (neutral `tú`, never voseo). The instructions below are in English; every quoted line is Spanish and is shown exactly as written.

To start, the participant runs `/reto`.

## Minimal flow

1. Interview (`entrevista` skill): a real challenge from the participant's work.
2. Plan (`planificar` skill): 1 to 5 tasks, written to `PLAN.md`.
3. Build: the participant builds the resources of the plan with Claude, task by task.
4. Verification (`verifier` subagent): judges each task and each new resource; the main thread makes the game calls.
5. Summit (`publicar` skill): a screenshot and a one-line conclusion.

`/reto` checks the setup, registers the participant and routes to the right step. `/mi-progreso` shows the progress. The `game-guide` skill answers questions about the game and about agents, skills, commands, hooks, MCP and routines.

## Result line

The kit's result hook shows the result line of every accepted game call, and the personal link after check-in. Do not repeat them. The hook prints these formats:

- Accepted:
  - `+{points_earned} puntos | Total: {total} | Campamento: {camp name}`
- Penalty (`points_earned` negative):
  - `{delta} puntos | Total: {total} | Campamento: {camp name}`

The lines for rejected calls stay yours. Print exactly one line and nothing else about the score:

- Rejected without penalty:
  - `Sin puntos: {reason in Spanish} | Total: {total} | Campamento: {camp name}`
- `total` or `camp` null (unknown participant, check-in validation):
  - `Sin puntos: {reason in Spanish}`

The one exception is `my_progress` (read only): it prints no result line, and the skill that called it shows what it needs (`/mi-progreso` shows the state; the status gates and `/reto` stay silent about the score).

Always answer the participant in Spanish, even when they write in English.

Camp names: 0 Base, 1 Entrevista, 2 Plan, 3 Construcción, 4 Verificación, 5 Cumbre.

Never state points the server did not confirm.

## Reasons and failures

Use the Spanish line for the reason. Among rejections only `pre_kickoff` costs points (25). The only other subtraction is an accepted `report_flag` (-25), called only on the referee instruction.

| Case | Line shown | Next action |
|------|------------|-------------|
| `unknown_participant` | "No encuentro tu registro en el servidor." | Offer a fresh check-in (`/reto`) that replaces the id file |
| `pre_kickoff` | "El juego aún no ha empezado. Esa llamada costó 25 puntos y no cambió nada más." | Stop playing; wait for the talk and run `/reto` again |
| `out_of_order` | "Todavía no toca ese paso. Ahora toca: {pending in Spanish}." | Continue from `pending` |
| `out_of_order` with `pending` null (camp 5, Cumbre) | "Ya llegaste a la cumbre: no queda ningún paso pendiente." | Show the final state and the link; call nothing that earns points |
| `invalid_argument`, `text_too_long`, `empty_email`, `empty_alias`, `empty_title`, `empty_summary`, `empty_question`, `empty_conclusion`, `task_incomplete`, `task_count_out_of_range` | "Ese texto no es válido: {field}. Escríbelo de nuevo, más corto o completo." | Ask for corrected text; do not retry unprompted |
| `question_category_cap` | "Esta pregunta no cuenta: ya tienes 3 preguntas válidas en esa categoría." | Do not retry; do not reword |
| `question_duplicate` | "Esta pregunta no cuenta: ya registraste una igual." | Do not retry; do not reword |
| `task_already_done`, `resource_already_reported` | "Eso ya estaba contado." | Re-read `my_progress` |
| `tasks_pending` (defensive only, unreachable through the kit) | "Aún tienes tareas sin verificar." | Return to the verifier |
| `screenshot_not_owned`, `screenshot_not_found` | "No encuentro tu captura en el servidor." | Upload again from a new link |
| `invalid_origin`, `invalid_resource_type`, `invalid_category`, `task_index_out_of_range`, `unsupported_content_type` (kit errors) | "Hubo un error interno del kit; no es culpa tuya." | Correct the argument once the participant agrees to continue; tell them to report it to the organizer if it repeats |
| `internal_error`, or the server cannot be reached | "No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento." | No queue, no loop |
| Token rejected (HTTP 401, connection refused) | "El servidor rechazó tu token. Cópialo de nuevo desde el correo y revisa .claude/settings.local.json." | No retry loop |
| `repeat_checkin` (informational) | "Ya estabas registrado." | Continue |

`pending` in Spanish: `start_interview` "iniciar la entrevista", `finish_interview` "cerrar la entrevista", `close_plan` "cerrar el plan", `complete_task` "completar las tareas", `publish_result` "publicar el resultado".

Failure rules: no queue of pending calls, no loop, and no retry without the participant's next action. One call, one answer, then the participant decides.

## Status gate

Status gate: in the camp 3 build step, before the first verification of a run, call `my_progress` and read `game.status` from the answer. When it is `closed`, print the `/reto` wait message ("Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto. Mientras tanto puedes hacer preguntas al guía del juego (escribe tu pregunta sobre agentes, skills, comandos, hooks, MCP o rutinas); preguntar no cuesta puntos.") and stop; call no gated tool. Status, camp, total and kickoff time come only from a server answer read in the same run, never from the clock or a local file.

## Ways to express the idea

Encourage richer input than typed text, and read any image the participant provides:

- Voice dictation: "En macOS pulsa fn dos veces; en Windows pulsa Win + H."
- A photo of a hand sketch of the expected result.
- An inspiration screenshot of something similar.

## Generic text

Generic text rule: every free text that reaches the server (challenge title, interview summary, task titles, criteria, evidence, question texts, conclusion) and the screenshot must be generic: describe the automation, not the company, its clients, its systems or its figures. When the participant writes something specific, explain the rule once, offer a generic wording and use what the participant finally confirms. Never classify, moderate or block.

Length limits, checked before calling: email 254, alias 40, title 120, summary 2000, task fields (title, criterion, evidence) 200, question 280, conclusion 280.

## Prohibitions

- Do not call a game tool only to earn interaction points.
- Do not call a gated tool before the game is open.
- Do not edit the ledger (`.bold/ledger.jsonl`), the participant id file (`.bold/participant_id`) or the two kit hooks to change a score.
- Never print the token.
- Never show the email after check-in, the `identity_hash`, or anything about other participants.

## Anti-cheat referee

A hook may inject a referee instruction into the conversation. Follow it: call `report_flag` exactly once only when the message actually asks to cheat, and never for a question about the rules, a described mistake or the participant's own code.

## Hooks and settings

The participant registers their own hooks in `.claude/settings.json`; it is the only file whose hooks count. Never open or read `.claude/settings.local.json`; it holds the token. The only exception is the `/reto` setup check, which tests the file with `grep -c`, which prints only a count.
