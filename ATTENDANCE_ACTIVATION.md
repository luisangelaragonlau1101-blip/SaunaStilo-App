# Activar la jornada de Sauna Stilo

Esta reparación es del servidor. Conserva el APK 3.6 y la misma página. No desinstales la aplicación.

## Autorizar y ejecutar

Abre la terminal de este repositorio en Google Cloud Shell, con la cuenta de Google que administra `saunastiloapp-17e15`. Ejecuta:

```bash
bash tools/activate-attendance.sh
```

Escribe `ACTIVAR` únicamente después de leer el alcance. Google puede pedir autorización de Cloud Shell o de Firebase. No envíes contraseñas, claves JSON ni códigos de acceso por chat.

El script publica entrada, solicitud de comida, regreso y salida en el mismo registro `asistencias/<persona>_<fecha de México>`. Conserva la aprobación de comida en la pantalla actual de Administración. Los nuevos avisos se guardan para la persona y para Administración; se usa el servicio FCM existente para intentar la entrega al teléfono.

Solo añade el índice de persona y fecha si falta. No reemplaza reglas, no elimina índices, no borra registros y no modifica salarios, bonos o descuentos. No activa horarios de avisos adicionales. Requiere facturación previamente habilitada por el propietario; no cambia ni contrata un plan. Las funciones y el índice pueden generar consumo en Google Cloud.

## Comprobación real

Usa una cuenta trabajadora real únicamente para registrar su jornada real: Entrada → Solicitar comida → aprobación desde Administración → Regreso → Salida. Los horarios deben verse en Asistencias y en el historial utilizado por Nómina, sin crear otro día ni otra base de datos.

Reintentar un movimiento conserva su hora original. Solicitar comida no equivale a que ya se autorizó. La salida no se inventa ni se registra por cerrar la aplicación. Un regreso faltante queda para revisión. Las zonas de asistencia se conservan; la casa u otra instalación necesita una zona autorizada antes de registrar desde allí.

## Estado y límites

El código y sus pruebas no prueban que tu Firebase esté activado. Solo se considera publicado cuando el despliegue termina y la comprobación anónima responde 401. Eso tampoco prueba recepción push en un teléfono: hay que verificar permisos, registro del dispositivo y recepción con ambas cuentas. Los datos sin conexión no se presentan como confirmados por el servidor.

El reporte de Nómina ya consulta la colección de Asistencias. Esta reparación conserva sus campos y su fórmula anterior; el resumen nuevo de minutos es informativo y no determina por sí solo el sueldo, deducciones o pago de comida. Se deben revisar las incidencias antes de usar el cálculo como nómina definitiva. No se envían alarmas generales ni se crean marcajes ficticios durante el script.
