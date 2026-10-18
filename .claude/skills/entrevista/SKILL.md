---
name: entrevista
description: Interview the participant to find one real challenge from their work and register it in the game (camps 0 and 1). Started or resumed by /reto.
---

# Entrevista

Runs in the main conversation, never in a subagent. Everything said to the participant is Spanish (neutral `tú`, no voseo). Quoted lines are shown exactly as written.

Use it at camp 0 (Base) or camp 1 (Entrevista) with the game open. Tools: `start_interview` (camp 0 only) and `finish_interview` (camp 1). Read the participant id from `.bold/participant_id`.

## Steps

0. Status gate: before `start_interview` or `finish_interview` in a run, call `my_progress` and read `game.status` from the answer. When it is `closed`, print "Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto. Mientras tanto puedes hacer preguntas al guía del juego (escribe tu pregunta sobre agentes, skills, comandos, hooks, MCP o rutinas); preguntar no cuesta puntos." and stop; call no gated tool. A skill started directly by the participant is covered the same way.
1. At camp 0, call `start_interview`. At camp 1 skip this call and continue.
2. Ask one question at a time, waiting for each answer: the role, the activities that take the most time, one concrete pain, and what a good result would look like.
3. Ask for more than text: voice dictation ("En macOS pulsa fn dos veces; en Windows pulsa Win + H."), a photo of a hand sketch of the expected result, or an inspiration screenshot ("Si tienes un boceto o una captura de algo parecido, compártelo."). Read any image the participant provides.
4. Map each pain to a resource with the resource ladder and state the mapping to the participant:
   - skill: same steps and format
   - subagent: someone to handle it end to end
   - hook: every time X happens do Y
   - routine: every Monday or every morning
   - MCP: fetch data from another tool

   When the pain maps to the hook rung, tell the participant to register their own hook in `.claude/settings.json`: only hooks there count.
5. Decide the origin and say it plainly before calling:
   - `own`: only when the challenge is in the participant's words, from their own work. Help from the agent to refine it is fine.
   - `delegated`: when the agent decided the challenge, or a suggestion was adopted unchanged. If the participant has no idea the agent may suggest one; adopting it without changing it makes the origin `delegated`.
6. Compose a generic title (at most 120 characters) and a generic summary (at most 2000 characters). Say: "Cuando escribas el título y el resumen, déjalos genéricos: describe la automatización, no tu empresa ni sus sistemas." Show both and ask for confirmation. If the participant wants specific names, apply the insist-once rule: explain the rule once, offer a generic wording and use what the participant finally confirms. Never classify or block.
7. Call `finish_interview` with `origin`, `title` and `summary`, exactly as confirmed. The camp becomes 2: hand over to the `planificar` skill.

Generic text rule: the title and the summary describe the automation, not the company, its clients, its systems or its figures. Never classify, moderate or block the participant's text.

## Reactions

One call, one answer; no automatic retry. The next action belongs to the participant.

- `out_of_order`: print "Todavía no toca ese paso. Ahora toca: {pending in Spanish}." and continue from `pending`. Mapping: `start_interview` "iniciar la entrevista", `finish_interview` "cerrar la entrevista", `close_plan` "cerrar el plan", `complete_task` "completar las tareas", `publish_result` "publicar el resultado". With `pending` null: "Ya llegaste a la cumbre: no queda ningún paso pendiente."
- `invalid_origin`: kit error. Print "Hubo un error interno del kit; no es culpa tuya." and fix the argument once the participant agrees to continue.
- `empty_title`, `empty_summary`, `text_too_long`: "Ese texto no es válido: {field}. Escríbelo de nuevo, más corto o completo." Ask for corrected text; do not retry unprompted.
- `pre_kickoff`: "El juego aún no ha empezado. Esa llamada costó 25 puntos y no cambió nada más." Stop.
- `internal_error` or server unreachable: "No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento."

Never state points the server did not confirm. Never print the token or the email.
