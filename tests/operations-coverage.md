# Cobertura de la entrega de operaciones

- Tareas del maestro: `team-operations.test.cjs` prueba pertenencia al proyecto, roles, usuarios inactivos, datos y vencimiento. Escritura autenticada e idempotencia real requieren prueba en Firebase después del despliegue.
- Recordatorios: `team-operations.test.cjs` prueba ventanas de 15/30/45 minutos, registro completado, sábado y domingo. Entrega push real requiere servidor y teléfonos.
- Navegación: `operations_navigation_test.dart`, invocado por `release_navigation_test.dart`, verifica pestañas, regreso a Inicio, ancho 375 y cambio de día de México.
- Mensajería privada: regresiones de fuente verifican privacidad de notificaciones; los casos de dos actores, fotos, audios y llamadas se detallan en `operations-manual-checks.md`. No afirmar una prueba de dos teléfonos a partir de ellas.
- IA: `browser-smoke.cjs` abre la guía real dentro de un iframe del origen de la app y solicita una respuesta pública de uso. No registra asistencia, no usa credenciales y no manda mensajes a empleados.
- Asistencia: regresión de fuente verifica lectura por propietario y uso de `updateAttendance`, sin escritura local simulada. La comprobación de URL sin autenticación solo informa si el servicio está publicado, no si funciona para una cuenta.
