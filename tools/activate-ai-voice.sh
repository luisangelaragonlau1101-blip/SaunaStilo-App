#!/usr/bin/env bash
# Run in an authorized Google Cloud Shell session for the existing Firebase project.
set -Eeuo pipefail
PROJECT='saunastiloapp-17e15'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
trap 'printf "\nLa activación no terminó. Revisa el error anterior; no se ha confirmado funcionamiento en producción.\n" >&2' ERR
command -v gcloud >/dev/null || { echo 'Ejecuta este archivo en Google Cloud Shell.'; exit 1; }
command -v npx >/dev/null
node -e 'if(Number(process.versions.node.split(".")[0])<22)throw Error("Se requiere Node.js 22 o posterior")'
[[ "$(gcloud projects describe "$PROJECT" --format='value(projectId)')" == "$PROJECT" ]]
BILLING="$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)')"
[[ "${BILLING,,}" == 'true' ]] || { echo 'El proyecto necesita facturación activa para publicar Functions. No se ha cambiado el plan.'; exit 1; }
printf '\nSAUNA STILO · Activación de IA, voz y envío de notificaciones\nProyecto: %s\n' "$PROJECT"
printf 'Se publicarán solo los siete servicios indicados; el uso de Google Cloud puede generar cargos.\n'
if ! npx --yes firebase-tools projects:list --json >/dev/null; then
  npx --yes firebase-tools login --no-localhost
fi
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node --test tests/futuristic-ai-voice.test.cjs tests/release-hardening.test.cjs tests/connectivity.test.cjs
node - <<'NODE'
const functions = require('./functions/app');
for (const name of ['saunaAssistant', 'saunaAssistantV2', 'getAdminVoiceStatus', 'enrollAdminVoice', 'setAdminVoiceEnabled', 'synthesizeAdminVoice', 'sendSaunaStiloNotification']) {
  if (typeof functions[name] !== 'function') throw new Error(`Falta la función ${name}`);
}
NODE
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com pubsub.googleapis.com aiplatform.googleapis.com texttospeech.googleapis.com fcm.googleapis.com --project="$PROJECT"
npx --yes firebase-tools deploy --project "$PROJECT" --only 'functions:saunaAssistant,functions:saunaAssistantV2,functions:getAdminVoiceStatus,functions:enrollAdminVoice,functions:setAdminVoiceEnabled,functions:synthesizeAdminVoice,functions:sendSaunaStiloNotification'
# These calls must reject anonymous access before reading private data or invoking AI.
node - <<'NODE'
(async () => {
  for (const name of ['saunaAssistantV2', 'getAdminVoiceStatus']) {
    const response = await fetch(`https://us-central1-saunastiloapp-17e15.cloudfunctions.net/${name}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({data: {}}),
      signal: AbortSignal.timeout(45000),
    });
    const payload = await response.json().catch(() => ({}));
    if (response.status !== 401 || payload.error?.status !== 'UNAUTHENTICATED') {
      throw new Error(`${name}: respuesta inesperada HTTP ${response.status}; falta verificar despliegue y acceso.`);
    }
    console.log(`${name}: publicado; acceso anónimo rechazado.`);
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
NODE
printf '\nServicios publicados y autenticación comprobada. Falta probar una respuesta desde una cuenta de Sauna Stilo.\n'
printf 'En Administración > Estudio de voz, comprueba el servicio, graba consentimiento y muestra, y prueba la síntesis. Google debe autorizar Instant Custom Voice.\n'
printf 'Comprueba avisos y llamadas entre dos teléfonos. La publicación no confirma recepción ni sonido en segundo plano.\n'
