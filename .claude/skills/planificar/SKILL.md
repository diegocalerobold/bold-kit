---
name: planificar
description: Turn the confirmed challenge into a plan of 1 to 5 tasks, write PLAN.md and close the plan in the game (camp 2). Started by /reto.
---

# Planificar

Runs in the main conversation, never in a subagent. A reduced `planner-fast`: no certification, judgment, deep or standard variants, no memory store and no bundled browser. Everything said to the participant is Spanish (neutral `tú`, no voseo). Quoted lines are shown exactly as written.

Use it at camp 2 (Plan) with the game open. Tool: `close_plan`. Local write: `PLAN.md`. Read the participant id from `.bold/participant_id`.

## Steps

0. Status gate: before `close_plan` in a run, call `my_progress` and read `game.status` from the answer. When it is `closed`, print "Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto. Mientras tanto puedes hacer preguntas al guía del juego (escribe tu pregunta sobre agentes, skills, comandos, hooks, MCP o rutinas); preguntar no cuesta puntos." and stop; call no gated tool. When it is `finished`, print "El juego ya terminó. Tus puntos quedaron congelados: puedes verlos con my_progress. La encuesta de satisfacción es el código QR que está en la pantalla." and stop; call no further game tool. A skill started directly by the participant is covered the same way.
1. Compute the remaining time: `remaining = 65 - minutes since kickoff_at`. `kickoff_at` comes from the server answer read in this run; the local clock only measures the elapsed time.
2. The participant chooses the plan size freely, from 1 to 5 tasks (the server limit). Recommend `n = floor(remaining / 15)` tasks, at least 1, and say: "Tienes unos {remaining} minutos; te recomiendo {n} tareas. Un plan más largo corre el riesgo de no terminarse, pero tú decides: de 1 a 5." The number is a guide, never a cap: never impose or limit the size and use no time formula as a limit. With little time left recommend one task and say so, and still accept the participant's choice.
3. Propose the chosen number of tasks ordered as the resource ladder (skill, subagent, hook, routine, MCP), so each task produces one working resource, about 10 to 15 minutes each, the first deliverable in 15 minutes or less. Each task has a generic title, a criterion and evidence, each at most 200 characters. For a hook-rung task, the criterion asks for the hook to be registered in `.claude/settings.json`.
4. Explain the limit before closing: "El plan admite de 1 a 5 tareas. Después de cerrarlo ya no se cambia."
5. Write `PLAN.md` in exactly this format, 1 to 5 task sections, the position being the heading number starting at 1:

   ```markdown
   # Plan

   Reto: <generic challenge title>

   ## 1. <task title>
   - Criterio: <criterion>
   - Evidencia: <evidence>
   - Recurso: skill | subagente | hook | rutina | MCP
   - Estado: pendiente
   ```

   `Recurso` is a note for the participant and is not sent to the server. `Estado` becomes `hecha` only after `complete_task` is accepted.
6. BEFORE closing, remind as one line: "Recuerda: el título de tu reto y los títulos de tus tareas se proyectan en la sala cuando alguien selecciona tu casilla en el mundo. Deben ser genéricos y no contener datos de tu empresa ni de tus clientes." Ask "¿Cerramos este plan?" and call `close_plan` only after a clear yes, with the same tasks as `PLAN.md` (title, criterion, evidence, the exact strings). The camp becomes 3: continue with the build.

Generic text rule: task titles, criteria and evidence describe the automation, not the company, its clients, its systems or its figures. Never classify, moderate or block the participant's text.

## Reactions

One call, one answer; no automatic retry. Never retry silently.

- `task_count_out_of_range`, `task_incomplete`, `text_too_long`: fix the task named in `detail`, update `PLAN.md` and ask again. Use "Ese texto no es válido: {field}. Escríbelo de nuevo, más corto o completo."
- `out_of_order`: print "Todavía no toca ese paso. Ahora toca: {pending in Spanish}." and continue from `pending`. With `pending` null: "Ya llegaste a la cumbre: no queda ningún paso pendiente."
- `pre_kickoff`: "El juego aún no ha empezado. Esa llamada costó 25 puntos y no cambió nada más." Stop.
- `internal_error` or server unreachable: "No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento."

Never state points the server did not confirm. Never print the token or the email.
