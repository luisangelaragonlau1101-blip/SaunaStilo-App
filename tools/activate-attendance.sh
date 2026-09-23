#!/usr/bin/env bash
# Run in the owner's Google Cloud Shell. Never paste a private key into chat.
set -Eeuo pipefail
PROJECT='saunastiloapp-17e15'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
trap 'printf "\nLa activación no terminó. No se ha confirmado funcionamiento en producción. Revisa el error anterior (sin compartir credenciales).\n" >&2' ERR
command -v gcloud >/dev/null || { echo 'Ejecuta esto dentro de Google Cloud Shell.'; exit 1; }
command -v npx >/dev/null
node -e 'if(Number(process.versions.node.split(".")[0])<22)throw Error("Se necesita Node.js 22 o posterior")'
printf '\nSAUNA STILO · Entrada, comida, regreso y salida\nProyecto fijo: %s\n' "$PROJECT"
printf 'Se publicarán tres funciones: updateAttendance, reconcileAttendance y sendSaunaStiloNotification.\n'
printf 'Se comprobará el índice de Asistencias por persona y fecha usado por el reporte de nómina.\n'
printf 'No cambia sueldos, bonos, descuentos, cuentas, reglas de acceso, firma Android ni recordatorios programados.\n'
printf 'No borra información. No cambia el plan de facturación; los servicios y el índice pueden generar consumo en Google Cloud.\n'
read -r -p 'Para autorizar la publicación, escribe ACTIVAR: ' ANSWER
[[ "$ANSWER" == 'ACTIVAR' ]] || { echo 'Cancelado, sin publicar.'; exit 0; }
# gcloud requests browser authorization in Cloud Shell when needed.
[[ "$(gcloud projects describe "$PROJECT" --format='value(projectId)')" == "$PROJECT" ]]
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)')"
[[ "${BILLING,,}" == 'true' ]] || { echo 'No se verificó facturación activa. No se habilita ninguna cuenta de cobro automáticamente.'; exit 1; }
if ! npx --yes firebase-tools projects:list --json >/dev/null; then
  echo 'Autoriza Firebase en la página de Google que indique la terminal. No compartas códigos ni tokens por chat.'
  npx --yes firebase-tools login --no-localhost
fi
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node --test tests/attendance-ledger.test.cjs
node -e "const f=require('./functions/app');if(!f.updateAttendance||!f.reconcileAttendance||!f.sendSaunaStiloNotification)throw Error('Exportaciones incompletas')"
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com pubsub.googleapis.com fcm.googleapis.com --project="$PROJECT"
# Add only the needed index if absent. Do not deploy or replace an entire index/rules set.
INDEX_FILE="$(mktemp)";trap 'rm -f "$INDEX_FILE"' EXIT
gcloud firestore indexes composite list --project="$PROJECT" --database='(default)' --format=json >"$INDEX_FILE"
if ! python3 - "$INDEX_FILE" <<'PY'
import json,sys
for x in json.load(open(sys.argv[1])):
    fields=[(f.get('fieldPath'),f.get('order')) for f in x.get('fields',[]) if f.get('fieldPath')!='__name__']
    if '/collectionGroups/asistencias/' in x.get('name','') and x.get('queryScope')=='COLLECTION' and fields==[('trabajadorId','ASCENDING'),('fecha','ASCENDING')] and x.get('state') in ['READY','CREATING']:
        print('Índice existente, estado:',x.get('state'));sys.exit(0)
sys.exit(1)
PY
then
  gcloud firestore indexes composite create --project="$PROJECT" --database='(default)' --collection-group=asistencias --query-scope=collection --field-config=field-path=trabajadorId,order=ascending --field-config=field-path=fecha,order=ascending
fi
npx --yes firebase-tools deploy --project "$PROJECT" --only 'functions:updateAttendance,functions:reconcileAttendance,functions:sendSaunaStiloNotification'
# Read-only security smoke check: an anonymous write must be rejected before any record is created.
RESPONSE="$(mktemp)"
CODE="$(curl --silent --show-error --max-time 45 -o "$RESPONSE" -w '%{http_code}' -X POST -H 'Content-Type: application/json' --data '{"data":{"accion":"entrada"}}' "https://us-central1-$PROJECT.cloudfunctions.net/updateAttendance")"
if [[ "$CODE" != '401' ]]; then
  rm -f "$RESPONSE"
  printf 'Respuesta de comprobación: HTTP %s. No se considera activado hasta verificar autenticación y despliegue.\n' "$CODE"
  exit 1
fi
rm -f "$RESPONSE"
printf '\nSERVICIOS PUBLICADOS · La llamada anónima fue rechazada (401) sin escribir registros.\n'
printf 'Abre Sauna Stilo 3.6: registra una entrada real desde zona autorizada y comprueba el mismo día en Administración > Asistencias.\n'
printf 'Solicita comida, apruébala desde Administración, registra regreso y salida; revisa las cuatro horas y las notificaciones en ambas cuentas.\n'
printf 'El resumen de minutos es informativo; la nómina conserva la fórmula anterior. No se han certificado pagos ni recibido avisos en teléfonos físicos durante esta activación.\n'
printf 'Si un índice aparece CREATING, el reporte por persona puede necesitar esperar a que Google termine de construirlo. No borres datos ni reinstales el APK.\n'
