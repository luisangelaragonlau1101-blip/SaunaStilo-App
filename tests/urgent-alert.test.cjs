const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { buildPushPayload } = require('../functions/push-payload');

test('admin alarm push is high priority and persistent', () => {
  const payload = buildPushPayload({
    notificationId: 'alarm-1',
    data: {
      tipo: 'alarma_admin',
      titulo: 'ALERTA GENERAL',
      mensaje: 'Atención equipo',
    },
    now: 1000,
  });
  assert.equal(payload.android.priority, 'high');
  assert.equal(payload.android.notification.priority, 'max');
  assert.equal(payload.android.notification.channelId, 'sauna_alarmas_urgentes');
  assert.equal(payload.android.notification.sticky, true);
  assert.equal(payload.apns.headers['apns-priority'], '10');
  assert.equal(payload.webpush.headers.Urgency, 'high');
  assert.equal(payload.webpush.notification.requireInteraction, true);
  assert.equal(payload.webpush.notification.silent, false);
});

test('all-team alert remains restricted to administration in server and UI', () => {
  const backend = fs.readFileSync(path.join(__dirname, '../functions/index.js'), 'utf8');
  const catalog = fs.readFileSync(path.join(__dirname, '../lib/services/app_action_catalog.dart'), 'utf8');
  const screen = fs.readFileSync(path.join(__dirname, '../lib/screens/admin_alerta_general_screen.dart'), 'utf8');
  assert.match(backend, /isAlarm/);
  assert.match(backend, /creator\.data\(\)\.rol !== 'admin'/);
  assert.match(catalog, /id: 'alerta_general'/);
  assert.match(catalog, /if \(admin\)/);
  assert.match(screen, /ACTIVAR ALERTA GENERAL/);
  assert.match(screen, /enviarAlertaGeneral/);
});

test('foreground alarm has a single owner and uses the urgent local sound', () => {
  const receiver = fs.readFileSync(path.join(__dirname, '../lib/widgets/avisos_sonoros.dart'), 'utf8');
  const push = fs.readFileSync(path.join(__dirname, '../lib/services/push_notifications_service.dart'), 'utf8');
  assert.match(receiver, /aviso.tipo == 'alarma_admin'/);
  assert.match(receiver, /sounds\/urgent_alarm\.ogg/);
  assert.match(receiver, /ReleaseMode\.loop/);
  assert.doesNotMatch(push, /onMessage\.listen/);
});
