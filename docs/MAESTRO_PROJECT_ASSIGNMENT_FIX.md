# Asignación de actividades desde el perfil maestro

## Problema y corrección

La consulta del selector usa `proyectos.where('encargados', arrayContains: uid)`. La regla anterior exigía `encargados is list` además de pertenencia. El emulador confirmó que esa comprobación rechaza la consulta completa con `permission-denied`, incluso cuando abrir un documento asignado mediante GET sí funciona.

Se conservan los permisos GET existentes y se separa LIST, con `encargados.hasAny([request.auth.uid])`. Esta condición puede demostrarse desde el filtro de la consulta y exige una lista: no permite interpretar un mapa con el UID como si fuera una asignación. La consulta global continúa reservada a Administración.

El maestro sigue necesitando pertenecer al proyecto y elegir un integrante activo de ese proyecto. No puede asignar tareas generales, añadir integrantes por sí mismo, modificar proyectos ni consultar proyectos ajenos. El selector permite reintentar después de actualizar los permisos y diferencia una denegación del servidor de un fallo de conexión. Si el proyecto ya está abierto, asignar una actividad usa directamente ese proyecto; el formulario y la transacción vuelven a validar su acceso.

## Publicar los permisos del servidor

Publicar la web no publica las reglas de Firestore. El entorno actual no tiene una sesión Firebase autenticada (`firebase projects:list` devuelve falta de autenticación).

En el proyecto Firebase **saunastiloapp-17e15**, abrir **Firestore Database → Reglas**, reemplazar el contenido por el archivo completo `firestore.rules` de esta versión y pulsar **Publicar**. Después recargar STILO o pulsar **Reintentar** en el selector.

La publicación remota de esas reglas y el acceso de la cuenta real del maestro permanecen pendientes hasta ese paso. Las pruebas de permisos utilizan únicamente proyectos y cuentas ficticios en un emulador aislado; no se alteraron datos de personal ni proyectos de producción.

## Comprobaciones

- `tools/operations-security.test.cjs`: consulta asignada por rol, bloqueo de consultas globales/ajenas/anónimas, selección de equipo y creación transaccional por el maestro, rechazo de destinatarios ajenos y de formatos de membresía inválidos.
- `test/project_picker_test.dart`: recuperación del selector mediante una nueva consulta, devolución del proyecto elegido y acceso a Reintentar en 320 px con texto ampliado.
- Se mantienen las pruebas existentes de entrega, aprobación y cierre de actividades y proyectos.

Validación local: 21 pruebas de permisos, 108 pruebas Flutter existentes más 2 del selector, y 124 pruebas Node aprobadas.
