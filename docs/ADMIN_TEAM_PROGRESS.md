# Avances del equipo para Administración

La vista **Proyectos y tareas → Equipo** reúne las tareas del día, extras, actividades de proyectos, instalaciones y envíos. También se abre desde **Avances del equipo** en Inicio o mediante el acceso del resumen diario. Todos los perfiles administrativos activos pueden consultar las asignaciones, aunque las haya creado otro administrador o un maestro.

El resumen distingue tareas entregadas **por aprobar** de las **aprobadas y finalizadas**. El avance promedio usa los porcentajes de las tareas; las aprobaciones se cuentan por separado. Una entrega al 100 % no cuenta como aprobada hasta que Administración la revise. La sección **Por persona** permite ver el avance, las aprobaciones y los pendientes de cada integrante, incluidos quienes no tienen asignaciones en la selección.

La vista abre por defecto **Todas las fechas**, para conservar visibles las aprobaciones históricas. La persona y el estado se filtran directamente; **Más filtros** reúne departamento, proyecto, periodo y tipo. Los periodos se basan en la fecha de asignación e incluyen pendientes anteriores, también las entregas pendientes de aprobación. Los registros sin fecha conocida siguen visibles en Todas las fechas. Una entrega ya enviada no se marca vencida mientras espera revisión administrativa.

Al abrir una tarea se usa el detalle existente, con sus evidencias, historial y acciones de aprobación o solicitud de cambios. El panel se consulta al abrirlo, volver de un detalle y regresar a la app. También puede actualizarse con el botón o arrastrando la lista; conserva la hora de la última consulta. Una consulta fallida elimina las cifras anteriores hasta recuperar una respuesta completa. Las lecturas de copias locales se identifican para que no se presenten como información confirmada del servidor.

## Fuente y permisos

La acción interna `daily-admin-overview` usa exclusivamente Firestore. Todas las asignaciones se leen una sola vez por documento desde `actividades`; no se mezclan copias de las vistas diarias o de proyectos. El último porcentaje registrado en `avances` conserva los casos históricos cuyo porcentaje no se podía copiar al documento principal. Los nombres proceden de `usuarios`; departamentos de `rh_expedientes.area`, con los campos anteriores del perfil como alternativa. Los avances se consultan en lotes de ocho tareas. Las tarjetas de entregas y aprobaciones usan el estado confirmado al 100 %, y sus historiales completos se descargan al abrir el detalle, evitando repetir lecturas de todo el archivo histórico.

La sesión autenticada, el perfil activo y el rol administrativo se verifican antes de consultar el conjunto completo. Un identificador seleccionado o un rol enviado desde la interfaz no otorga acceso. Se descartan respuestas de otra sesión y se limpia la vista al cambiar de cuenta. Los demás perfiles conservan sus permisos existentes para sus asignaciones. Esta actualización no modifica las reglas de Firestore ni requiere publicar reglas nuevas; el arreglo anterior del selector de maestros tiene su propio paso de publicación pendiente.

## Validación

Las comprobaciones nuevas cubren estados, porcentajes, aprobaciones históricas, filtros combinados, personas sin tareas, recuperación tras errores, cambios de cuenta y apertura de evidencias e historial. Se revisaron las pantallas de teléfono y computadora con datos ficticios; la vista soporta 320 px con texto ampliado. Las pruebas de Firestore usan cuentas y proyectos aislados, sin tocar registros de producción.
