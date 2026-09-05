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

test('the guide uses the real advanced assistant with internet enabled', () => {
  const guide = read('lib/screens/guia_inteligente_screen.dart');
  assert.match(guide, /responderAvanzado/);
  assert.match(guide, /usarInternet:\s*true/);
  assert.match(guide, /modo:\s*'guia'/);
  assert.equal(guide.includes('respuesta simulada'), false);
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

test('every role is routed through the new futuristic command center', () => {
  const bridge = read('lib/screens/modern_dashboard_screen.dart');
  const dashboard = read('lib/screens/futuristic_dashboard_screen.dart');
  assert.match(bridge, /FuturisticDashboardScreen/);
  assert.match(dashboard, /AppActionCatalog\.forUser/);
  assert.match(dashboard, /¿A dónde quieres entrar\?/);
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

test('new Firebase entrypoint preserves old functions and adds AI and voice services', () => {
  const app = read('functions/app.js');
  const pkg = JSON.parse(read('functions/package.json'));
  assert.equal(pkg.main, 'app.js');
  assert.match(app, /\.\.\.base/);
  assert.match(app, /saunaAssistantV2/);
  assert.match(app, /enrollAdminVoice/);
  assert.match(app, /synthesizeAdminVoice/);
});
