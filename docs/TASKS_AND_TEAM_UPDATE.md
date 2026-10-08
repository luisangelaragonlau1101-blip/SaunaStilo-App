# Tareas y organización del equipo

## Comportamiento de esta actualización

- El responsable marca una tarea o actividad como terminada con una confirmación. Las fotografías, archivos y descripción son opcionales.
- La entrega pasa a **Por aprobar**. Administración puede **Aprobar y finalizar** o solicitar cambios con una observación.
- Las entregas históricas marcadas como completadas siguen disponibles para revisión si no tienen una aprobación registrada. Se conservan sus fotografías anteriores.
- Los porcentajes se guardan en la misma transacción que el avance y aparecen en las listas y el detalle. Administración puede registrar avances operativos de instalaciones y envíos.
- Inicio incluye las tareas personales del día y pendientes anteriores. Administración también ve las entregas del equipo por aprobar.
- Las instalaciones y envíos conservan su historial por mes de asignación; al crearlos se envía una fecha completa, no solo un mes.
- Las tareas extras se asignan independientemente de un proyecto. Administración asigna las tareas independientes; los maestros conservan la asignación de actividades dentro de sus proyectos.
- Un error de Firestore no cambia silenciosamente la escritura a otra base de datos. El aviso de una tarea abre su detalle; si no se confirma el registro de un aviso, la interfaz conserva el trabajo guardado y ofrece reintentar.
- Recursos Humanos permite filtrar departamentos y registrar puestos, practicantes, carrera, institución educativa y tutor. Estos datos permanecen privados para Administración; los permisos de la cuenta siguen usando los roles existentes.
- Ideas, maderas y jornada tienen nuevos encabezados visuales. **Stilo original** sigue siendo el tema predeterminado. **Vino ejecutivo** es una elección adicional en Mi estilo.
- Se corrigió la capa de la bolita del asistente para conservar sus controles al navegar. Se mantienen los audios existentes en chats y asistente, las notas en Mensajes y el registro separado de entrada, comida, pausas y salida. Las pantallas de chat no ofrecen botones de llamadas.

## Validación realizada

- `node --test tests/*.test.cjs tools/online-smart34/*.test.mjs`: 124 aprobadas.
- `flutter test --no-pub --concurrency=4`: 100 aprobadas.
- Emulador aislado de Firestore, `tools/general-task-security.test.cjs` y `tools/operations-security.test.cjs`: 16 aprobadas. El trabajador entrega sin adjuntos, no puede autoaprobarse y no puede reabrir una tarea aprobada.
- `flutter analyze --no-pub lib test --no-fatal-infos --no-fatal-warnings`: sin errores; permanecen avisos e información de lint del repositorio.
- `flutter build web --release --no-pub --base-href /SaunaStilo-App/ --pwa-strategy=none`: compilación JavaScript aprobada. La comprobación opcional de WebAssembly señala incompatibilidades existentes de `flutter_tts`.
- `node tools/prepare-offline.cjs`: recursos públicos offline preparados.
- Arranque del artefacto local con Chromium en 390 × 844 y 1440 × 960: HTTP 200, formulario de acceso visible y sin errores JavaScript. Los recursos externos de Firebase se cargaron mediante la ruta HTTPS con verificación TLS del entorno.

## Publicación

El flujo `build-web.yml` publica GitHub Pages desde `main`, con base `/SaunaStilo-App/`. `vercel/vercel.json` dirige el dominio de Vercel a ese alojamiento. La versión pública se comprueba en `version.json`.

Las reglas de Firestore actualizadas requieren una cuenta autorizada para publicarse. Mientras se conserva el esquema anterior, un rechazo del campo resumen `porcentaje` vuelve a intentar la misma transacción sin ese campo: el porcentaje permanece en el avance, junto con la entrega, y las pantallas lo consultan desde el historial. Se mantienen las comprobaciones de cuenta, responsable y estado; un rechazo restante se muestra como error. La prueba aislada verifica que la transacción rechazada no deje una entrega parcial ni conceda acceso a otros trabajadores.

El servicio existente `sendSaunaStiloNotification` y los programadores de entrada, comida y salida deben estar desplegados para entregar avisos en segundo plano. Cada dispositivo debe autorizar las notificaciones en **Notificaciones y sonido**; el nuevo acceso desde Proyectos y tareas facilita hacerlo. No se han enviado avisos al personal ni cambiado permisos en teléfonos durante estas pruebas. La recepción real, las cuentas de producción y las respuestas de IA/voz de servicios externos siguen necesitando validación autorizada después de publicar.
