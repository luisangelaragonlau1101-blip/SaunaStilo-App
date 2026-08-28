# Backend de Sauna IA

La función callable `saunaAssistant` autentica cada solicitud, vuelve a leer el
rol desde `usuarios/{uid}` y forma un contexto diferente para administración,
almacén y trabajadores. Los perfiles no administradores nunca cargan clientes,
cotizaciones ni proyectos administrativos.

Antes del primer despliegue se configura la clave únicamente en Secret Manager:

```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:saunaAssistant
```

La clave no debe agregarse al código, a `.env` ni al repositorio.
