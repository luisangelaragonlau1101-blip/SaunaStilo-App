# Sauna Stilo: activar asistencia, avisos y tareas del maestro

La aplicación web y el servidor no se publican con el mismo proceso. Online Smart funciona en su alojamiento independiente; no necesita activar la antigua función Gemini para orientar sobre la app. El registro de entrada/salida, los recordatorios y los nuevos permisos de tareas sí necesitan Firebase.

## Abrir con la cuenta propietaria

Abre este repositorio en Google Cloud Shell usando la cuenta autorizada de `saunastiloapp-17e15`. No compartas contraseñas, claves privadas ni tokens. Este tutorial no despliega nada al abrirse.

Revisa `tools/activate-team-services.sh` y `firestore.rules`. El script publicará servicios concretos y reemplazará las reglas Firestore por la versión revisada del repositorio. No modifica usuarios ni documentos empresariales, pero habilita recordatorios que pueden notificarse al equipo según su horario. Si modificaste reglas en la consola y no están en GitHub, reconcilia esas diferencias antes de publicar.

## Ejecutar una vez

En la terminal, dentro del repositorio:

```sh
bash tools/activate-team-services.sh
```

Escribe `saunastiloapp-17e15` cuando pida confirmación. El script utiliza Firebase CLI mediante npm, requiere Node 22 y se detiene si no tiene acceso al proyecto o no puede verificar facturación activa. No habilita una nueva cuenta de cobro. Google Cloud puede cobrar por uso.

Si Cloud Shell pide autorización, revisa los permisos con la cuenta propietaria. Si aparece un error de acceso, no pegues secretos ni cambies permisos a ciegas. La activación de IA de Google y de voz personalizada está separada y no forma parte de este comando.

## Comprobar el resultado

En Inicio, Jornada tiene Registrar entrada y Registrar salida. La hora solo se considera registrada cuando el servidor lo confirma, desde las ubicaciones autorizadas. El maestro asigna desde Tareas y únicamente a integrantes de su proyecto. En Chats abre Personas o Por proyecto; el aviso personal muestra su contenido dentro de la app autenticada y la notificación del sistema usa una vista previa genérica.

Los recordatorios revisan cada 15 minutos durante la primera hora posterior al horario de entrada, comida o salida, con un máximo de cuatro avisos; se detienen cuando el registro correspondiente aparece. No publiques `repeatWorkdayReminders` junto con `reminderEntrada`, `reminderComida` y `reminderSalida`, porque son implementaciones alternativas.

Haz una prueba acordada con dos teléfonos, primero con app abierta y después en segundo plano y bloqueado. Cada teléfono debe autorizar notificaciones. El sistema operativo controla sonido, volumen y Enfoque. Las llamadas son invitaciones a una sala de comunicación; no son telefonía nativa ni alertas críticas del sistema.

Online Smart permite preguntar, dictar cuando el navegador lo admite y escuchar con la voz del dispositivo. No consulta expedientes privados, registra acciones ni realiza búsqueda web en tiempo real. La voz personalizada de Ángel requiere su grabación y el servicio específico habilitado; la voz del dispositivo no se presenta como la suya.
