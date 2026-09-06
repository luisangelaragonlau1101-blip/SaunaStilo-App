# Sauna Stilo 3.2 · Pausa Stilo

Esta entrega reúne la corrección de tareas generales, el área de almacén y la nueva sección de juegos locales. Mantiene logo, negro nocturno, vino, verde neón y acentos violeta/ámbar; no cambia la IA ni elimina la alerta general.

## Juegos sin Internet
- Memorama Stilo: 1 a 4 personas, 12 pares con símbolos de bienestar y taller. Un acierto conserva el turno; un fallo pasa al siguiente jugador. Marcador y resultado final con empates.
- Territorios Stilo: 2 a 4 personas, unen puntos y cierran cuadros. Quien cierra un cuadro repite turno. Nueve territorios y puntuación por jugador.
- Carrera Stilo: 2 a 4 personas, dado local y recorrido de 30 casillas con impulsos/retrocesos. No contiene apuestas, compras, anuncios ni premios monetarios.

Estos modos son por turnos **en el mismo teléfono o tableta**. No requieren cuenta, Firebase, Wi-Fi, datos móviles ni permiso del micrófono. Todos sus recursos visuales son locales. Los nombres/apodos son opcionales y una partida se guarda en el dispositivo para continuar. No afectan asistencias, rachas, permisos ni logros de trabajo. Los juegos en teléfonos separados siguen requiriendo una conexión entre dispositivos; el Gato remoto existente usa Internet.

Acceso: Inicio → Pausa Stilo · Juegos → Sin Wi-Fi · hasta 4. También hay acceso Juegos sin conexión · hasta 4 desde la pantalla de inicio de sesión; una cuenta cerrada no da acceso a ninguna información de la empresa. En web se debe abrir una vez con Internet y dejar preparar los archivos públicos; el APK ya contiene los recursos de juego. No puede abrirse una web nunca visitada sin haber descargado sus archivos.

## Operación incluida
Administración: Tareas → Crear → Tarea general → Persona. No requiere elegir proyecto. Maestro: tareas dentro de sus proyectos. Almacén: solicitudes, aprobación, entrega, devolución, recepción e historial; catálogo y registro con foto comparten estética nocturna. El modo sin conexión de trabajo distingue borrador/copia local de confirmación del servidor.

## Pendientes externos que no se ocultan
Las reglas de Firestore/Storage y funciones de producción no se publican con una compilación web o APK. Las autorizaciones de maestros, el historial estricto del almacén y juegos remotos requieren revisar/publicar esas reglas con la cuenta propietaria. No se accedió ni se modificó facturación, usuarios, datos de producción o la configuración de Spotify. La voz personalizada sigue aplazada. Spotify muestra canciones compartidas, no actividad automática en vivo. El bloqueo de capturas es una política del nuevo APK Android; no bloquea Chrome/Safari ni cámaras externas.

## Verificación
La ejecución de CI debe aprobar reglas aisladas, tareas generales, navegación, motores de juegos, guardado/restauración, interacción de 4 jugadores a 320 px, compilación web y APK. La prueba de navegador corta toda conexión y verifica que los tres juegos abren y responden a jugadas sin iniciar sesión y que la carrera se recupera después de recargar. Estos tests no sustituyen pruebas físicas de sonido, cámara, préstamos y notificaciones en los teléfonos del equipo. El APK mantiene firma de desarrollo para pruebas internas; una firma distinta de otro APK puede impedir actualizarlo encima. No se distribuye ninguna clave privada.
