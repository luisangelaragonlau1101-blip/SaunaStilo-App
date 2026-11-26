'use strict';
const {createHash} = require('node:crypto');

// Firestore events are at least once. A short lease prevents concurrent
// invocation duplicates; a successful FCM acknowledgement is kept permanently.
// Network failure after FCM acceptance can still retry, so the payload also
// uses a stable notification tag on every platform.
async function deliverBatch({db,key,tokens,payload,send,now=Date.now()}) {
  const digest=createHash('sha256').update(JSON.stringify([key,tokens])).digest('hex');
  const ref=db.collection('push_entregas').doc(digest);
  const claimed=await db.runTransaction(async tx=>{
    const previous=await tx.get(ref),data=previous.data() || {};
    if (data.estado==='enviado') return false;
    if (data.estado==='enviando' && data.venceEn>now) throw new Error('push-delivery-in-progress');
    tx.set(ref,{estado:'enviando',venceEn:now+120000,notificacionId:key,intentos:(data.intentos || 0)+1});
    return true;
  });
  if (!claimed) return null;
  try {
    const response=await send({tokens,...payload});
    await ref.set({estado:'enviado',enviadoEn:Date.now(),aceptados:response.successCount || 0,fallidos:response.failureCount || 0},{merge:true});
    return response;
  } catch (error) {
    await ref.set({estado:'pendiente',venceEn:0},{merge:true});
    throw error;
  }
}
module.exports={deliverBatch};
