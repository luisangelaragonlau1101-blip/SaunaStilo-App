# Sauna Stilo · IA, Guía, voz y notificaciones

Proyecto existente: `saunastiloapp-17e15`; región de Cloud Functions: `us-central1`.

La aplicación conserva sus servicios actuales y agrega **Sauna IA v2**, **Guía Inteligente con Google Search** y **Estudio de Voz de Administración**. No colocar secretos ni claves de cuenta de servicio en Flutter, GitHub o chats.

## Sauna IA y Guía con Internet

`saunaAssistantV2` utiliza `@google/genai` sobre Vertex AI. Cuando la app envía `usarInternet: true`, el servidor habilita la herramienta `googleSearch`. Los permisos de información interna no cambian por usar Internet: el servidor vuelve a leer el rol autenticado y construye solamente el contexto autorizado.

La Guía usa el modo `guia` del mismo servicio y está orientada a indicar qué módulo abrir y qué pasos seguir. Los resultados de Google Search se devuelven como fuentes web para que la app pueda mostrar enlaces de consulta.

El modelo puede configurarse con `GEMINI_MODEL`; el valor debe corresponder a un modelo realmente disponible para el proyecto. `GOOGLE_CLOUD_LOCATION` usa `global` por defecto.

## Voz oficial de Administración

El Estudio de Voz solo aparece para el rol `admin`. Graba dos archivos mono de hasta 10 segundos: consentimiento y muestra de referencia. El consentimiento en español debe decir exactamente:

> Soy el propietario de esta voz y doy mi consentimiento para que Google la utilice para crear un modelo de voz sintética.

El servidor usa Chirp 3 Instant Custom Voice de Cloud Text-to-Speech para solicitar una `voiceCloningKey` y guarda la configuración en Firestore. La aplicación Flutter no recibe la clave en sus respuestas. Para hablar, el cliente solicita audio a `synthesizeAdminVoice`; si la voz personalizada no está disponible, IA y Guía conservan como respaldo el TTS del dispositivo.

**Importante:** Instant Custom Voice es un servicio de acceso restringido por Google. El código puede estar publicado correctamente y aun así devolver `failed-precondition` hasta que el proyecto esté autorizado para usar esa función.

## Publicación por una cuenta autorizada

1. Confirmar facturación y APIs necesarias en Google Cloud: Vertex AI y Cloud Text-to-Speech.
2. Comprobar que la identidad administrada de ejecución tenga acceso mínimo a Vertex AI, Firestore y Text-to-Speech. No descargar claves JSON de cuenta de servicio.
3. Desde `functions/`, ejecutar `npm ci`.
4. Desde la raíz del repositorio, con Firebase CLI autenticado en el proyecto correcto:

```sh
firebase deploy --project saunastiloapp-17e15 --only functions:saunaAssistantV2,functions:getAdminVoiceStatus,functions:enrollAdminVoice,functions:setAdminVoiceEnabled,functions:synthesizeAdminVoice,functions:sendSaunaStiloNotification
```

Este comando publica únicamente los servicios nombrados. No cambia usuarios, datos ni reglas de Firestore. Tener el código en GitHub no prueba que estas funciones ya estén desplegadas.

## Verificación obligatoria

Desde la raíz:

```sh
node --test tests/*.test.cjs
```

GitHub Actions también ejecuta comprobaciones de sintaxis Node y compila Flutter Web en release.

Después del despliegue, probar en cuentas distintas:

- **Admin:** Sauna IA puede consultar proyectos/clientes/cotizaciones autorizados y mostrar fuentes web cuando use Internet.
- **Trabajador:** Sauna IA y Guía no deben exponer clientes, cotizaciones ni datos administrativos.
- **Guía:** preguntar dónde registrar asistencia, cómo pedir herramientas y una pregunta externa actual; las tres deben producir respuestas reales.
- **Voz:** grabar consentimiento y muestra desde Administración, crear la voz, probarla y después escuchar una respuesta de IA y de Guía.
- **Push:** con dos dispositivos, probar app abierta, segundo plano y pantalla bloqueada; repetir después de actualizar y después de cerrar/cambiar sesión.

Una aceptación por FCM no garantiza sonido o visualización en todos los estados. Enfoque, silencio, permisos y restricciones del sistema siguen afectando la entrega; la PWA no equivale a PushKit/CallKit de una aplicación VoIP nativa.

## Documentación primaria

- https://cloud.google.com/vertex-ai/generative-ai/docs/samples/googlegenaisdk-tools-google-search-with-txt
- https://cloud.google.com/text-to-speech/docs/chirp3-instant-custom-voice
- https://firebase.google.com/docs/cloud-messaging/web/receive-messages
- https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
