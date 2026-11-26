# Arranque y validación de rendimiento — modernización 2026

La referencia se congeló antes de editar el arranque: commit
`9b4d6ae36fa7332b600cfb8e9a05e7018bb8da28`. Se exportó mediante `git archive`
fuera del repositorio, sin crear otro Git worktree, y se compiló como release
JavaScript/CanvasKit con Flutter 3.47.6 y Dart 3.13.5.

## Medición real y alcance

El script [startup-benchmark.cjs](../tools/startup-benchmark.cjs) abre la
compilación en Chromium 151.0.7922.173, con viewport móvil de 390 × 844. Captura
`flutter-first-frame` y el instante en que aparece el formulario accesible
«Entrar a mi espacio», con sus dos campos de entrada. La página debe responder
HTTP 200 y no producir errores JavaScript.

Cada versión se mide con cinco pares de navegaciones:

- **Fría:** contexto nuevo, caché HTTP borrada explícitamente y almacenamiento
  local nuevo.
- **Reapertura:** página nueva en el mismo contexto, conservando sus cachés.

No se incluyen el arranque del proceso del navegador ni la instalación del
service worker: este último se bloquea durante la comparación. El servidor
estático usa los mismos encabezados de caché para ambas compilaciones. No hay
limitación artificial de CPU o red.

Esta máquina valida TLS mediante `curl`, pero Chromium rechaza la CA del proxy
para los SDK externos. El benchmark utiliza un espejo local de **SDK públicos
de Firebase y fuentes**, precargado mediante una navegación sin medir. Las
descargas originales conservan la verificación TLS. Solo se reescriben sus URL
públicas en las respuestas del servidor de pruebas, de forma idéntica para
ambas versiones. No se interceptan API privadas ni credenciales. Esto mantiene
la caché HTTP real del navegador habilitada; `page.route` la deshabilitaría.

Los resultados corresponden a una prueba local controlada. **No son una
medición de conexión celular, Safari, aplicación nativa o inicio autenticado de
un empleado real.** La primera interfaz de Flutter tampoco equivale por sí sola
a tener acceso a información privada.

## Referencia antes del cambio

| Mediana de 5 muestras | Apertura fría | Reapertura |
| --- | ---: | ---: |
| Primera interfaz Flutter | 1.031 s | 1.002 s |
| Formulario de acceso disponible | 2.029 s | 1.943 s |

Los valores individuales, versión del navegador, estado de la caché y condiciones
están en [startup-baseline-2026.json](validation/startup-baseline-2026.json).
La comprobación de referencia terminó con 10 navegaciones correctas, cero
errores JavaScript y sin acceder a datos empresariales privados.

La medición de la versión modificada debe ejecutarse cuando se congele su
compilación; no se sustituye por una estimación a partir del código.

## Reproducir la comparación

En el entorno preparado, activar `/workspace/.cloud-setup/flutter-env.sh` y
ejecutar desde la carpeta de cada versión:

```sh
flutter pub get --enforce-lockfile
flutter build web --release --no-pub --base-href / --pwa-strategy=none
node tools/startup-benchmark.cjs \
  --build-dir build/web \
  --public-sdk-cache /workspace/.cloud-setup/public-sdk-cache-2026 \
  --label version-a-medir \
  --repetitions 5 \
  --out /workspace/.cloud-setup/startup-version-a-medir.json
```

Para la versión anterior, ejecutar el script nuevo indicando la ruta de su
compilación congelada con `--build-dir`. El espejo solo es necesario si la CA
de Chromium impide cargar los SDK; en otro entorno puede omitirse esa opción.
No deben mezclarse en la misma comparación resultados con transportes distintos.
El archivo JSON registra también las marcas `stilo:*` cuando la compilación
las proporciona.

## Comprobaciones de la referencia

- Flutter: **121 pruebas aprobadas**, cero fallidas, con concurrencia 2.
- Node: **124 pruebas aprobadas**, cero fallidas.
- `flutter analyze --no-pub lib test --no-fatal-infos --no-fatal-warnings`:
  **920 avisos previos**, sin errores del analizador.
- `flutter build web --release --no-pub --base-href / --pwa-strategy=none`:
  compilación JavaScript correcta en 77.6 s. Ese tiempo es de compilación y no
  debe confundirse con el tiempo de apertura de la aplicación.

Los logs completos de esta ejecución se guardan en `/workspace/.cloud-setup/`
con el prefijo `baseline-2026-`. Los resultados finales y sus limitaciones deben
registrarse por separado, sin atribuir a la nueva versión pruebas de la anterior.

## Verificación pendiente fuera de esta medición

La pantalla privada de Inicio exige identidad Firebase y un perfil autorizado.
Sus marcas de rendimiento ayudan a medir `firebase-ready`, `auth-ready`,
`profile-ready` y `home-first-frame` con una cuenta de prueba autorizada. El
benchmark público no utiliza cuentas reales de empleados ni elude este control.

La validación en iPhone/Safari y Android físicos, la cámara y el micrófono, la
recepción FCM con la aplicación cerrada y una conexión móvil lenta deben
comprobarse en los dispositivos correspondientes. Una vista de Chromium con
dimensiones de teléfono no valida esas capacidades nativas.


## Primera publicación compatible con Firebase existente

La versión de arranque independiente se midió con el mismo protocolo: cinco aperturas frías y cinco reaperturas, acceso visible y sin errores JavaScript. El build se realizó antes del commit de publicación; el JSON registra el commit base y el estado de fuentes para no atribuir la medición a la versión anterior.

| Mediana | Antes frío | Después frío | Antes reapertura | Después reapertura |
| --- | ---: | ---: | ---: | ---: |
| Primera interfaz Flutter | 1.031 s | 0.977 s | 1.002 s | 0.924 s |
| Formulario de acceso disponible | 2.029 s | 1.700 s | 1.943 s | 1.658 s |

El acceso mejora aproximadamente 16 % en frío y 15 % al reabrir, bajo las condiciones locales descritas. No se han medido datos de empleados reales ni dispositivos físicos. Resultados: [startup-release-2026.json](validation/startup-release-2026.json).
