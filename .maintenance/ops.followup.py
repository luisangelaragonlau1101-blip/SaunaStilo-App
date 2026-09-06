from pathlib import Path
root=Path.cwd()
p=root/'lib/screens/trabajador_control_herramientas_screen.dart'
p.write_text(p.read_text().replace('_imagenBytes!, \n','_imagenBytes!,\n'))
p=root/'lib/screens/modal_asignar_actividades.dart'
s=p.read_text();assert s.count('      ])))));')==1;p.write_text(s.replace('      ])))));','      ]))))));'))
p=root/'lib/services/offline_workspace.dart'
s=p.read_text();a=s.index('      if (kIsWeb)');b=s.index('    } catch',a)
assert 'enablePersistence' in s[a:b]
p.write_text(s[:a]+'      FirebaseFirestore.instance.settings = Settings(persistenceEnabled: trusted, cacheSizeBytes: 40 * 1024 * 1024, webPersistentTabManager: kIsWeb && trusted ? const WebPersistentMultipleTabManager() : null);\n'+s[b:])
p=root/'firestore.rules';s=p.read_text();a=s.index('    function oneGameMove(');b=s.index('    match /partidas_equipo/',a)
s=s[:a]+'''    function oneGameMove(old,b,m) {
      let i = b[0] != old[0] ? 0 : b[1] != old[1] ? 1 : b[2] != old[2] ? 2 : b[3] != old[3] ? 3 : b[4] != old[4] ? 4 : b[5] != old[5] ? 5 : b[6] != old[6] ? 6 : b[7] != old[7] ? 7 : b[8] != old[8] ? 8 : -1;
      return b is list && b.size() == 9 && i >= 0 && old[i] == '' && b[i] == m
        && (i == 0 || b[0] == old[0]) && (i == 1 || b[1] == old[1]) && (i == 2 || b[2] == old[2])
        && (i == 3 || b[3] == old[3]) && (i == 4 || b[4] == old[4]) && (i == 5 || b[5] == old[5])
        && (i == 6 || b[6] == old[6]) && (i == 7 || b[7] == old[7]) && (i == 8 || b[8] == old[8]);
    }
'''+s[b:]
s=s.replace("&& gameResult(resource.data.tablero) == ''","&& resource.data.resultado == ''");p.write_text(s)
p=root/'tools/operations-security.test.cjs';s=p.read_text();s+='''
test('complete legal games include the last cell, a win, a draw and reject play after completion',async()=>{
 const cases=[{id:'win',moves:[8,0,4,1,6,2],result:'O'},{id:'draw',moves:[0,1,2,4,3,5,7,6,8],result:'empate'}];
 for(const scenario of cases){
  const id='juego_worker_'+scenario.id,board=Array(9).fill('');
  await assertSucceeds(setDoc(doc(db('worker'),'partidas_equipo',id),{jugadores:['worker','master'],nombres:['A','B'],tablero:board,estado:'invitada',turno:'worker',resultado:'',creadoPor:'worker',fecha:serverTimestamp(),actualizadaEn:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db('master'),'partidas_equipo',id),{estado:'jugando',actualizadaEn:serverTimestamp()}));
  for(let n=0;n<scenario.moves.length;n++){
   const actor=n%2?'master':'worker',next=n%2?'worker':'master',finished=n===scenario.moves.length-1;
   board[scenario.moves[n]]=n%2?'O':'X';
   await assertSucceeds(updateDoc(doc(db(actor),'partidas_equipo',id),{tablero:[...board],turno:next,resultado:finished?scenario.result:'',estado:finished?'terminada':'jugando',actualizadaEn:serverTimestamp()}));
  }
  const saved=(await getDoc(doc(db('worker'),'partidas_equipo',id))).data();assert.equal(saved.resultado,scenario.result);
  await assertFails(updateDoc(doc(db(saved.turno),'partidas_equipo',id),{estado:'jugando',resultado:'',actualizadaEn:serverTimestamp()}));
 }
});
''';p.write_text(s)
p=root/'lib/services/notification_router.dart';s=p.read_text()
s=s.replace("import '../screens/prestamos_equipo_screen.dart';","import '../screens/prestamos_equipo_screen.dart';\nimport '../screens/admin_solicitudes_herramientas_screen.dart';\nimport '../screens/trabajador_control_herramientas_screen.dart';")
s=s.replace("      } else if (data['tipo'] == 'tarea') {","      } else if (data['tipo'] == 'almacen' || data['tipo'] == 'solicitud_herramienta') {\n        destination = [AppRoles.admin, AppRoles.almacenista].contains(user.rol) ? const AdminSolicitudesHerramientasScreen() : ControlHerramientasScreen(usuarioId: user.id, usuarioNombre: user.nombre);\n      } else if (data['tipo'] == 'tarea') {");p.write_text(s)
p=root/'web/offline-client.js'
p.write_text('''/* Public shell only; private persistence needs the trusted-device consent. */
(() => {
  async function prepare() {
    if(!('serviceWorker' in navigator)||!window.isSecureContext)return;
    try {
      const base=new URL('./',document.baseURI),all=await navigator.serviceWorker.getRegistrations();
      let r=all.find(x=>x.scope===base.href&&/firebase-messaging-sw\\.js/.test(x.active?.scriptURL||''));
      if(r)await r.update();else r=await navigator.serviceWorker.register(new URL('stilo-offline-worker.js',base),{scope:base.pathname});
      const sent=new Set();
      const warm=()=>{
        const worker=r.active;if(!worker||worker.state!=='activated')return;
        const urls=performance.getEntriesByType('resource').map(x=>x.name).filter(raw=>{try{const u=new URL(raw);return u.protocol==='https:'&&u.hostname==='www.gstatic.com'&&/^\\/firebasejs\\/[\\w.-]+\\/firebase-[\\w-]+\\.js$/.test(u.pathname)&&!sent.has(u.href);}catch(_){return false;}}).slice(-250);
        if(urls.length){worker.postMessage({type:'stilo-cache-public',urls});for(const u of urls)sent.add(u);}
      };
      const target=r.installing||r.waiting||r.active;
      if(target?.state==='activated')warm();else target?.addEventListener('statechange',()=>{if(target.state==='activated')warm();});
      // Firebase libraries may load after the first Flutter frame; never warm private request URLs.
      if(window.PerformanceObserver){const observer=new PerformanceObserver(warm);observer.observe({type:'resource',buffered:true});setTimeout(()=>observer.disconnect(),120000);}
      for(const delay of [1000,3000,8000,15000,30000,60000])setTimeout(warm,delay);
    } catch (_) {console.info('[Sauna Stilo] Copia no preparada; vuelve a abrir con conexión.');}
  }
  window.addEventListener('flutter-first-frame',prepare,{once:true});
})();
''')
print('Applied reviewed SDK repairs, bounded game validation, complete-game tests and late public SDK warming.')
