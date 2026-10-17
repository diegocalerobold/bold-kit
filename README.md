# Kit del reto

Este kit te permite jugar el reto durante la charla con Claude Code. Léelo antes de la charla: así llegas con todo listo y ganas el bono de registro.

## 1. Descarga el kit

Enlace del kit: `<KIT_URL_AFTER_APPROVAL>` (se publicará cuando el equipo de seguridad lo apruebe).

Clona el repositorio o descarga el ZIP y abre la carpeta con Claude Code.

## 2. Requisitos

- Claude Code, versión mínima **2.1.301** (provisional: es la versión verificada hasta ahora y puede cambiar).
- `git` instalado. En Windows, Git for Windows.
- `curl` instalado. Viene con macOS y con las versiones recientes de Windows.

Recursos de instalación:

- Claude Code: https://code.claude.com/docs/en/overview
- Skills de Claude Code: https://code.claude.com/docs/en/skills
- Git: https://git-scm.com/downloads

Comprueba tu versión con `claude --version`.

## 3. El token del juego

El token del juego llega en la comunicación previa a la charla (correo o canal). Es el mismo para todos los participantes. Colócalo solo en el archivo `.claude/settings.local.json` de esta carpeta (si no existe, créalo) con este contenido, cambiando el texto entre `<` y `>` por el token:

```json
{"env": {"BOLD_TOKEN": "<paste-the-token-here>"}}
```

Ese archivo no se sube a git. No pegues el token en el chat, en capturas, en otros archivos ni en ningún lugar fuera de la carpeta del kit.

## 4. Primera vez que abres la carpeta

Al iniciar `claude` en la carpeta verás dos avisos. Acéptalos:

- **Confianza en la carpeta.** Al aceptarla se activa la regla de permisos del kit (`mcp__bold__*`), que permite las llamadas al servidor del juego sin preguntarte cada vez.
- **Servidor MCP del proyecto.** Aprueba el servidor `bold`; es el servidor del juego.

## 5. Permisos que verás

La única regla preaprobada es `mcp__bold__*`. Todo lo demás te lo pedirá Claude Code, y puedes aprobarlo:

- Algunos permisos para `git` y para los comandos de la comprobación inicial de `/reto`.
- Un permiso para `curl` en `publicar`, cuando subas tu captura.

## 6. Antes de la charla: ejecuta /reto

Ejecuta `/reto` antes de la charla. Registra tu participación, crea tu alias y te da un bono de **50 puntos** si te registras antes del inicio.

Tu alias aparecerá en la pantalla de la sala. No uses tu nombre real ni el de tu empresa.

Después del registro el juego espera a la charla. Hasta que la charla dé el aviso de inicio:

- Jugar antes del inicio cuesta **25 puntos** por cada llamada. Espera el aviso.
- Preguntar al guía del juego no cuesta nada. Puedes hacerle preguntas sobre agentes, skills, comandos, hooks, MCP o rutinas.

Con `/mi-progreso` ves tu puntaje y tu avance en cualquier momento.

## 7. Datos de tu empresa

Los títulos, los resúmenes, las tareas, las preguntas, las conclusiones y la captura se envían al servidor tal como los escribes. Mantén fuera los datos de tu empresa: usa ejemplos genéricos y describe la automatización, no tu empresa ni sus sistemas (sin nombres, clientes, sistemas ni cifras).

En la galería de cierre se proyectan en la sala tu captura y tu conclusión, junto a tu alias. Deben ser genéricas.

## 8. Captura de pantalla

Al final subirás una captura de tu resultado. Estos son los atajos del sistema:

- macOS: `Cmd + Shift + 4`
- Windows: `Win + Shift + S`

Se aceptan imágenes PNG, JPEG o WebP de hasta 5 MiB.

## 9. Foto de un boceto desde el teléfono

Si dibujas un boceto en papel, pasa la foto al computador con:

- AirDrop (de iPhone a Mac).
- WhatsApp Web: envíate la foto en un chat contigo y descárgala en el computador.

Antes de usar la foto, revisa que no aparezcan datos internos de tu empresa.
