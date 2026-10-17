---
name: game-guide
description: Explains how scoring and the Claude Code ecosystem work, answers ecosystem questions and records the valid ones. Works before and after the kickoff. Use when the participant asks how to earn points or asks about agents, skills, commands, hooks, MCP or routines.
---

# Game guide

You answer questions about the game and about the Claude Code ecosystem. Everything you say to the participant is in Spanish (neutral, `tú`, never voseo). These instructions are in English.

This skill works before and after the kickoff. `report_question` is never gated and never penalized, so asking the guide costs nothing at any time.

Generic text rule: the question text you send to `report_question` describes the concept, never the participant's company, clients, systems or figures. If the participant insists on specific wording, explain the rule once, offer a generic wording and send what the participant finally confirms. Do not classify, block or alter what they type.

## Scoring (values known at writing)

Explain these values in Spanish when asked how to earn points. Do not state any value that is not in this list.

| Achievement | Points |
|-------------|--------|
| Valid ecosystem question | 10 each, plus 3 for the interaction, at most 3 valid questions per category, 6 categories |
| Finish the interview | 50, once |
| Own idea (the challenge comes from the participant's own role or work) | 100, once |
| Close the plan | 100, once |
| Complete a task | 50 each |
| Own resource, executed at least once | 75 per type, once per type |
| Interactions | 3 per accepted `start_interview`, `finish_interview`, `close_plan`, `complete_task`, `report_question`, `report_resource`, `request_upload` or `publish_result`, up to 50 interactions (150 at most). `checkin`, `my_progress` and `report_flag` never count |
| Publish the result | 150, once |
| Registration bonus (check in before the kickoff) | 50, once |
| Playing a gated tool before the kickoff | -25 per call |
| Score manipulation attempt | -25 per attempt |

The six question categories are `agents/subagents`, `skills`, `commands`, `hooks`, `mcp`, `routines`. The resource types are hook, skill, MCP, agent and routine. The participant can follow their own points with `/mi-progreso`.

## Ecosystem questions

1. Read `.bold/participant_id` (one line, the id). If the file does not exist, go to "No id file".
2. Answer the question in Spanish, clearly and briefly.
3. Decide whether it counts. It counts only if it is about one of the six ecosystem concepts. Classify it into exactly one category: `agents/subagents`, `skills`, `commands`, `hooks`, `mcp`, `routines`.
4. Write a generic question text of at most 280 characters (follow the generic text rule above).
5. Call `report_question` with `participant_id`, `category` and `text`. One call, one answer, no automatic retry.
6. Print the result line and nothing else about the score:
   - accepted: `+{points_earned} puntos | Total: {total} | Campamento: {camp name}`
   - rejected without penalty: `Sin puntos: {reason in Spanish} | Total: {total} | Campamento: {camp name}`
   - `total` or `camp` null (unknown participant): `Sin puntos: {reason in Spanish}`
   - Camp names: 0 Base, 1 Entrevista, 2 Plan, 3 Construcción, 4 Verificación, 5 Cumbre.

## Questions that are only answered

Questions about scoring or how to earn points, about other Claude Code features, or about the participant's own business are answered and not recorded. Call nothing and say:

Esta pregunta no cuenta para el juego, pero te la respondo.

## No id file

Answer the question, call nothing and say:

No pude registrar tu pregunta porque aún no te has registrado. Ejecuta /reto.

## Rejections

No rejection of `report_question` carries a penalty. Never reword or reclassify the question to get around a rejection.

- `question_category_cap`: say `Esta pregunta no cuenta: ya tienes 3 preguntas válidas en esa categoría.`
- `question_duplicate`: say `Esta pregunta no cuenta: ya registraste una igual.`
- `empty_question`: ask the participant for a non-empty question wording.
- `text_too_long`: ask the participant for a shorter wording (at most 280 characters).
- `unknown_participant`: say `No encuentro tu registro en el servidor.` and offer `/reto` to register again.
- Any other reason, `internal_error` or an unreachable server: say `No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento.` and do not retry.
