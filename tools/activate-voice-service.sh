#!/usr/bin/env bash
# Owner-authorized deployment only. Never creates a voice or uploads samples.
set -Eeuo pipefail
PROJECT='saunastiloapp-17e15'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v gcloud >/dev/null || { echo 'Usa una sesión de Google Cloud Shell autorizada.'; exit 1; }
command -v npx >/dev/null || { echo 'Falta Node.js con npm.'; exit 1; }
node -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)' || { echo 'Se requiere Node.js 22 o posterior.'; exit 1; }
gcloud projects describe "$PROJECT" --format='value(projectId)' | grep -Fx "$PROJECT" >/dev/null
printf '\nSAUNA STILO · Publicación del servicio de voz\nProyecto: %s\n' "$PROJECT"
printf 'Publicará solo estado, alta, activación y síntesis de voz. Habilita las APIs necesarias; no crea una voz, no envía grabaciones y no cambia reglas, usuarios ni facturación. El proveedor puede cobrar por uso.\n'
printf 'Google debe autorizar Instant Custom Voice por separado. Este despliegue NO concede esa autorización y NO conecta automáticamente el iframe independiente de Online Smart a tu voz.\n'
read -r -p "Para autorizar, escribe $PROJECT: " CONFIRMATION
[[ "$CONFIRMATION" == "$PROJECT" ]] || { echo 'Cancelado, sin cambios.'; exit 0; }
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)')"
[[ "${BILLING,,}" == 'true' ]] || { echo 'No se verificó facturación activa; no se crea una cuenta de cobro.'; exit 1; }
gcloud services enable texttospeech.googleapis.com cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project="$PROJECT"
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node --check functions/voice-service.js
npx --yes firebase-tools deploy --project "$PROJECT" --only 'functions:getAdminVoiceStatus,functions:enrollAdminVoice,functions:synthesizeAdminVoice,functions:setAdminVoiceEnabled'
printf '\nFunciones publicadas. Abre Estudio de voz y pulsa Comprobar servicio. La grabación, el consentimiento, la autorización de Google y una síntesis real todavía deben verificarse.\n'
