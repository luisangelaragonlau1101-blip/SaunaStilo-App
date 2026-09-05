const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('Sauna IA v2 is grounded with Google Search and remains on Vertex AI', () => {
  const backend = read('functions/assistant-v2.js');
  assert.match(backend, /vertexai:\s*true/);
  assert.match(read('functions/web-context.js'), /googleSearch:\s*\{\}/);
  assert.match(backend, /retrieveWebContext/);
  assert.match(backend, /extractWebSources/);
  assert.match(backend, /usarInternet/);
});
test('the retained advanced guide uses the real assistant, while main navigation opens the embedded guide', () => {
  const guide = read('lib/screens/guia_inteligente_screen.dart');
  assert.match(guide, /OnlineSmartScreen/);
  assert.match(guide, /SIN CONSULTA A IA/);
  assert.equal(guide.includes('respuesta simulada'), false);
  assert.match(read('lib/screens/operations_shell.dart'), /OnlineSmartScreen/);
  assert.match(read('lib/screens/online_smart_embed_web.dart'), /HtmlElementView/);
});
test('official voice enrollment requires the exact Spanish consent and keeps cloning key off Flutter client', () => {
  const server = read('functions/voice-service.js');
  const client = read('lib/services/custom_voice_service.dart');
  const consent = 'Soy el propietario de esta voz y doy mi consentimiento para que Google la utilice para crear un modelo de voz sintética.';
  assert.equal(server.includes(consent), true);
  assert.match(server, /voices:generateVoiceCloningKey/);
  assert.match(server, /text:synthesize/);
  assert.equal(client.includes('voiceCloningKey'), false);
});
test('every role uses the daily operations shell and retains all role-filtered actions including alert', () => {
  const bridge = read('lib/screens/modern_dashboard_screen.dart');
  const shell = read('lib/screens/operations_shell.dart');
  assert.match(bridge, /OperationsShell/);
  assert.match(shell, /AppActionCatalog\.forUser/);
  assert.match(shell, /alerta_general/);
  for (const label of ['Inicio', 'Comunidad', 'Chats', 'Tareas', 'Perfil']) assert.ok(shell.includes("label: '" + label + "'"));
  assert.match(shell, /JornadaCompacta/);
  assert.match(shell, /OperationsTaskList/);
});
test('administration has a voice studio while other roles remain role-filtered', () => {
  const catalog = read('lib/services/app_action_catalog.dart');
  const studio = read('lib/screens/voz_administracion_screen.dart');
  assert.match(catalog, /id:\s*'voz'/);
  assert.match(catalog, /widget.usuario.rol == AppRoles.admin|user\.rol == AppRoles.admin/);
  assert.match(studio, /Este estudio de voz está disponible únicamente para Administración/);
  assert.match(studio, /_VoiceSlot\.consent/);
  assert.match(studio, /_VoiceSlot\.reference/);
});
test('Firebase entrypoint preserves old functions and adds scoped team services', () => {
  const app = read('functions/app.js');
  assert.equal(JSON.parse(read('functions/package.json')).main, 'app.js');
  for (const name of ['...base','saunaAssistantV2','enrollAdminVoice','synthesizeAdminVoice','assignProjectActivity','repeatWorkdayReminders']) assert.ok(app.includes(name));
});
