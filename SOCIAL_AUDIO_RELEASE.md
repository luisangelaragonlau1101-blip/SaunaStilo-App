# Sauna Stilo · perfiles, notas y audios

## Publicación de esta entrega
- Administradores: panel de supervisión, sin botones de entrada/salida. El catálogo conserva Asistencias para consultar al equipo y ALERTA GENERAL. Los demás roles conservan su jornada.
- Navegación: Inicio, Comunidad, Chats, Tareas y Perfil en una barra redonda con cinco acentos suaves, brillo y símbolos circulares. Se conserva el logo y el modo noche.
- Reconocimientos y lugares: Administración elige símbolo y color. Los logros automáticos también usan medallones; se conserva cada registro anterior.
- Perfil → Mi mundo: enlaces opcionales de Instagram, Facebook, TikTok, Spotify, YouTube, X, LinkedIn, sitio web y otro enlace. Los enlaces se validan antes de guardar y de abrir; nunca se piden contraseñas de redes.
- Chats → Notas del equipo: crear/editar/eliminar una nota con comentario y enlace musical. Visible al equipo autenticado en Chats y Comunidad hasta quitarla. Música por enlace externo, sin copiar ni reproducir canciones automáticamente. No envía una alarma general por publicar una nota.
- Audios: micrófono → Grabar → Detener → Escuchar → Enviar. Se mantiene la muestra para reintentar si falla el envío. Reproducción a velocidad 1×, pausa y progreso, sin varias notas sonando a la vez. El capturador web remuestrea la frecuencia real a WAV mono 24 kHz; no etiqueta datos de 48 kHz como 16 kHz.
- Online Smart conserva su motor y alojamiento. Una respuesta puede enviarse al reproductor autenticado de Sauna Stilo mediante Voz de Ángel, exclusivamente al tocar el botón; se verifica origen/ventana/esquema y no se reenvían tokens. Las respuestas largas se separan en partes de hasta 900 caracteres.

## Activación de voz por el propietario
Google debe aprobar Instant Custom Voice para el proyecto saunastiloapp-17e15. Con esa cuenta, revisar y ejecutar `bash tools/activate-voice-service.sh` en el repositorio desde Cloud Shell. Solicita confirmación, no cambia IAM ni facturación; el uso puede generar cargos. Después: Administración → Mi voz → Comprobar servicio → grabar consentimiento y referencia propios → Crear mi voz → Probar mi voz. Por último, dentro de Online Smart tocar Voz de Ángel → Generar con voz oficial → Escuchar.

No se ha ejecutado ese despliegue, grabado consentimiento en nombre del usuario ni creado una voz durante esta entrega. La voz del dispositivo y las notas grabadas no equivalen a la voz sintética. El nuevo rechazo de asistencia de administradores en el servidor requiere publicar updateAttendance; la separación visual está en la web.

## Verificaciones y alcance
Pruebas automatizadas de enlaces, notas, roles, layout estrecho, reglas aisladas y WAV. Captura/reproducción web con audio sintético y respuesta real pública de Online Smart, sin cuentas productivas ni mensajes al equipo. Aún se requiere verificar entre dos cuentas autorizadas en sus teléfonos: ambos sentidos de notas de voz, almacenamiento real, permisos de micrófono y avisos en segundo plano. No se certifica recepción push ni volumen forzado. No se cambian reglas de producción, usuarios o expedientes durante esta publicación.
