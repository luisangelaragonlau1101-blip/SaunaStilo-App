#!/usr/bin/env bash
# Run in the owner's authenticated Google Cloud Shell; no downloaded keys.
set -Eeuo pipefail
PROJECT='saunastiloapp-17e15'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v gcloud >/dev/null || { echo 'Abre este proyecto en Google Cloud Shell.'; exit 1; }
command -v firebase >/dev/null || { echo 'Falta Firebase CLI. Instálalo en Cloud Shell antes de continuar.'; exit 1; }
node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)' || { echo 'Se requiere Node 22 o posterior.'; exit 1; }
gcloud projects describe "$PROJECT" --format='value(projectId)' | grep -Fx "$PROJECT" >/dev/null
printf '\nProyecto: %s\n' "$PROJECT"
printf 'Esta activación publica IA, búsqueda web, voz y envío push. El uso puede generar cargos en Google Cloud.\n'
printf 'No cambia tu plan de facturación, usuarios, reglas de seguridad ni registros de la empresa.\n'
printf 'Instant Custom Voice requiere además la autorización de Google. No se genera tu voz hasta que la grabes y lo confirmes en la app.\n\n'
read -r -p "Para autorizar servicios y despliegue, escribe $PROJECT: " CONFIRMATION
[[ "$CONFIRMATION" == "$PROJECT" ]] || { echo 'Cancelado, sin cambios.'; exit 0; }
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)')"
[[ "${BILLING,,}" == 'true' ]] || { echo 'El proyecto no tiene facturación activa o no se pudo verificar. No se ha habilitado ninguna cuenta de cobro.'; exit 1; }
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com pubsub.googleapis.com aiplatform.googleapis.com texttospeech.googleapis.com fcm.googleapis.com --project="$PROJECT"
npm --prefix functions ci --ignore-scripts
node --test tests/*.test.cjs
firebase deploy --project "$PROJECT" --only 'functions:saunaAssistant,functions:saunaAssistantV2,functions:sendSaunaStiloNotification,functions:getAdminVoiceStatus,functions:enrollAdminVoice,functions:setAdminVoiceEnabled,functions:synthesizeAdminVoice'
firebase functions:list --project "$PROJECT"
printf '\nDespliegue terminado. Abre Inicio > Probar IA. Prueba también Guía y los avisos con dos teléfonos.\n'
printf 'Si Google rechaza IA o voz, revisa los permisos de la identidad de ejecución y el acceso a Instant Custom Voice. El despliegue no demuestra una respuesta de IA ni entrega push.\n'
