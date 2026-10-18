---
name: publicar
description: Upload the participant's screenshot, publish the one-line conclusion and reach the summit (camp 4). Started by /reto once every task is verified.
---

# Publicar

Everything said to the participant is Spanish (neutral `tú`, no voseo). Quoted lines are shown exactly as written.

Use it at camp 4 (Verificación) with the game open. Tools: `request_upload` and `publish_result`. Local: reads the screenshot file. Read the participant id from `.bold/participant_id`.

## Steps

0. Status gate: before `request_upload` in a run, call `my_progress` and read `game.status` from the answer. When it is `closed`, print "Ya estás registrado. El juego empieza con la charla: espera el aviso y vuelve a ejecutar /reto. Mientras tanto puedes hacer preguntas al guía del juego (escribe tu pregunta sobre agentes, skills, comandos, hooks, MCP o rutinas); preguntar no cuesta puntos." and stop; call no gated tool. A skill started directly by the participant is covered the same way. Then announce: "Para subir tu captura, Claude Code te pedirá permiso una vez para ejecutar curl. Puedes aprobarlo."
1. Remind: "Antes de la captura: que no aparezcan datos internos de tu empresa (nombres, clientes, sistemas, cifras). Usa un ejemplo genérico."
2. Ask for the file path of the screenshot.
   - Accept only `.png`, `.jpg`/`.jpeg` and `.webp`. Otherwise say "Solo se aceptan imágenes PNG, JPEG o WebP; conviértela o vuelve a capturarla."
   - Check the size with `wc -c`. Over 5 MiB (5242880 bytes) is not uploaded: "La imagen pesa más de 5 MiB. Haz una captura más pequeña (menor resolución u otro formato)."
   - When the participant has no capture, show the shortcuts: macOS `Cmd + Shift + 4`, Windows `Win + Shift + S`.
3. Ask: "Escribe una conclusión de una sola línea (máximo 280 caracteres), genérica: qué lograste, sin nombres de tu empresa."
4. BEFORE calling `publish_result`, remind as one line: "Recuerda: tu captura y tu conclusión se proyectan en la sala, en la galería de cierre, junto a tu alias. Deben ser genéricas y no contener datos de tu empresa." and ask for a final yes.
5. Call `request_upload` with the content type (`image/png`, `image/jpeg` or `image/webp`). Upload with `curl -sS -X PUT`, each returned header as `-H "Name: value"` exactly as returned, and `--data-binary @<file>` to `upload_url`, reading `-o /dev/null -w '%{http_code}'`. A code of 200 is success. Never show the signed URL to the participant.
6. Call `publish_result` with `conclusion` and `screenshot` = the returned `object_name`, unedited. Then print "Llegaste a la cumbre." and the link of the answer.

Generic text rule: the conclusion and the screenshot describe the automation, not the company, its clients, its systems or its figures. When the participant insists on specific text, explain the rule once, offer a generic wording and use what the participant finally confirms. Never classify, moderate or block.

## Reactions

One call, one answer; no automatic retry beyond what is stated here.

- Upload code not 200, or `expires_at` passed: say "El enlace de subida venció o fue rechazado. Pido uno nuevo." and call `request_upload` once per failed upload. Never edit `object_name`.
- `screenshot_not_found`, `screenshot_not_owned`: "No encuentro tu captura en el servidor." Repeat the upload from a new link.
- `out_of_order` (for example `publish_result` at camp 3, with `pending` `complete_task`): print "Todavía no toca ese paso. Ahora toca: {pending in Spanish}." relaying `pending` in plain Spanish ("completar las tareas") and return to the verifier. With `pending` null (camp 5): "Ya llegaste a la cumbre: no queda ningún paso pendiente." Show the final state and the link.
- `tasks_pending`: a defensive branch only, unreachable through the kit. Say "Aún tienes tareas sin verificar." and return to the verifier.
- `empty_conclusion`, `text_too_long`: "Ese texto no es válido: {field}. Escríbelo de nuevo, más corto o completo." Ask for corrected text.
- `unsupported_content_type`: kit error, "Hubo un error interno del kit; no es culpa tuya."
- `pre_kickoff`: "El juego aún no ha empezado. Esa llamada costó 25 puntos y no cambió nada más." Stop.
- `internal_error` or server unreachable: "No pude conectar con el servidor. No se otorgaron puntos. Inténtalo de nuevo en un momento."

Never state points the server did not confirm. Never print the token or the email.
