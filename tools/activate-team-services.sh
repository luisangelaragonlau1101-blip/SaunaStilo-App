#!/usr/bin/env bash
# Run only in an owner's authenticated Google Cloud Shell. No secret keys required.
set -Eeuo pipefail
PROJECT='saunastiloapp-17e15'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v gcloud >/dev/null || { echo 'Abre el repositorio en Google Cloud Shell con tu cuenta autorizada.'; exit 1; }
command -v npx >/dev/null || { echo 'Se requiere Node.js con npm.'; exit 1; }
node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)' || { echo 'Selecciona Node.js 22 o posterior en Cloud Shell antes de continuar.'; exit 1; }
gcloud projects describe "$PROJECT" --format='value(projectId)' | grep -Fx "$PROJECT" >/dev/null
printf '\nSAUNA STILO · Activación de operación\nProyecto: %s\n' "$PROJECT"
printf 'Publicará entrada/salida, avisos y recordatorios. También reemplazará las reglas Firestore por las del repositorio, probadas para tareas del maestro y privacidad de avisos.\n'
printf 'No borra usuarios, documentos ni proyectos; no cambia tu plan de facturación. El uso del servidor puede generar cargos. No activa IA de Google ni clonación de voz.\n'
printf 'Revisa firestore.rules: si has editado reglas directamente en Firebase y no están en el repositorio, cancela y reconcilia primero.\n'
read -r -p "Para autorizar, escribe $PROJECT: " CONFIRMATION
[[ "$CONFIRMATION" == "$PROJECT" ]] || { echo 'Cancelado, sin cambios.'; exit 0; }
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)')"
[[ "${BILLING,,}" == 'true' ]] || { echo 'No se verificó facturación activa. No se habilitará ninguna cuenta de cobro.'; exit 1; }
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com pubsub.googleapis.com fcm.googleapis.com cloudscheduler.googleapis.com --project="$PROJECT"
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node --test tests/*.test.cjs
# Do not deploy the alternative repeatWorkdayReminders alongside these schedules.
npx --yes firebase-tools deploy --project "$PROJECT" --only 'functions:updateAttendance,functions:sendSaunaStiloNotification,functions:reminderEntrada,functions:reminderComida,functions:reminderSalida,firestore:rules'
printf '\nServicios publicados. No se envió ningún mensaje ni se registró asistencia de prueba por este script. Los recordatorios programados quedan activos.\n'
printf 'Comprueba una entrada real desde una ubicación autorizada; verifica la hora guardada. Haz una prueba consentida entre dos teléfonos para confirmar avisos y sonido.\n'
printf 'No despliegues repeatWorkdayReminders al mismo tiempo: duplicaría recordatorios. No se garantiza entrega con Silencio/Enfoque, ni volumen máximo.\n'
