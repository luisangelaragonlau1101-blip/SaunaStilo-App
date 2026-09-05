# Activación real de servicios

Comprobación de solo lectura del 5 de septiembre de 2026: `updateAttendance` y `saunaAssistantV2` devuelven HTTP 404 a una petición vacía no autenticada. No se registraron horarios ni se enviaron alertas reales. El disparador `sendSaunaStiloNotification` respondió 403 como endpoint no público; ese resultado no demuestra fallo ni éxito de entrega.

La interfaz de Online Smart fue actualizada en AppDeploy. La asistencia y los recordatorios recurrentes requieren desplegar servicios con la cuenta autorizada de Firebase/Google Cloud. Las tareas creadas por maestros requieren además las reglas validadas. No presentar esos servicios como operativos solo porque compile o se publique Flutter.
