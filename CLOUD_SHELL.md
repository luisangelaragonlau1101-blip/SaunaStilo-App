# Sauna Stilo: activar las funciones pendientes

La versión web contiene perfiles con insignias/lugares, cumpleaños en lista con gustos/colores, préstamos por chat, justificación de faltas y captura de voz a velocidad normal. Publicar la web no publica las reglas ni los servicios Firebase. Online Smart funciona en su alojamiento independiente y no obtiene acceso a tus expedientes ni a tu voz personalizada.

## Cuenta autorizada y revisión

Abre Google Cloud Console con la cuenta propietaria de `saunastiloapp-17e15` y abre Cloud Shell. Una vista de repositorio en un entorno temporal sin credenciales no es una sesión autorizada. No compartas contraseñas, tokens ni claves privadas. Usa Node.js 22 o posterior.

Desde el repositorio actualizado, revisa `tools/activate-team-services.sh`, `firestore.rules` y `storage.rules`. La activación reemplaza ambas reglas por esta versión y habilita recordatorios de jornada; pueden llegar avisos al equipo en sus horarios. Si existen cambios de reglas en la consola que no están en GitHub, cancela y reconcilia primero. No se crea una cuenta de cobro, pero el uso del servidor puede generar cargos.

## Activar operación, perfiles y evidencias privadas

Ejecuta dentro del repositorio:

```sh
bash tools/activate-team-services.sh
```

Escribe `saunastiloapp-17e15` solamente después de revisar el alcance. Si Firebase CLI no reconoce tu sesión, autentícate con `npx firebase-tools login --no-localhost` siguiendo el flujo oficial en el navegador; no compartas sus códigos. Si aparece un error de permisos o facturación, detente y revisa la cuenta. No agregues permisos a ciegas.

Este paso publica entrada/salida y entrega de avisos, tres programadores de recordatorios y reglas de Firestore/Storage. No publica la implementación alternativa `repeatWorkdayReminders` porque duplicaría avisos. No se registran asistencias ni se envían alarmas de prueba por el script.

## Activar el servidor de voz por separado

Grabar y escuchar muestras es local y no necesita activar el servidor. Para crear una voz sintética, revisa y ejecuta:

```sh
bash tools/activate-voice-service.sh
```

También pide confirmación del proyecto. Solo publica `getAdminVoiceStatus`, `enrollAdminVoice`, `synthesizeAdminVoice` y `setAdminVoiceEnabled` y habilita APIs. No graba, clona ni sube muestras. Google mantiene Instant Custom Voice restringido a cuentas autorizadas: publicar funciones no concede ese acceso. La aprobación del proveedor y las grabaciones reales de consentimiento/referencia siguen siendo necesarias. No se presenta la voz del dispositivo de Online Smart como si fuera la de Ángel.

## Comprobar antes del uso oficial

Administración: Inicio → Administrar perfiles → persona → agregar y quitar insignia/lugar. Propietario: Perfil → Lo que me gusta → guardar intereses/colores y verificar tras volver a abrir. Cumpleaños: lista, filtro y búsqueda. Trabajador: Justificar una falta → motivo/foto → verificar que quede pendiente y privada, sin modificar horas. Préstamo: solicitar → compañero recibe el chat → ambos confirman entrega/recepción en Mi cajita. Solicitar no cambia automáticamente la custodia.

Prueba con dos cuentas autorizadas y teléfonos reales: chat, notificación dirigida, app abierta/segundo plano/bloqueada, entrada/salida y que los recordatorios se detengan al registrar. Nunca consideres entregada una notificación solo porque fue registrada o aceptada por FCM. El teléfono controla el volumen y Silencio/Enfoque; la web no es un sistema único de emergencia.

En Estudio de voz: graba y escucha primero; verifica duración y tono en Safari. Solo después de activar el servidor y obtener autorización del proveedor crea la voz y prueba una respuesta real. Online Smart incrustada conserva la voz del dispositivo y no realiza búsqueda web ni acciones privadas por sí misma.
