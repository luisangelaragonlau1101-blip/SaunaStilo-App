# Paneles personales y gestión por rol

Esta revisión mantiene la aplicación y el enlace existentes. No cambia reglas de Firebase, roles, cuentas ni permisos del teléfono.

- Apariencia: Stilo, rosa, rojo, oscuro, blanco, gris y morado. Preferencias por UID en este dispositivo, con opción de inicio sencillo y celebraciones. Cambiar de cuenta reinicia el estilo antes de cargar sus preferencias; no comparte preferencias ni datos laborales entre cuentas.
- Inicio: fotografía junto al nombre, rol, marca Sauna Stilo con sombra, una jornada y cinco accesos principales. La personalización se abre desde el saludo o Perfil. La fotografía se guarda como PNG acotado en el perfil autorizado y admite los enlaces anteriores.
- Temporadas: Año Nuevo, amistad, Independencia, Día de Muertos y diciembre. Cumpleaños tiene prioridad, contempla nacidos el 29 de febrero, cambia al medianoche de Ciudad de México y al volver a la app. Puede desactivarse sin cambiar datos de nacimiento.
- Proyectos y tareas: un solo acceso con actividades, tareas del día y proyectos. Administración crea proyectos/grupos y edita sus integrantes. Maestro conserva las restricciones de pertenencia a proyectos. Una persona asignada puede entregar una actividad pendiente o en progreso con descripción y evidencia. Las fotos se reducen a PNG de hasta 500 KiB por documento; no dependen de Storage. Archivos distintos a imágenes conservan su servicio anterior.
- Almacén: un solo acceso con existencias, fotos, solicitudes, préstamos, cajitas, entregas y devoluciones según rol. Solo Administración y Almacén gestionan existencias/movimientos.
- Ingeniería: panel visible solo con la designación `panelIngenieria`; no se infiere de nombres ni se otorga por elegir un color. Administración conserva el control de esa designación en Perfiles.
- Gestión de la empresa: exclusiva de Administración. Reúne Recursos Humanos, registro financiero interno, clientes, ventas, cotizaciones, proveedores, solicitudes, planificación personal, manuales, alerta y voz.
- Recursos Humanos: directorio de cuentas, expediente privado (`rh_expedientes`) con puesto, área, referencia de contrato, fecha de ingreso, notas y checklist de incorporación; acceso al alta de cuentas, horarios, asistencia/nómina, solicitudes y reconocimientos existentes. Los expedientes no se escriben en el perfil social visible al equipo.
- Libro financiero (`gestion_movimientos`): ingresos/egresos capturados manualmente, MXN en centavos enteros, filtros por mes y tipo, referencias, actor/hora del servidor e ID de reintento. Los totales incluyen solo ese libro; no duplican automáticamente ventas o nóminas y no realizan pagos.
- Se retiraron las opciones de videollamada individual y grupal, incluyendo el acceso a salas históricas de video. Las conversaciones, adjuntos y llamadas de voz se conservan.

## Límites que no deben presentarse como resueltos

El proveedor externo de jornadas/tareas del día/guía mostró pausa por límite de uso el 28 de septiembre. La consulta anónima de estado a su API devolvió HTTP 402 y APP_TEMPORARILY_UNAVAILABLE, sin acceder a empleados ni enviar registros. El despliegue de registro manual continúa pendiente de publicar `tools/online-smart34/attendance.mjs` como `backend/attendance.mjs` cuando termine el bloqueo informado hasta 2026-09-29T00:00:00Z. La web no simula guardados ni activa por sí misma ese servidor. Las actividades de proyecto y las nuevas vistas sobre Firestore son independientes de ese proveedor.

No hay integración con Siigo Aspel, no se importa su base y no se emiten CFDI, nómina timbrada, declaraciones fiscales ni pólizas contables. Esta revisión no sustituye todas las funciones de SAE/NOI/COI. El libro interno es un registro operativo, no una cuenta bancaria ni un balance contable consolidado.

La actualización es web/PWA. El APK anterior y su canal de firma no se modifican.

## Validación

Se prueban aislamiento de apariencia por usuario, contraste de siete paletas, cumpleaños/fechas límite, roles del menú, rechazo de Recursos Humanos antes de consultar datos para perfiles no administrativos, cantidades monetarias en centavos y reglas existentes con emuladores aislados. Se verifica que el dueño de una actividad puede guardar su evidencia y que terceros no pueden leerla; maestros y almacén no pueden leer ni escribir expedientes ni el libro financiero. No se usan registros laborales reales para probar.
