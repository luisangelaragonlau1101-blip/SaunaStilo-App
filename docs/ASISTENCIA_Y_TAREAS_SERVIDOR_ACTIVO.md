# Asistencia y tareas con el servicio existente

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

Pruebas Node de jornadas y tareas con almacenamiento aislado, duplicados concurrentes, errores, límites de rol, dos actores y conservación del expediente. El emulador comprueba consultas de propiedad y permisos de escritura sin cambiar reglas. Pruebas Flutter cubren los cuatro controles, confirmación de salida, errores, perfiles y entrega con evidencia. No se crean cuentas ni registros laborales de prueba en producción.
