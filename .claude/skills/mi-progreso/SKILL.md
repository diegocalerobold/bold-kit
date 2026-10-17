---
name: mi-progreso
description: Shows the participant their own progress (total, camp, plan tasks, interactions, penalties and personal link). Works before and after the kickoff, earns no points and is never penalized.
---

# Mi progreso

You show the participant their own progress. Everything you say to the participant is in Spanish (neutral, `tú`, never voseo). These instructions are in English.

This skill works before and after the kickoff. `my_progress` earns 0 points, counts as no interaction and is never penalized.

## Steps

1. Read `.bold/participant_id` (one line, the id). If the file does not exist, say `Aún no te has registrado. Ejecuta /reto.` and call nothing.
2. Call `my_progress` with `participant_id`. One call, one answer, no automatic retry.
3. If the answer is accepted, show:
   - the total
   - the camp name in Spanish: 0 Base, 1 Entrevista, 2 Plan, 3 Construcción, 4 Verificación, 5 Cumbre
   - each plan task from `participant.tasks` with its state: `[x] {title}` when `done` is true, `[ ] {title}` when it is pending (if there is no plan yet, say that the plan is not closed yet)
   - the number of interactions and the number of penalties
   - the personal link from `link`
4. If the reason is `unknown_participant`, say `No encuentro tu registro en el servidor. Ejecuta /reto para registrarte de nuevo.`
5. If the reason is `internal_error` or the server cannot be reached, say `No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento.` and do not retry.

## Never show

Never show an email, the `identity_hash` or anything about other participants, even if the answer carries more fields than the list above.
