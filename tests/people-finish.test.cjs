const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const read = p => fs.readFileSync(p, 'utf8');

test('sign-in and voice studio retain the night brand without the retired cyan palette', () => {
  for (const file of ['lib/screens/login_screen.dart', 'lib/screens/voz_administracion_screen.dart']) {
    const code = read(file);
    assert.match(code, /0xFF000000/);
    assert.match(code, /0xFFB7FF2A/);
    assert.match(code, /0xFF8E1538/);
    for (const retired of ['0xFF86E9FF', '0xFF172D3C', '0xFF182533', '0xFF11161C']) assert.equal(code.includes(retired), false);
  }
  const login = read('lib/screens/login_screen.dart');
  assert.match(login, /assets\/logo_saunastilo\.png/);
  assert.match(login, /password: _passwordController\.text,/);
});
test('local recording remains independent from provider status and uses the resampling path', () => {
  const code = read('lib/screens/voz_administracion_screen.dart');
  const start = code.slice(code.indexOf('Future<void> _startRecording'), code.indexOf('Future<void> _stopRecording'));
  assert.match(start, /capture\.beginCapture/);
  assert.doesNotMatch(start, /_status|_voice\.status/);
  assert.match(code, /capture\.finishCapture/);
  assert.match(code, /_statusError/);
  assert.match(code, /Cómo activar el servicio/);
  assert.match(read('web/voice-capture.js'), /OfflineAudioContext/);
});
test('voice synthesis cannot start during recording or play after leaving the screen', () => {
  const code = read('lib/screens/voz_administracion_screen.dart');
  assert.match(code, /bool get _locked => _busy \|\| _recording != null/);
  for (const name of ['_testVoice', '_toggleEnabled']) {
    const body = code.slice(code.indexOf('Future<void> ' + name));
    assert.match(body.slice(0,150), /if \(_locked\) return/);
  }
  const body = code.slice(code.indexOf('Future<void> _testVoice'), code.indexOf('Future<void> _toggleEnabled'));
  assert.match(body, /if \(!mounted\) return;\s+await _player\.play/);
  assert.match(body, /setPlaybackRate\(1\.0\)/);
});
test('owner activation includes private Storage rules and separates voice from team reminders', () => {
  const team = read('tools/activate-team-services.sh');
  const voice = read('tools/activate-voice-service.sh');
  assert.match(team, /firestore:rules,storage'/);
  assert.match(team, /read -r -p/);
  assert.match(voice, /read -r -p/);
  assert.doesNotMatch(voice, /firestore:rules|storage'|--force|set-iam-policy/);
  assert.match(voice, /functions:getAdminVoiceStatus,functions:enrollAdminVoice,functions:synthesizeAdminVoice,functions:setAdminVoiceEnabled/);
  execFileSync('bash', ['-n', 'tools/activate-team-services.sh']);
  execFileSync('bash', ['-n', 'tools/activate-voice-service.sh']);
});
