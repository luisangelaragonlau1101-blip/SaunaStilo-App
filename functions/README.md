# Sauna Stilo · Servicios de IA y notificaciones

Proyecto existente: `saunastiloapp-17e15`; región: `us-central1`.
El proveedor del asistente es Gemini mediante Google Cloud y `@google/genai`.
NO se utiliza `OPENAI_API_KEY`. Nunca colocar claves privadas en Flutter, GitHub ni chats.

## Publicación por un administrador autorizado

1. Confirmar el proyecto Firebase, facturación habilitada y API de IA correspondiente habilitada en Google Cloud.
2. Comprobar la identidad de servicio que ejecuta `saunaAssistant`, su acceso al motor (Vertex AI User o permisos equivalentes mínimos), Firestore y el modelo configurado. No descargar claves de cuenta de servicio: usar la identidad de ejecución administrada.
3. Desde esta carpeta: `npm ci`. El modelo predeterminado es `gemini-3.7-flash`; `GEMINI_MODEL` y `GOOGLE_CLOUD_LOCATION` se pueden configurar en el entorno del proyecto. No inventar un identificador de modelo.
4. Desde la raíz del repositorio, con la sesión autorizada de Firebase CLI:

```sh
firebase deploy --project saunastiloapp-17e15 --only functions:saunaAssistant,functions:sendSaunaStiloNotification
```

El comando actualiza exclusivamente esos dos servicios. No publica las demás tareas programadas ni cambia reglas, usuarios o datos. La cuenta debe tener los permisos mínimos de despliegue correspondientes. Esta revisión del código NO prueba que los servicios ya estén desplegados.

## Verificación

`node --test tests/*.test.cjs` desde la raíz valida las regresiones de receptor, caché y política del servidor con dobles de prueba. La compilación Flutter se valida con GitHub Actions.

En la app, un usuario autenticado debe pulsar **Probar IA** y recibir una respuesta real. Comprobar después, con dos roles distintos, que un trabajador no puede consultar clientes/cotizaciones reservados. El servidor vuelve a comprobar el rol; los límites son 8 solicitudes/minuto y 150/día por usuario. Los adjuntos admitidos deben pertenecer a `media/<uid>/` del usuario autenticado. El contexto es una muestra limitada de registros, no todos los datos de la empresa.

Para push: instalar en inicio en iPhone, abrir desde el icono y pulsar **Activar avisos**. Con dos dispositivos/cuentas, probar mensaje y llamada: app abierta, segundo plano y pantalla bloqueada. Tocar la notificación debe abrir el buzón de la misma app; desde una notificación privada se accede a Mensajes. Repetir después de actualizar y de cerrar sesión/cambiar de usuario.

Una aceptación por FCM no confirma sonido/visualización. La app web no implementa PushKit/CallKit ni timbrado VoIP continuo; Enfoque, silencio, conectividad y permisos del sistema afectan la entrega. Las llamadas actuales son invitaciones a salas de reunión externas, no llamadas nativas. La compilación APK y las pruebas físicas Android/iPhone siguen siendo verificaciones separadas.

## Documentación primaria consultada

- https://firebase.google.com/docs/cloud-messaging/web/receive-messages
- https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- https://ai.google.dev/gemini-api/docs/latest-model
- https://googleapis.github.io/js-genai/
