#!/usr/bin/env bash
# Publish the authenticated backend before promoting its dependent Flutter client.
set -Eeuo pipefail
STILO_PROJECT='saunastiloapp-17e15'
STILO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$STILO_ROOT"
command -v node >/dev/null
command -v npm >/dev/null
node -e 'if(Number(process.versions.node.split(".")[0])!==22)throw Error("Usa Node.js 22 para Firebase Functions.")'
if command -v firebase >/dev/null; then
  STILO_FIREBASE=(firebase)
else
  STILO_FIREBASE=(npx --yes firebase-tools@15.32.1)
fi
STILO_ACCESS_REPORT="$(mktemp)"
trap 'rm -f "$STILO_ACCESS_REPORT"' EXIT
"${STILO_FIREBASE[@]}" projects:list --json > "$STILO_ACCESS_REPORT"
node - "$STILO_ACCESS_REPORT" "$STILO_PROJECT" <<'NODE'
const fs=require('node:fs');
const report=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
if(!Array.isArray(report.result)||!report.result.some(p=>p.projectId===process.argv[3])){
  throw Error('La sesión no acredita acceso al proyecto de STILO. Autentica Firebase con una cuenta autorizada.');
}
NODE
git diff --check
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
node -e "require('./functions/app.js')"
node --test tests/*.test.cjs tools/online-smart34/*.test.mjs

# Existing names are updated in place; the shared policy deduplicates reminders.
# No force, account creation, database import, user deletion or client promotion.
"${STILO_FIREBASE[@]}" deploy --project "$STILO_PROJECT" --non-interactive \
  --only 'functions:enterpriseFinance,functions:enterpriseInstallations,functions:enterpriseAttendance,functions:enterpriseAccess,functions:enterprisePreferences,functions:cancelAttendanceReminders,functions:syncBirthdayProjection,functions:sendSaunaStiloNotification,functions:reminderEntrada,functions:reminderComida,functions:reminderSalida,functions:reminderAusencias,functions:repeatWorkdayReminders,firestore:rules,firestore:indexes,storage'
printf '%s\n' 'Servicios y reglas enviados. Espera a que los índices estén listos y verifica los flujos con cuentas autorizadas antes de promover el cliente web.'
