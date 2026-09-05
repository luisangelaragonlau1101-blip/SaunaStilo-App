from pathlib import Path

def replace(path, old, new):
    p = Path(path)
    text = p.read_text()
    if text.count(old) != 1:
        raise SystemExit('Unexpected source in ' + path)
    p.write_text(text.replace(old, new))

# The retained screen uses formatted Dart and its own conditional iframe adapter.
replace('tests/team-workflows.test.cjs', "assert.match(page,/workspace':'sauna-stilo'/);", "assert.match(page,/'workspace'\\s*:\\s*'sauna-stilo'/);")
replace('tests/team-workflows.test.cjs', "read('lib/widgets/online_smart_embed_web.dart')", "read('lib/screens/online_smart_embed_web.dart')")
for file in ['lib/widgets/online_smart_embed_web.dart', 'lib/widgets/online_smart_embed_stub.dart']:
    Path(file).unlink()

# Match production iframe permissions in the real-provider browser verification.
replace('tools/team-browser-smoke.cjs', "f.id='embedding-check';f.src=url;", "f.id='embedding-check';f.src=url;f.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-popups');f.setAttribute('allow','microphone; autoplay');f.setAttribute('referrerpolicy','no-referrer');")

# Never download every colleague's personal notification to filter it on the device.
replace('lib/services/notificaciones_service.dart', "  Stream<List<NotificacionApp>> avisosPara", "  Query<Map<String, dynamic>> _visible(String uid, String rol) => _ref.where(Filter.or(\n    Filter('destinatarioId', isEqualTo: uid),\n    Filter('destinatarioId', isEqualTo: 'todos'),\n    Filter('rolesDestinatarios', arrayContainsAny: [rol, 'todos']),\n  ));\n\n  Stream<List<NotificacionApp>> avisosPara")
replace('lib/services/notificaciones_service.dart', "return _ref.snapshots().map", "return _visible(usuarioId, rol).snapshots().map")
replace('lib/services/notificaciones_service.dart', "final snapshot = await _ref.get();", "final snapshot = await _visible(usuarioId, rol).get();")
replace('firestore.rules', "    match /notificaciones/{notificationId} {\n      allow read: if signedIn();", "    function notificationVisible(data) {\n      return signedIn() && (data.get('destinatarioId', '') == request.auth.uid\n        || data.get('destinatarioId', '') == 'todos'\n        || data.get('rolesDestinatarios', []).hasAny([role(), 'todos']));\n    }\n\n    match /notificaciones/{notificationId} {\n      allow read: if notificationVisible(resource.data);")
replace('firestore.rules', "      allow create: if isAdmin() || isSafeNotificationCreate();\n      allow update: if signedIn()", "      allow create: if isAdmin() || isSafeNotificationCreate();\n      allow update: if notificationVisible(resource.data)")

# Attendance reminders expire promptly rather than appearing the next day.
replace('functions/push-payload.js', "(isAlarm || isPersonal ? 900 : 86400)", "(isAlarm || isPersonal || type.startsWith('asistencia_') ? 900 : 86400)")
replace('tools/security.test.cjs', "const {doc,setDoc,getDoc,updateDoc,serverTimestamp,Timestamp}", "const {doc,setDoc,getDoc,getDocs,collection,query,where,or,updateDoc,serverTimestamp,Timestamp}")
with Path('tools/security.test.cjs').open('a') as f:
    f.write('''\ntest('personal notices can be queried by the recipient, not another worker',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'notificaciones','private'),{destinatarioId:'worker',rolesDestinatarios:[],leidosPor:[],mensaje:'Personal',creadoPor:'master'});
  await setDoc(doc(c.firestore(),'notificaciones','general'),{destinatarioId:'todos',rolesDestinatarios:['todos'],leidosPor:[],mensaje:'General',creadoPor:'admin'});
 });
 const db=env.authenticatedContext('worker').firestore();
 await assertSucceeds(getDocs(query(collection(db,'notificaciones'),or(where('destinatarioId','==','worker'),where('destinatarioId','==','todos'),where('rolesDestinatarios','array-contains-any',['trabajador','todos'])))));
 await assertFails(getDocs(collection(db,'notificaciones')));
 const other=env.authenticatedContext('outside').firestore();
 await assertFails(getDoc(doc(other,'notificaciones','private')));
 await assertFails(updateDoc(doc(other,'notificaciones','private'),{leidosPor:['outside']}));
 await assertSucceeds(getDoc(doc(other,'notificaciones','general')));
});
''')
with Path('tests/team-workflows.test.cjs').open('a') as f:
    f.write('''\ntest('reminders expire after fifteen minutes and queries filter recipients on the server',()=>{
 const p=buildPushPayload({notificationId:'entry',data:{tipo:'asistencia_entrada'}});
 assert.equal(p.webpush.headers.TTL,'900');
 const s=read('lib/services/notificaciones_service.dart');
 assert.match(s,/Filter.or/);assert.doesNotMatch(s,/_ref.snapshots/);
 assert.match(read('firestore.rules'),/allow read: if notificationVisible/);
});
''')
replace('tools/activate-services.sh', 'Abre Inicio > Probar IA.', 'Abre Inicio > Jornada para verificar entrada y salida; Online Smart tiene su acceso propio.')
print('Applied exact guide, notification privacy, reminder-expiry and test refinements.')
