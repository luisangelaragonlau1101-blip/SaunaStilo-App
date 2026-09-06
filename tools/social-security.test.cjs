const test=require('node:test');const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc}=require('firebase/firestore');
let env;
test.before(async()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated emulator required');env=await initializeTestEnvironment({projectId:'demo-sauna-social-audio',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});await env.withSecurityRulesDisabled(async c=>{for(const [id,rol] of [['admin','admin'],['a','trabajador'],['b','maestro']])await setDoc(doc(c.firestore(),'usuarios',id),{rol,nombre:id,correo:id+'@example.invalid'});});});
test.after(async()=>{if(env)await env.cleanup();});
test('both users can send audio metadata and read each other in their real conversation model',async()=>{
 const a=env.authenticatedContext('a').firestore(),b=env.authenticatedContext('b').firestore();
 await assertSucceeds(setDoc(doc(a,'conversaciones','privado_a_b'),{participantes:['a','b']}));
 await assertSucceeds(setDoc(doc(a,'conversaciones','privado_a_b','mensajes','audio-a'),{autorId:'a',tipo:'audio',audioUrl:'https://example.invalid/audio.wav'}));
 await assertSucceeds(setDoc(doc(b,'conversaciones','privado_a_b','mensajes','audio-b'),{autorId:'b',tipo:'audio',audioUrl:'https://example.invalid/reply.wav'}));
 await assertSucceeds(getDoc(doc(a,'conversaciones','privado_a_b','mensajes','audio-b')));
 await assertSucceeds(getDoc(doc(b,'conversaciones','privado_a_b','mensajes','audio-a')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'conversaciones','privado_a_b','mensajes','audio-a')));
});
test('social links remain owner-editable without granting account or role permissions',async()=>{
 const a=env.authenticatedContext('a').firestore();
 await assertSucceeds(updateDoc(doc(a,'usuarios','a'),{redesSociales:{instagram:'https://instagram.com/saunastilo',spotify:'https://open.spotify.com/user/example'}}));
 await assertFails(updateDoc(doc(a,'usuarios','b'),{redesSociales:{web:'https://example.com'}}));
 await assertFails(updateDoc(doc(a,'usuarios','a'),{rol:'admin'}));
});
test('notes are shared team posts with durable owner update and delete',async()=>{
 const a=env.authenticatedContext('a').firestore(),b=env.authenticatedContext('b').firestore();const path=['publicaciones_sociales','nota_equipo_a'];
 await assertSucceeds(setDoc(doc(a,...path),{autorId:'a',tipo:'nota_equipo',estado:'nota',notaTexto:'Primera nota',musicaUrl:'https://open.spotify.com/track/test'}));
 await assertSucceeds(getDoc(doc(b,...path)));
 await assertFails(updateDoc(doc(b,...path),{notaTexto:'Editar nota ajena'}));
 await assertSucceeds(updateDoc(doc(a,...path),{notaTexto:'Actualizada'}));
 await assertFails(deleteDoc(doc(b,...path)));await assertSucceeds(deleteDoc(doc(a,...path)));
});
