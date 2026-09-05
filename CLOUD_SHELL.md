# Activar IA, Internet y voz de Sauna Stilo

Este paso usa tu cuenta de Google para publicar los servicios del proyecto existente `saunastiloapp-17e15`. No compartas contraseñas ni claves privadas. Abrir este tutorial no despliega nada automáticamente.

## Revisar la activación

El archivo `tools/activate-services.sh` verifica el proyecto y la facturación, pide confirmación y publica únicamente los servicios de IA, voz y envío push. Habilita las APIs necesarias. El uso de Google Cloud puede generar cargos. No modifica reglas de seguridad, usuarios ni datos de la empresa y no activa una nueva cuenta de cobro.

Revisa el script en el editor antes de continuar. La cuenta de Google debe estar autorizada para administrar el proyecto.

## Ejecutar

En la terminal del repositorio ejecuta:

```sh
bash tools/activate-services.sh
```

Cuando lo solicite, escribe `saunastiloapp-17e15` para confirmar. Si aparece una solicitud de autorización de Cloud Shell, revisa los permisos y autorízala solamente con la cuenta propietaria del proyecto. Ante un error de permisos o facturación, el script se detiene: no continúes cambiando permisos a ciegas.

## Comprobar en la aplicación

Abre la aplicación habitual e inicia sesión. Pulsa `Probar IA`, prueba una consulta pública con fuentes y verifica el acceso con roles diferentes. La Guía de uso básica funciona sin el motor de IA; el resto de las consultas necesita el servidor.

Para personalizar la voz, entra como administrador a `Estudio de voz`, graba el consentimiento y la muestra de tu propia voz y confirma su creación. Google debe autorizar Instant Custom Voice para este proyecto. Hasta entonces, las respuestas de voz usan la voz del dispositivo. Que el despliegue termine no garantiza que los permisos del modelo o de voz estén listos.

Para avisos, prueba con dos cuentas y teléfonos: app abierta, segundo plano y pantalla bloqueada. Las llamadas actuales son invitaciones a una sala externa; no son llamadas nativas CallKit. Nunca supongas entrega o sonido solo por una confirmación de envío.
