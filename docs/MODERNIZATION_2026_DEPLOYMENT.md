# Publicación de la modernización empresarial

La autorización para implementar y publicar ya fue otorgada. El bloqueo observado es técnico: Firebase CLI devuelve `Failed to authenticate, have you run firebase login?`. El borrador del entorno declara `FIREBASE_TOKEN`, pero no tiene un valor vinculado. Guardar ese borrador no autentica ni despliega Firebase.

## Preparación

Trabajar con Node.js 22 y la rama `codex/modernizacion-integral-2026`. Usar una identidad Google autorizada para el proyecto existente `saunastiloapp-17e15`. En un equipo propio o Cloud Shell se puede ejecutar `firebase login`; en automatización, usar una identidad de despliegue autorizada o un secreto de Firebase configurado en los ajustes protegidos del entorno. No pegar claves ni tokens en el chat, en el repositorio o en comandos registrados.

Para obtener un token de la cuenta propia, la herramienta oficial ofrece `npx firebase-tools login:ci`. Su salida debe guardarse exclusivamente en el campo secreto `FIREBASE_TOKEN` del entorno; nunca enviarla por chat. Este método es legado: preferir una identidad de servicio o federada cuando esté disponible y correctamente autorizada.

La red del entorno debe permitir OAuth/Firebase/Firestore/Storage y las API de Cloud Functions, Cloud Run, Cloud Build, Artifact Registry, Eventarc, Pub/Sub, Cloud Scheduler, IAM y Service Usage que realmente exija el despliegue. No cambiar automáticamente de proyecto ni crear usuarios, cuentas de facturación o una nueva base.

Antes de desplegar, obtener una copia de las reglas remotas y compararlas con el repositorio. Conservar las personalizaciones que no estén versionadas y un respaldo administrativo de los datos existentes. Este desarrollo no incluye un borrado ni una importación que sustituya esos datos.

## Backend, reglas e índices

```sh
bash tools/deploy-enterprise-2026.sh
```

El script comprueba acceso al proyecto, instala dependencias bloqueadas, carga el módulo de funciones, ejecuta Node y despliega únicamente las funciones empresariales y de avisos necesarias, Firestore rules/indexes y Storage rules. No promueve el cliente web, no usa `--force` y se detiene si falta autenticación. No presupone que una compilación de Flutter despliegue Firebase.

Funciones empresariales: `enterpriseFinance`, `enterpriseInstallations`, `enterpriseAttendance`, `enterpriseAccess`, `enterprisePreferences`. Avisos: `sendSaunaStiloNotification`, `cancelAttendanceReminders`, `syncBirthdayProjection`, `repeatWorkdayReminders` y los nombres anteriores `reminderEntrada`, `reminderComida`, `reminderSalida`, `reminderAusencias`. Todas las rutas de recordatorio nuevas comparten identificadores por persona/día/acción; las repeticiones no crean asistencias ni avisos adicionales para el mismo evento.

Colecciones financieras: `gestion_movimientos` existente; `gestion_cuentas`, `gestion_facturas`, `gestion_compras`, `gestion_presupuestos`, `gestion_config`, `gestion_auditoria`, `gestion_operaciones`, `gestion_conciliaciones`, `gestion_cfdi_uuids`, `gestion_proyectos`.

Instalaciones: `instalacion_ordenes` y sus `eventos`, `instalacion_plantillas`, `instalacion_operaciones`, integradas con `actividades`, `insumos_inventario`, `cajitas_inventario` y `solicitudes_herramientas` existentes. Las solicitudes espejo de instalación no se procesan de nuevo con los botones de préstamos anteriores.

Privacidad/jornada: `preferencias_personales`, `preferencias_notificaciones`, `cumpleanos_equipo`, `jornada_operaciones`, `empresa_auditoria`, además de `asistencias` y `notificaciones` existentes.

Archivos: `finance/<uid>/<operación>/…` para documentos fiscales inmutables; `instalaciones/<orden>/…` para evidencias y actas. Las consultas usan Firebase Authentication y reglas privadas, sin enlaces públicos persistentes. Las actas se generan en servidor; su descarga usa Storage autenticado y no requiere firmar URL con `signBlob`.

Esperar a que los índices de `firestore.indexes.json` estén **listos**. No usar el éxito del emulador como prueba de que un índice ya existe en producción.

## Comprobación autenticada antes de publicar la web

Verificar con cuentas autorizadas: gasto y ticket → factura pendiente → XML/PDF y revisión; compra → autorización → una sola conversión; orden → checklist → autorización → dos firmas → PDF → devolución → firmas → cierre y stock; actividad → foto → revisión administrativa; jornada con hora de servidor. No generar pruebas sobre empleados sin su conocimiento. Confirmar permisos negativos y que los registros históricos siguen disponibles.

Desde Gestión de la empresa → Funciones y permisos, asignar capacidades según puesto, permiso manual y horario de comida. “Proteger cumpleaños históricos” conserva las fechas en el registro privado; después cada persona configura su consentimiento en su perfil. Contabilidad confirma régimen/RFC, clasifica el histórico y configura reservas antes de interpretar estimaciones fiscales. El disponible registrado excluye saldos históricos sin cuenta asignada; no sustituye al saldo bancario conciliado.

Verificar APNs/VAPID, permisos de notificación, preferencias y recepción en primer/segundo plano/cerrada en iPhone y Android. La recepción depende también de permisos y restricciones del dispositivo; no se genera asistencia por recibir un recordatorio.

## Cliente web

Cuando el backend y los índices estén verificados, promover los commits revisados a `main`. El flujo `.github/workflows/build-web.yml` prueba y compila Flutter, publica GitHub Pages y confirma la versión exacta en:

- https://sauna-stilo-app-web.vercel.app/
- https://luisangelaragonlau1101-blip.github.io/SaunaStilo-App/

Comprobar `version.json` y la revisión del trabajador de caché en ambas URL, además del login y un flujo autenticado. Conservar la versión pública anterior hasta que estos controles pasen. No despachar Build Web sobre la rama empresarial antes de tener backend: ese flujo publica realmente en Pages.

Para una reversión del cliente usar el commit web previo verificado; conservar documentos y auditoría. No borrar las colecciones nuevas ni sustituir automáticamente reglas antiguas tras haber registrado datos empresariales.

## Reproducir validaciones aisladas

```sh
flutter analyze --no-pub lib test --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node --test tests/*.test.cjs tools/online-smart34/*.test.mjs
```

El flujo `team-release-review.yml` ejecuta las pruebas Firestore/Storage y transacciones con proyectos `demo-*`. En esta nube se usaron Firestore 8187 y Storage 9197 mediante un archivo de configuración temporal. Firebase CLI 15.32.1 ignora `NO_PROXY` en sus consultas internas de Storage a Firestore: para esas pruebas **exclusivamente locales**, se retiraron las variables de proxy en el proceso de emuladores; no se cambiaron las reglas ni las aserciones para lograr un resultado positivo. Los despliegues reales conservan la configuración de red y autenticación del entorno.
