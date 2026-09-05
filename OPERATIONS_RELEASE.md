# Sauna Stilo · operaciones diarias

## Interfaz
Inicio coloca jornada, entrada/salida, tareas y rachas antes que el menú completo. Navegación persistente: Inicio, Proyectos, Comunidad, Chats, Perfil. Todos los accesos por rol se conservan y Administración conserva ALERTA GENERAL. La identidad usa el logo existente, negro, vino y verde; los controles de mensajes son de trazo limpio.

## Mensajes y llamadas
Personas tiene botones separados para escribir y llamar. El chat conserva textos, fotos, videos, archivos, notas de voz y emojis. Añade dictado de texto y un aviso personal de pantalla. Las invitaciones abren salas externas; no se implementa telefonía nativa. El contenido privado se guarda en la conversación y el documento general de notificación solo anuncia que existe un mensaje. El sonido foreground respeta el permiso de audio; una llamada personal deja de timbrar al salir, confirmar o cumplir su límite.

## IA
Los accesos de Inicio y su menú abren Online Smart incrustada en su origen, utilizando el cliente de AppDeploy que ya emplea la guía. No pasan credenciales Firebase, expedientes ni tokens. El análisis Firebase anterior permanece en el código, pero no se presenta como conectado. La voz de la guía es la del dispositivo, no una clonación de Ángel. No se promete búsqueda web en vivo cuando el proveedor no la realiza.

## Servidor pendiente de activación autorizada
No se han publicado funciones Firebase ni se han cambiado reglas, usuarios o facturación desde esta entrega. Un despliegue web no habilita estos servicios:

- `updateAttendance`: registro server-side de entrada, comida y salida.
- `assignProjectActivity`: maestro/admin asigna a integrantes de sus proyectos. El backend verifica perfiles y pertenencia, no el rol enviado por el navegador.
- `sendSaunaStiloNotification`: entrega FCM de los avisos registrados.
- `reminderEntrada`, `reminderComida`, `reminderSalida`, `repeatWorkdayReminders`: avisos en el horario y hasta tres seguimientos de 15 minutos, solo mientras falta el registro, respetando sábado/turno. No temporizadores de navegador intentando funcionar cerrados.

Con una sesión propietaria autorizada, revisar facturación/APIs y ejecutar desde el repositorio:

```sh
firebase deploy --project saunastiloapp-17e15 --only functions:updateAttendance,functions:assignProjectActivity,functions:sendSaunaStiloNotification,functions:reminderEntrada,functions:reminderComida,functions:reminderSalida,functions:repeatWorkdayReminders
```

Este comando no se ha ejecutado aquí. Puede implicar cargos del proveedor. No compartir credenciales en el chat.

## Verificación requerida
Los tests automáticos de políticas y navegación no prueban cuentas reales ni sonidos en teléfonos. Probar con dos cuentas autorizadas: abrir chat existente desde ambos lados, texto/foto/audio, aviso de pantalla, invitación, permisos rechazados, segundo plano y bloqueo. Probar maestro en proyecto propio y ajeno, asignación duplicada y trabajador externo. Probar primera entrada sin registro previo, ubicación denegada, salida y recordatorios que se detienen después del registro. No se envían alarmas a empleados como parte de CI.

La app web no controla el volumen físico ni ignora Silencio/Enfoque. No usarla como único sistema de emergencia.
