# Activar IA y voz de Sauna Stilo

La web y Firebase se publican por separado. El enlace existente es https://sauna-stilo-app-web.vercel.app/.

El 28 de septiembre de 2026, `version.json` entregaba la versión 3.6.0, commit `f3529c0c23a9f0b1914789611ceef910bcb08e6e`. Los endpoints configurados de `saunaAssistantV2` y `getAdminVoiceStatus` respondían HTTP 404. Recargar la web no publica esos servicios.

## Publicación

Abre [el repositorio en Google Cloud Shell](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Fluisangelaragonlau1101-blip%2FSaunaStilo-App.git&cloudshell_open_in_editor=docs%2FACTIVAR_IA_Y_VOZ.md) con una cuenta autorizada para `saunastiloapp-17e15`. Desde la carpeta del repositorio ejecuta:

```bash
bash tools/activate-ai-voice.sh
```

Requiere Node.js 22 o posterior. El script comprueba el proyecto y la facturación existente, instala las dependencias, valida las exportaciones y publica solamente IA, voz y el emisor de notificaciones. Habilita las APIs necesarias; el uso de Google Cloud puede generar cargos. No publica reglas, nómina ni recordatorios y no crea usuarios o grabaciones. Si Firebase pide autorización, complétala en Google; no compartas claves o códigos por chat.

Un resultado HTTP 401 con `UNAUTHENTICATED` confirma que los dos endpoints existen y rechazan llamadas anónimas. No demuestra todavía que el modelo responda o que la voz esté disponible para el proyecto. Si una operación falla por permisos, revisa la identidad de ejecución y los permisos necesarios en Google Cloud; no sustituyas esa identidad por claves descargadas.

## Comprobación desde la aplicación

1. Abre Guía: debe seleccionar directamente Guía web. El asistente público y el asistente de manuales tienen servicios distintos de Sauna IA v2.
2. En Administración > Estudio de voz, toca Comprobar servicio. Graba el consentimiento y la referencia de tu voz; después crea y prueba la voz.
3. Desde una respuesta del asistente interno, toca Escuchar · voz de Ángel. También está disponible el botón de voz en la guía web. La voz del dispositivo se identifica por separado.
4. Prueba los avisos con dos teléfonos autorizados: app abierta, en segundo plano y pantalla bloqueada. No envíes una alerta general como prueba.

La publicación de Functions no equivale a la autorización del proveedor para Instant Custom Voice ni a una prueba de sonido en un teléfono físico. Revisa [la documentación de Google sobre Instant Custom Voice](https://docs.cloud.google.com/text-to-speech/docs/chirp3-instant-custom-voice) y [el despliegue de Functions](https://firebase.google.com/docs/functions/get-started?gen=2nd).
