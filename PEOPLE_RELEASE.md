# Sauna Stilo · perfiles, cumpleaños, herramientas y voz

## Cambios
- Inicio: préstamos, justificar faltas, cumpleaños y equipo quedan a un toque. El bloque destacado de IA se retira; Online Smart sigue en el menú completo.
- Administración: Inicio → Administrar perfiles → persona → agregar insignia o lugar de instalación. Se conservan los logros automáticos y proyectos anteriores.
- Cada persona: Perfil → Lo que me gusta → editar intereses y colores. Es opcional y visible para compañeros autenticados.
- Cumpleaños: lista ordenada por próxima fecha, búsqueda y filtro de mes; sin mostrar edad ni año de nacimiento. Los 29 de febrero se observan el 28 en años no bisiestos.
- Préstamos: solicitar crea un mensaje privado con aviso dirigido; Mi cajita conserva entrega, recepción y devolución confirmadas. Registrar el aviso no garantiza la recepción del teléfono.
- Faltas: motivo y foto opcional, historial, transacción que conserva horarios. Evidencias nuevas en justification_evidence, solo propietario/Administración. Los archivos históricos no se migran automáticamente.
- Voz web: captura con frecuencia real y remuestreo a 24 kHz antes de generar WAV; no reetiqueta audio de 44.1/48 kHz. Escucha a velocidad 1.0 y libera micrófono al salir.

## Activación y límites
La publicación web no despliega reglas de Firestore/Storage ni Cloud Functions. Para guardar gustos, primera justificación y evidencia privada se deben revisar y publicar las reglas de esta versión con la cuenta autorizada. No se publican ni se borran datos de empresa durante CI.

Desde una sesión propietaria, reconciliar primero cualquier regla editada fuera de GitHub y ejecutar:

```sh
firebase deploy --project saunastiloapp-17e15 --only firestore:rules,storage
```

Asistencia y FCM requieren sus funciones de servidor; consultar CLOUD_SHELL.md. La voz personalizada requiere getAdminVoiceStatus/enrollAdminVoice/synthesizeAdminVoice publicados y autorización de Google para Instant Custom Voice. No se cambia facturación ni se solicitan secretos en el chat.

La grabación corregida no equivale a tener una voz sintética activada. Antes de uso oficial faltan pruebas con dos cuentas autorizadas y teléfonos reales: alta/baja de insignias, guardado de gustos, préstamo/recepción/devolución, evidencia de falta, grabación Safari, creación de voz y llegada de notificaciones en segundo plano.
