# Sauna Stilo 3.6 · Asignaciones claras y jornada completa

## Trabajo asignado y aportaciones
El personal destinatario marca avances y evidencia en sus tareas; no crea, edita ni se asigna tareas. Administración y maestros conservan la asignación autorizada por proyecto. Un solo acceso principal lleva a Proyectos y tareas; desde ahí se ven los grupos y un porcentaje calculado con todas las tareas completadas, no con reportes extra.

En Mi día se conservan comidas, compras, eventos e historial, con las mismas cuentas. Administración crea y edita las listas; la persona marca lo hecho y usa Lo que hice de más para reportar una actividad extra ya realizada o un faltante. Esos reportes viven por separado: no crean tareas, compras, asistencia ni puntos de proyecto. El servidor rechaza asignaciones y ediciones del destinatario, incluso desde una versión anterior. No se eliminan sus registros históricos.

## Comida
El Inicio de todo usuario no administrativo, incluido Mi día, muestra salida y regreso de comida. Solicitar comida usa solicitar_comida; regreso usa regreso_comida, con la validación existente del servidor. Administración tiene la solicitud en su bandeja. La última hora se considera registrada solo tras confirmación; el menú no inventa una autorización.

## Bandeja e Ingeniería
Administración tiene en Inicio una bandeja con solicitudes de herramientas, devoluciones y comida; además, solicitudes de idiomas/constancias y reportes extra. Las solicitudes se consultan aunque falle el push. Idiomas y reportes se consultan por páginas de ocho personas; los errores se presentan, nunca se interpretan como ausencia de solicitudes. El aprendizaje requiere su aprobación habitual.

Administración puede activar Panel de Ingeniería desde el perfil de la persona seleccionada. Ingeniería registra producción, calidad, tiempos y mejoras con mediciones e historial. Opcionalmente, el control Gestión operativa de Almacén concede, con confirmación, el rol de almacén ya existente; no concede administración completa ni acceso a ventas, cuentas o sueldos. No se asignan privilegios por nombres, ni se modifica automáticamente la cuenta de Ángel, Osiris Naomi, Anahí o cualquier otra persona.

## Notificaciones y voz
La consulta pasiva del permiso no vuelve a solicitarlo en cada inicio. El aviso de invitación se recuerda por cuenta/dispositivo; la reconexión de Firestore no dispara una pregunta de permisos. Notificaciones y sonido permite registrar de nuevo el teléfono y probar tres segundos de sonido local, sin enviar avisos al equipo.

Esto NO demuestra que el servidor FCM existente esté desplegado o entregando avisos. No se publicaron Firebase Rules, Cloud Functions ni una nueva aplicación Android en Firebase. La recepción remota y en segundo plano, el volumen del teléfono y los permisos requieren verificación en dispositivos reales. La alarma general existente se conserva, no se dispara durante QA.

Online Smart muestra respuestas completas sin asteriscos ni encabezados Markdown. Escuchar divide la respuesta completa en fragmentos, sin cortar la última frase. El interruptor Responder también con voz es opcional y usa la voz del dispositivo; se detiene al salir de la vista. No se activa voz clonada.

## Entrega Android
El APK definitivo de esta entrega debe usar com.saunastilo.personal, etiqueta Sauna Stilo Nueva y exactamente el certificado 716e331c62be7c4055e8217ebf771da716ed13c87e10bf55bb98f608625b80bf. El material privado no se sube a GitHub ni AppDeploy: se firma en el entorno privado del propietario después de compilar. Una coincidencia de nombre no sustituye la comprobación de firma. Conserva los datos de la edición 3.5.1 al ser una actualización de esa misma identidad; no migra los datos de la edición antigua com.saunastylo.saunastylo.

Registrar las pruebas reales de la entrega antes de distribuir. No declarar probados teléfonos físicos, inicio de sesión de empleados ni recepción push sin haberlo comprobado. Los registros de prueba son aislados, sin usuarios, alarmas, compras ni eventos reales de empresa.
