# Estado de la reparación del 28 de septiembre de 2026

El cambio de web agrega fotos pequeñas guardadas en la ficha del producto, accesos principales para todos los perfiles, un solo perfil con configuración, reconocimientos en el detalle de nómina y rachas que incluyen comprobantes recientes. Las fotos se reducen a PNG de hasta 500 KiB; se conservan las fotos anteriores con URL. Se usa la autorización de almacén que ya tiene Firestore; no hay cambios de reglas.

**Pendiente de publicar en el backend:** el registro manual de entrada, salida a comer, regreso y salida para los cuatro roles. El servidor de AppDeploy rechazó nuevas publicaciones por su cuota diaria (`CREDITS_USAGE_LIMIT_REACHED`) hasta `2026-09-29T00:00:00Z` (18:00 del 28 de septiembre en Ciudad de México). No se reintentó antes del reinicio. El código y las pruebas están en `tools/online-smart34/attendance.mjs` y `attendance.test.mjs`. Debe publicarse ese archivo como `backend/attendance.mjs`, previa lectura del snapshot actual e instrucciones de despliegue.

La web detecta `supportsManual: true` devuelto por el servidor antes de habilitar el nuevo flujo. Hasta que el backend se publique conserva el flujo de ubicación existente para trabajadores y muestra a los administradores que su registro sencillo sigue pendiente. **Compilar/publicar la web no activa por sí solo el cambio del servidor.**

El nuevo registro usa hora del servidor y conserva auditoría por usuario, duplicados idempotentes, correcciones administrativas y sincronización de nómina. Identifica la ubicación como no verificada y nunca inventa coordenadas. Los botones no guardan localmente horarios como si fueran confirmados. No requiere aprobar la comida cuando se utiliza explícitamente el nuevo registro manual; las solicitudes antiguas mantienen su autorización.

El historial administrativo se abre con los registros existentes y sincroniza en segundo plano; muestra un aviso persistente mientras haya movimientos sin confirmar. Los reportes finales siguen exigiendo una sincronización completa. Los importes y las reglas de cálculo de nómina no cambian. La vista personal muestra datos registrados, no un recibo emitido. Rachas e insignias se muestran como información sin efecto en el pago.

## Bloqueo externo observado y validación

El 28 de septiembre, a las 21:58 UTC, el navegador mostró el aviso del proveedor “This app is paused / This app has reached its credit limit”. La guía externa no acepta interacción mientras está pausada; esto explica el botón deshabilitado del chequeo de navegador. No se eludió la pausa ni se cambiaron cuotas, permisos o planes. El mismo servicio aloja jornadas y tareas, por lo que su disponibilidad debe comprobarse después del reinicio; no se promete reactivación automática.

La revisión pasó 121 pruebas Node, las pruebas aisladas de reglas, el análisis Flutter, 80 pruebas Flutter y la compilación web. El chequeo completo de navegador permanece fallido por la pausa externa; los chequeos posteriores de ese paso no se ejecutaron. La publicación web permite entregar fotos y vistas basadas en Firestore, pero no resuelve ni declara operativo ese servicio. Las pruebas conservan sus condiciones de éxito y el fallo externo no se marca como aprobado.

## Arquitectura publicada anteriormente

La web usa el backend autenticado ya desplegado de Online Smart. No necesita publicar `updateAttendance`, cambiar reglas de Firebase ni introducir credenciales administrativas.

## Jornada

- Inicio y Mi jornada guardan entrada, solicitud de comida, regreso y salida. El servidor asigna la hora de Ciudad de México y verifica el perfil actual. Los tres movimientos presenciales conservan las zonas existentes.
- Los comprobantes son persistentes e inmutables. Reintentos conservan una sola hora efectiva; no se muestran horas locales optimistas.
- Administración abre Asistencias para integrar los movimientos al expediente `asistencias/<uid>_<día>`. La integración usa su sesión actual y las reglas existentes, máscaras de campos y precondiciones de versión. No guarda el token ni modifica sueldos, bonos, multas o notas. Conserva correcciones ya aprobadas, incluso horas borradas por Administración.
- La autorización de comida usa hora del servidor. El regreso exige esa autorización. Una salida sin regreso conserva el horario real y señala la incidencia.
- El historial del trabajador incluye comprobantes aún pendientes de integración. El reporte de nómina actualiza primero su período; si falla, no genera un reporte incompleto. La pantalla informa cuando los horarios todavía no se han integrado a nómina.

La integración requiere que una sesión administrativa abra Asistencias o prepare su reporte. Esto no es un proceso de fondo con credenciales de servicio. Un APK anterior sigue usando sus endpoints antiguos hasta que se actualice; el cambio publicado corresponde a la web/PWA.

## Tareas del día

- Inicio y Tareas incluyen Tareas del día para todos los perfiles.
- Administradores y maestros pueden asignar a cualquier perfil activo; el servidor obtiene el nombre y rol actuales de Firebase. Las tareas de proyectos conservan su flujo y restricciones.
- La persona asignada adjunta JPG, PNG, WebP o PDF de hasta 2 MB por archivo, guarda avances y entrega con al menos una evidencia. Los archivos se guardan en el servicio existente; los enlaces privados se generan para destinatario, autor o Administración.
- Las asignaciones y entregas se confirman con lectura persistente. Una subida fallida conserva la tarea abierta y permite reintentar. Los comprobantes de asignación y progreso son inmutables.
- Las tareas diarias se consultan por fecha; la pantalla se actualiza al volver a la app, manualmente y cada 45 segundos mientras está abierta. Se confirma llegada al listado de la app, no entrega de notificación push.
- Capacidad acotada: hasta 80 tareas por día y 80 movimientos por tarea. Un límite o cuota produce un aviso explícito, nunca resultados vacíos engañosos.

## Verificación

Pruebas Node de jornadas y tareas con almacenamiento aislado, duplicados concurrentes, errores, límites de rol, dos actores y conservación del expediente. El emulador comprueba consultas de propiedad con cursor y permisos de escritura sin cambiar reglas. Pruebas Flutter cubren los cuatro controles, confirmación de salida, errores, perfiles y entrega con evidencia. No se crean cuentas ni registros laborales de prueba en producción.
