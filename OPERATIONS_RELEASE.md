# Sauna Stilo · operación, pausas y privacidad (3.1.0)

## Entrega
- Tareas: formulario único para Administración/maestro; validación por proyecto en transacción; ID estable en reintentos; notificaciones independientes. El maestro solo asigna dentro de sus proyectos. Borradores privados locales recuperables, sin fingir asignaciones offline.
- Almacén: acceso directo para admin/almacenista. Solicitudes, En préstamo, Recibir, Historial, Entre compañeros. Aprobación y recepción físicamente confirmadas, sin duplicar stock. Daños a reparación. Historial inmutable con actor y fecha. Las cancelaciones conservan la solicitud. Los movimientos anteriores no se reescriben ni se les inventa firma.
- Sin conexión: preparación voluntaria de datos en dispositivo confiable, caché marcada, cuaderno local y borradores de tareas. La aplicación web prepara solo sus archivos públicos; no guarda APIs privadas en el service worker ni cambia el worker de avisos. Solo datos previamente cargados; no hay confirmaciones de almacén, asistencia, multimedia, IA o juego remoto sin Internet.
- Juegos: Gato por invitación entre dos cuentas, con aceptación, turnos y resultado validados en reglas. Gato y Memoria por turnos en el mismo dispositivo funcionan sin conexión. No apuestas ni compras.
- Reels: opción dedicada para adjuntar enlaces válidos de Instagram, TikTok, Facebook, YouTube y música en chats privados/proyecto; el envío permanece explícito. Se abren externamente; no se descargan ni copian videos.
- Notas Spotify: enlace y nombre de canción visible al equipo; se indica canción compartida, no reproducción en vivo. NO se implementó la consulta automática de escuchas: requiere app Spotify autorizada y consentimiento individual. No hay credenciales Spotify ni lecturas en segundo plano en esta entrega.
- Asistencias mantiene controles de Administración y lógica previa, con paleta nocturna. Rachas: última secuencia, mejor racha, meta y fechas que sustentan el cálculo. Solo admin ve todo el equipo; días inexistentes no se inventan como asistencias.
- Perfil administrativo: interruptor bloquear capturas. Aplica FLAG_SECURE en toda la Activity del nuevo APK Android. Política conservadora al iniciar/cambiar cuenta; recibe configuración por perfil. No protege navegador/iOS, otras apps, dispositivos modificados ni fotos con cámara externa. El APK 3.0.1 NO contiene este control nativo.

## Activación no realizada
La web y el APK no publican Firestore Rules automáticamente. Para asignaciones del maestro, historial estricto y juegos compartidos hay que publicar `firestore.rules` con la cuenta propietaria, reconciliando primero reglas editadas fuera del repositorio. No se publicaron funciones, se modificó facturación ni se enviaron registros/avisos a empleados durante QA.

Desde una copia revisada de esta versión y una cuenta autorizada: `firebase deploy --project saunastiloapp-17e15 --only firestore:rules`. Este comando reemplaza las reglas activas; conservar primero una copia desde Firebase Console. No usar reglas abiertas de prueba. Las reglas mantienen módulos anteriores, y separan las colecciones inmutables del permiso administrativo genérico.

## Pruebas necesarias
Node sobre datos/avisos y caché pública, emuladores aislados de autorización y movimientos, Flutter para roles/formularios/juegos, compilación web y Android. Registrar el resultado real de CI; este archivo no afirma pruebas realizadas solo por existir. La aceptación final requiere dos cuentas autorizadas en teléfonos: crear tareas, aprobar/recibir/rechazar préstamo, enviar audio, jugar, preparar offline, y comprobar captura con bloqueo activo/inactivo. Firma Android sigue siendo la de desarrollo para pruebas internas, no Play Store.
