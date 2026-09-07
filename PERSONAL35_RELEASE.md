# Sauna Stilo 3.5 · Mi día para personal

## Activación por Administración
Administrar perfiles → seleccionar una cuenta activa con rol trabajador → Panel personal · Mi día → confirmar. No se crea un rol chef ni se cambia la cuenta, horario, sueldo o permisos comerciales. El campo panelPersonal es administrado mediante las reglas existentes de perfiles; el servidor lo vuelve a leer con la sesión Firebase verificada. No se activa para nadie automáticamente.

Organizar su día, en el mismo perfil, abre su plan. También está Todas las opciones → Organizar al personal. Solo la cuenta destinataria habilitada y Administración pueden consultar o cambiar su planificación privada; maestros, almacén y otros integrantes no obtienen acceso.

## Plan compartido
Mi plan: comidas con hora, cantidad/porciones e indicaciones; pendientes del hogar con casillas. Compras: anotar faltantes, cantidades/unidades y marcar artículos comprados. Eventos: fecha, hora, invitados, temática, menú, indicaciones y lista de preparativos marcables. La persona puede agregar actividades propias y Administración asignarle actividades. Puede completar lo asignado, pero no editar o retirar instrucciones creadas por Administración. Al retirar una actividad se conserva su historial.

Las nuevas actividades se guardan en el servidor privado de Online Smart. Cada cambio lleva su actor y fecha; se conservan registros inmutables y las casillas completadas se tachan después de recibir confirmación, no antes. Actualizar, deslizar hacia abajo o regresar a la app permite consultar cambios del otro usuario; no se presenta como mensajería push ni sincronización instantánea. No se mandan alarmas ni avisos a todo el equipo por estas tareas.

El selector de fecha permite preparar próximos días y revisar días anteriores. Eventos muestra desde la fecha seleccionada hasta fin del mes siguiente; para fechas posteriores hay que cambiar de mes. Cada día y cada mes de eventos admite hasta 190 movimientos en esta primera entrega; si el historial está lleno o paginado, el servidor rechaza operar sobre datos incompletos sin borrar nada. Los cambios simultáneos quedan registrados; el último cambio sobre un mismo campo determina su estado, sin perder actualizaciones de otros campos. No hay migración de actividades laborales existentes a este panel.

## Jornada y beneficios
El Inicio personal conserva la tarjeta de asistencia existente, rachas e insignias y todas las opciones de su cuenta, incluidas Comunidad, Chats, tareas de proyectos, juegos, idiomas con autorización y Online Smart. Al completar sus pendientes se reconoce el avance, pero no se cambia su asistencia. Después de confirmar una salida real mediante updateAttendance aparece “¡Terminaste tu jornada laboral! Excelente trabajo”. Requiere el servidor de asistencia, conexión, ubicación autorizada y sus permisos existentes; no se inventa una nueva zona del hogar ni una jornada registrada.

## IA
Organizar mi día con la IA pide confirmación antes de utilizar las comidas, compras y pendientes de la fecha. Solo se envía su plan autorizado y los fragmentos publicados de manuales permitidos para su rol. Las sugerencias no hacen compras ni modifican actividades. La IA pública anterior y el servicio de idiomas/constancias se mantienen sin cambios. La voz personalizada no se activa.

## Validación y límites
Pruebas de servidor en memoria: aislamiento por cuenta, habilitación administrada, dos actores asignando y completando, historial, reintentos idempotentes, eventos, fechas inválidas, cuotas y consentimiento de IA. Pruebas Flutter: accesos por rol, tachado confirmado, errores sin falsos completados, formulario que conserva texto, felicitación que no simula una salida y ocultación de la configuración a no administradores. Pruebas de reglas de perfiles en emulador, sin editar producción. No se modifican empleados ni compras reales durante QA. Falta aceptación física con las cuentas y teléfonos del personal.

No se publican Firebase Rules, Cloud Functions, facturación ni autorizaciones de voz. El guardado del nuevo plan necesita Internet; su confirmación no se simula sin conexión. Los borradores generales y juegos locales anteriores conservan su funcionamiento. APK interno con firma de desarrollo; no equivale a una distribución Play Store ni garantiza actualización sobre otra firma.
