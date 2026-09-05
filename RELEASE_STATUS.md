# Entrega de la versión futurista

La interfaz se publica desde `main` en GitHub Pages. El dominio habitual de Vercel es un proxy del mismo sitio: no se crea otra aplicación ni se migra la base de datos.

## Servicios del proyecto propio

Proyecto Firebase: `saunastiloapp-17e15`, región `us-central1`.

Para publicar los servicios desde Google Cloud Shell con tu cuenta autorizada:

```sh
bash tools/activate-services.sh
```

El script verifica el proyecto y la facturación, solicita confirmación antes de habilitar APIs o desplegar, utiliza credenciales administradas y publica solo IA, voz y envío push. No descarga claves, cambia reglas, borra datos ni activa una nueva cuenta de cobro. Puede generar cargos por el uso de los servicios. Las funciones programadas restantes no se publican con este comando.

## Lo que no sustituye una prueba real

Una compilación satisfactoria no confirma permisos, facturación, respuesta del modelo, calidad de voz, acceso a micrófono ni entrega en teléfonos. El propietario debe comprobar `Probar IA`, una búsqueda pública con fuentes, dos roles diferentes y un aviso con pantalla bloqueada. Google debe autorizar Instant Custom Voice. El Estudio de voz requiere tus propias grabaciones y consentimiento; no utiliza un audio inventado.

La Guía de uso incluida responde preguntas operativas frecuentes sin el modelo; lo identifica explícitamente como manual, no IA. Otras preguntas dependen del servidor.

Las muestras de voz se envían por una llamada autenticada, en memoria, a Google; no se suben a la carpeta compartida. La clave de voz no se devuelve al cliente. Las búsquedas web no reciben el contexto interno de clientes, cotizaciones o historial: la síntesis con datos autorizados se realiza en una petición separada sin herramienta de búsqueda.
