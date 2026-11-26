'use strict';

const crypto = require('node:crypto');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const access = require('./enterprise-access');

const ORDERS = 'instalacion_ordenes';
const stamp = () => FieldValue.serverTimestamp();
const fail = (message, code = 'failed-precondition') => { throw new HttpsError(code, message); };
const text = (value, max = 1000) => String(value ?? '').trim().slice(0, max);
const integer = (value, min = 0, max = 1000000) => {
  if (!Number.isSafeInteger(value) || value < min || value > max) fail('Revisa las cantidades.', 'invalid-argument');
  return value;
};
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])]));
  return value;
}
const hash = value => crypto.createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(stable(value))).digest('hex');
const key = value => {
  const result = text(value, 100);
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(result)) fail('Referencia inválida.', 'invalid-argument');
  return result;
};
const manager = p => access.canManageInstallations(p);
const coordinator = p => access.canCoordinateInstallations(p);
const member = (order, uid, p) => manager(p) || (order.participantes || []).includes(uid);
const active = profile => profile && profile.activo !== false;
const iso = value => value && typeof value.toDate === 'function' ? value.toDate().toISOString() : value;
function wire(value) {
  if (value && typeof value.toDate === 'function') return iso(value);
  if (Array.isArray(value)) return value.map(wire);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k,wire(v)]));
  return value;
}
function date(value) {
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) fail('Selecciona las fechas de salida y regreso.', 'invalid-argument');
  return Timestamp.fromDate(parsed);
}
function signature(raw) {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > 80) fail('Dibuja tu firma.', 'invalid-argument');
  let points = 0;
  const strokes = raw.map(stroke => {
    if (!Array.isArray(stroke) || stroke.length < 1) fail('Firma inválida.', 'invalid-argument');
    return stroke.map(point => {
      points++;
      if (!Array.isArray(point) || point.length !== 2 || point.some(n => typeof n !== 'number' || !Number.isFinite(n) || n < 0 || n > 1)) fail('Firma inválida.', 'invalid-argument');
      return point.map(n => Math.round(n * 10000) / 10000);
    });
  });
  if (points < 5 || points > 4000) fail('Dibuja una firma completa.', 'invalid-argument');
  // Firestore forbids nested arrays. Store strokes as maps of point maps.
  return strokes.map(points => ({puntos:points.map(([x,y])=>({x,y}))}));
}
function normalizeLines(raw) {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > 40) fail('Selecciona entre 1 y 40 artículos.', 'invalid-argument');
  const seen = new Set();
  return raw.map(row => {
    const sourceType = row.sourceType === 'cajita' ? 'cajita' : 'inventario';
    const sourceId = key(row.sourceId);
    const sourceKey = `${sourceType}:${sourceId}`;
    if (seen.has(sourceKey)) fail('Un artículo no puede aparecer dos veces en la misma orden.', 'invalid-argument');
    seen.add(sourceKey);
    return {id:hash(sourceKey).slice(0,20), sourceType, sourceId, tipo:['retornable','consumible','equipo'].includes(row.tipo) ? row.tipo : 'retornable', cantidad:integer(row.cantidad,1), preparada:0, preparadaConfirmada:false, estadoFisico:'bueno', observaciones:text(row.observaciones,500), numeroSerie:text(row.numeroSerie,120)};
  });
}
function completion(lines) {
  const prepared = lines.filter(l => l.preparadaConfirmada).length;
  return {preparados:prepared,total:lines.length,porcentaje:lines.length ? Math.round(prepared / lines.length * 100) : 0};
}
function returnLines(order, raw) {
  if (!Array.isArray(raw) || raw.length !== order.salida.lineas.length) fail('Registra el regreso de todos los artículos.');
  const seen = new Set();
  return order.salida.lineas.map(original => {
    const matches = raw.filter(r => r.id === original.id);
    if (matches.length !== 1 || seen.has(original.id)) fail('El regreso contiene artículos repetidos o desconocidos.');
    seen.add(original.id);
    const r = matches[0], salio = original.entregada;
    const devuelta = integer(r.devuelta), danada = integer(r.danada), utilizada = integer(r.utilizada), desperdicio = integer(r.desperdicio), instalada = integer(r.instalada);
    if (original.tipo === 'retornable' && (utilizada || desperdicio || instalada)) fail('Una herramienta retornable no puede registrarse como consumida.');
    if (original.tipo !== 'equipo' && instalada) fail('Solo los equipos destinados a instalarse se registran instalados.');
    if (original.tipo === 'equipo' && (utilizada || desperdicio)) fail('Indica el equipo instalado, devuelto o dañado.');
    const accounted = devuelta + danada + utilizada + desperdicio + instalada;
    if (accounted > salio) fail('No pueden regresar o consumirse más unidades de las entregadas.');
    const faltante = salio - accounted;
    return {...original, devuelta, danada, utilizada, desperdicio, instalada, faltante, clasificacion:danada ? 'devuelta_danada' : faltante ? (r.clasificacion === 'extraviada' ? 'extraviada' : 'pendiente') : 'devuelta', observacionesRegreso:text(r.observacionesRegreso,1000)};
  });
}
function validateDeparture(order, justification) {
  if (!order.lineas.length || order.lineas.some(l => !l.preparadaConfirmada)) fail('Completa la preparación de todos los artículos.');
  if (order.lineas.some(l => l.preparada < l.cantidad || l.estadoFisico !== 'bueno') && !text(justification)) fail('Justifica los faltantes o artículos dañados antes de autorizar.');
  if (!order.lineas.some(l => l.preparada > 0)) fail('La salida debe incluir al menos un artículo.');
}
async function readActor(db, uid) {
  if (!uid) fail('Inicia sesión.', 'unauthenticated');
  const snap = await db.collection('usuarios').doc(uid).get();
  const profile = snap.data();
  if (!snap.exists || !active(profile)) fail('Tu perfil no tiene acceso.', 'permission-denied');
  return profile;
}
function requireMember(order, uid, profile) {
  if (!member(order,uid,profile)) fail('Esta orden no está asignada a tu cuenta.', 'permission-denied');
}
function notice(tx, db, id, uid, title, message, orderId, actor) {
  tx.set(db.collection('notificaciones').doc(`inst_${id}_${uid}`), {titulo:title,mensaje:message,tipo:'instalacion',destinatarioId:uid,rolesDestinatarios:[],leidosPor:[],creadoPor:actor,fecha:stamp(),pantalla:'instalacion',orderId,installationOrderId:orderId});
}
function adminNotice(tx, db, id, title, message, orderId, actor) {
  tx.set(db.collection('notificaciones').doc(`inst_admin_${id}`), {titulo:title,mensaje:message,tipo:'instalacion',destinatarioId:'',rolesDestinatarios:['admin'],leidosPor:[],creadoPor:actor,fecha:stamp(),pantalla:'instalacion',orderId,installationOrderId:orderId});
}
async function catalog(db, uid, profile) {
  const [projects, stock, boxes, people, templates] = await Promise.all([
    (manager(profile) ? db.collection('proyectos') : db.collection('proyectos').where('encargados','array-contains',uid)).limit(200).get(),
    db.collection('insumos_inventario').limit(400).get(),
    (manager(profile) ? db.collection('cajitas_inventario') : db.collection('cajitas_inventario').where('trabajador_actual_id','==',uid)).limit(400).get(),
    manager(profile) ? db.collection('usuarios').where('activo','==',true).limit(300).get() : Promise.resolve({docs:[]}),
    db.collection('instalacion_plantillas').limit(100).get(),
  ]);
  return {projects:projects.docs.map(d=>({id:d.id,titulo:d.data().titulo||'Proyecto'})),stock:stock.docs.map(d=>({id:d.id,nombre:d.data().nombre||'Artículo',disponible:Number(d.data().cantidad_disponible)||0,sourceType:'inventario'})),boxes:boxes.docs.filter(d=>!d.data().ordenInstalacionId&&d.data().estado==='asignado').map(d=>({id:d.id,nombre:d.data().nombre||'Herramienta personal',responsableId:d.data().trabajador_actual_id,disponible:1,sourceType:'cajita'})),people:people.docs.map(d=>({id:d.id,nombre:d.data().nombre||'Compañero',rol:d.data().rol})),templates:templates.docs.map(d=>({id:d.id,...wire(d.data())}))};
}

async function runInstallationAction({db,uid,data,storage}) {
  const profile = await readActor(db,uid);
  const action = text(data.action,60);
  if (action === 'catalog') {
    const assigned = data.orderId ? await db.collection(ORDERS).doc(key(data.orderId)).get() : null;
    if (assigned) {
      if (!assigned.exists) fail('La orden no está disponible.', 'not-found');
      requireMember(assigned.data(),uid,profile);
    }
    if (!manager(profile) && !coordinator(profile) && !assigned?.exists) fail('Abre una orden asignada para consultar materiales.', 'permission-denied');
    const result = await catalog(db,uid,profile);
    if (!manager(profile) && assigned?.exists) {
      const ids = [...new Set(assigned.data().participantes || [])].slice(0,30);
      const people = ids.length ? await db.getAll(...ids.map(id=>db.collection('usuarios').doc(id))) : [];
      result.people = people.filter(p=>p.exists&&active(p.data())).map(p=>({id:p.id,nombre:text(p.data().nombre,160)||'Responsable',rol:p.data().rol}));
    }
    return result;
  }
  if (action === 'list') {
    let q = manager(profile) ? db.collection(ORDERS) : db.collection(ORDERS).where('participantes','array-contains',uid);
    if(data.afterId){const cursor=await db.collection(ORDERS).doc(key(data.afterId)).get();if(cursor.exists){requireMember(cursor.data(),uid,profile);q=q.startAfter(cursor);}}
    const snap = await q.limit(100).get();
    return {orders:snap.docs.map(d=>({id:d.id,...wire(d.data())})).sort((a,b)=>String(b.creadoEn).localeCompare(String(a.creadoEn))),limited:snap.size===100,nextCursor:snap.size===100?snap.docs.at(-1).id:null};
  }
  if (action === 'read' || action === 'document' || action === 'photo') {
    const id = key(data.orderId);
    const snap = await db.collection(ORDERS).doc(id).get();
    if (!snap.exists) fail('La orden no está disponible.', 'not-found');
    requireMember(snap.data(),uid,profile);
    if(action==='photo'){
      const photo=(snap.data().fotos||[]).find(p=>p.path===data.path);if(!photo)fail('La fotografía no pertenece a esta orden.', 'not-found');
      return {path:photo.path};
    }
    if (action === 'document') {
      const phase = data.phase === 'devolucion' ? 'devolucion' : 'salida';
      const file = await ensureDocument(db,storage,id,phase);
      return {path:file.path,sha256:file.sha256};
    }
    const events = await snap.ref.collection('eventos').orderBy('fecha','desc').limit(100).get();
    return {order:{id,...wire(snap.data())},events:events.docs.map(d=>({id:d.id,...wire(d.data())}))};
  }
  const operationId = key(data.operationId);
  if (operationId.length < 8) fail('Identificador de operación inválido.', 'invalid-argument');
  const fingerprint = hash({...data,operationId:undefined});
  const opRef = db.collection('instalacion_operaciones').doc(`${uid}_${operationId}`);
  const id = action === 'create' ? `ord_${hash(`${uid}:${operationId}`).slice(0,24)}` : key(data.orderId || data.templateId || operationId);
  const orderRef = db.collection(ORDERS).doc(id);
  let uploadedPhoto;
  if(action==='upload-photo'){
    const current=await orderRef.get();if(!current.exists)fail('La orden no existe.');requireMember(current.data(),uid,profile);
    if(!storage)fail('El almacenamiento no está configurado.');
    const encoded=data.base64;if(typeof encoded!=='string'||encoded.length>4500000||!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded))fail('La imagen debe pesar como máximo 3 MB.', 'invalid-argument');
    const bytes=Buffer.from(encoded,'base64');
    if(bytes.length<20||bytes.length>3*1024*1024||bytes[0]!==0xff||bytes[1]!==0xd8||bytes[2]!==0xff)fail('Selecciona una fotografía JPEG válida.', 'invalid-argument');
    const path=`instalaciones/${id}/evidencias/${operationId}.jpg`;const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
    await immutableFile(storage,path,bytes,'image/jpeg',{orderId:id,sha256});
    uploadedPhoto={path,sha256,usuarioId:uid,nombre:text(data.nombre,160)||'Fotografía',fecha:Timestamp.now()};
  }
  const result = await db.runTransaction(async tx => {
    const actorSnap = await tx.get(db.collection('usuarios').doc(uid));
    const actor = actorSnap.data();
    if (!actorSnap.exists || !active(actor)) fail('Tu perfil no tiene acceso.', 'permission-denied');
    const op = await tx.get(opRef);
    if (op.exists) {
      if (op.data().fingerprint !== fingerprint) fail('Este identificador ya se usó con otros datos.', 'already-exists');
      return op.data().result;
    }
    const now = Timestamp.now();
    let result = {orderId:id};
    if (action === 'template-save') {
      if (!manager(actor)) fail('Solo Administración puede guardar plantillas.', 'permission-denied');
      const lines = normalizeLines(data.lineas);
      const name = text(data.nombre,120);
      if (name.length < 3) fail('Escribe el nombre de la plantilla.', 'invalid-argument');
      tx.set(db.collection('instalacion_plantillas').doc(id), {nombre:name,lineas:lines.map(({id,sourceType,sourceId,tipo,cantidad,numeroSerie})=>({id,sourceType,sourceId,tipo,cantidad,numeroSerie})),creadoPor:uid,actualizadoEn:now});
      result = {templateId:id};
    } else if (action === 'create') {
      if (!manager(actor)) fail('Solo Administración puede crear órdenes.', 'permission-denied');
      const projectId = key(data.proyectoId), prepId = key(data.preparadorId), driverId = key(data.transportistaId), receiverId = key(data.receptorTallerId || uid);
      const lines = normalizeLines(data.lineas);
      const refs = [db.collection('proyectos').doc(projectId),...Array.from(new Set([prepId,driverId,receiverId])).map(p=>db.collection('usuarios').doc(p)),...lines.map(l=>db.collection(l.sourceType==='cajita'?'cajitas_inventario':'insumos_inventario').doc(l.sourceId))];
      const docs = await tx.getAll(...refs);
      const project = docs[0];
      if (!project.exists) fail('El proyecto no existe.');
      const people = new Map(docs.slice(1,refs.length-lines.length).map(d=>[d.id,d.data()]));
      if ([prepId,driverId,receiverId].some(p=>!active(people.get(p)))) fail('Selecciona responsables con cuenta activa.');
      docs.slice(refs.length-lines.length).forEach((s,i)=> {
        if (!s.exists) fail('Un artículo ya no existe.');
        if (lines[i].sourceType==='cajita'&&(lines[i].cantidad!==1||lines[i].tipo!=='retornable')) fail('Cada herramienta de Cajita es una pieza retornable.');
        lines[i].nombre=text(s.data().nombre||'Artículo',160);
        lines[i].unidad=text(s.data().unidad_medida||'pieza',60);
        if (lines[i].sourceType==='cajita') lines[i].propietarioId=s.data().trabajador_actual_id;
      });
      const salida=date(data.fechaSalida), regreso=date(data.fechaRegreso);
      if (regreso.toMillis()<salida.toMillis()) fail('El regreso debe ser posterior a la salida.');
      const order = {folio:`INS-${now.toDate().getFullYear()}-${id.slice(-6).toUpperCase()}`,proyectoId:projectId,proyectoTitulo:text(project.data().titulo||'Proyecto',160),preparadorId:prepId,preparadorNombre:text(people.get(prepId).nombre,160),transportistaId:driverId,transportistaNombre:text(people.get(driverId).nombre,160),receptorTallerId:receiverId,receptorTallerNombre:text(people.get(receiverId).nombre,160),participantes:[...new Set([prepId,driverId,receiverId,uid,...(Array.isArray(project.data().encargados)?project.data().encargados.filter(p=>typeof p==='string').slice(0,40):[])])],editores:[prepId],fechaSalida:salida,fechaRegreso:regreso,lineas:lines,estado:'preparacion',version:1,progreso:completion(lines),fotos:[],firmas:{},observaciones:text(data.observaciones,2000),creadoPor:uid,creadoEn:now,actualizadoEn:now};
      tx.create(orderRef,order);
      tx.create(orderRef.collection('eventos').doc(operationId),{accion:'create',usuarioId:uid,usuarioNombre:text(actor.nombre,160),fecha:now,version:1,estadoNuevo:'preparacion'});
      tx.create(db.collection('actividades').doc(`instalacion_${id}`),{proyectoId:projectId,titulo:`Preparar herramientas · ${order.proyectoTitulo}`,descripcion:'Abre el checklist de instalación, guarda las cantidades y termina la preparación.',asignadoATrabajadorId:prepId,fechaInicio:now,fechaTermino:salida,fechaAsignada:now,completadoEn:null,estatus:'pendiente',observacionesAdmin:'',comentariosTrabajador:'',evidenciaFotos:[],historialEventos:[],evidenciasCount:0,cantidadEvidencias:0,ultimoAvance:0,requiereEvidencia:false,creadoPor:uid,creadoEn:now,workKind:'preparacion',installationOrderId:id});
      notice(tx,db,operationId,prepId,'Herramientas por preparar',`Prepara las herramientas para ${order.proyectoTitulo}.`,id,uid);
    } else {
      const snap = await tx.get(orderRef);
      if (!snap.exists) fail('La orden no existe.', 'not-found');
      const order = snap.data();
      requireMember(order,uid,actor);
      const isEditor = manager(actor)||(order.editores||[]).includes(uid);
      const event = {accion:action,usuarioId:uid,usuarioNombre:text(actor.nombre,160),fecha:now,version:order.version};
      const changes = {actualizadoEn:now};
      if (action === 'save-checklist' || action === 'finish-preparation') {
        if (!isEditor || !['preparacion','lista'].includes(order.estado)) fail('No puedes modificar esta preparación.', 'permission-denied');
        if (data.expectedVersion!==order.version) fail('La lista cambió. Actualiza antes de guardar.', 'aborted');
        if (!Array.isArray(data.lineas)||data.lineas.length!==order.lineas.length) fail('La lista debe conservar todos los artículos.');
        const lines=order.lineas.map(l=>{
          const matches=data.lineas.filter(r=>r.id===l.id);
          if (matches.length!==1) fail('Hay artículos repetidos o desconocidos.');
          const r=matches[0];
          return {...l,preparada:integer(r.preparada),preparadaConfirmada:r.preparadaConfirmada===true,estadoFisico:['bueno','danado','reparacion'].includes(r.estadoFisico)?r.estadoFisico:'bueno',observaciones:text(r.observaciones,1000)};
        });
        if (action==='finish-preparation'&&lines.some(l=>!l.preparadaConfirmada)) fail('Confirma todos los artículos o registra su faltante.');
        Object.assign(changes,{lineas:lines,progreso:completion(lines),version:order.version+1,estado:action==='finish-preparation'?'lista':'preparacion'});
        tx.update(db.collection('actividades').doc(`instalacion_${id}`),{estatus:action==='finish-preparation'?'en_revision':'en_progreso',ultimoAvance:completion(lines).porcentaje,...(action==='finish-preparation'?{completadoEn:now}:{}),actualizadoEn:now});
        if(action==='finish-preparation') adminNotice(tx,db,operationId,'Preparación por revisar',`Revisa la salida de ${order.proyectoTitulo}.`,id,uid);
      } else if (action==='add-material') {
        if(!isEditor||!['preparacion','lista'].includes(order.estado)) fail('No puedes añadir materiales a esta versión.', 'permission-denied');
        if(data.expectedVersion!==order.version) fail('La lista cambió. Actualiza antes de agregar.', 'aborted');
        const raw=normalizeLines([data.material])[0];
        if(order.lineas.length>=40||order.lineas.some(l=>l.sourceType===raw.sourceType&&l.sourceId===raw.sourceId)) fail('El artículo ya existe o la lista está completa.');
        const source=await tx.get(db.collection(raw.sourceType==='cajita'?'cajitas_inventario':'insumos_inventario').doc(raw.sourceId));
        if(!source.exists) fail('El artículo no existe.');
        if(raw.sourceType==='cajita'&&(raw.cantidad!==1||raw.tipo!=='retornable')) fail('Una herramienta de Cajita es una pieza retornable.');
        raw.nombre=text(source.data().nombre||'Artículo',160);raw.unidad=text(source.data().unidad_medida||'pieza',60);
        if(raw.sourceType==='cajita') raw.propietarioId=source.data().trabajador_actual_id;
        const lines=[...order.lineas,raw];Object.assign(changes,{lineas:lines,version:order.version+1,estado:'preparacion',progreso:completion(lines)});
      } else if(action==='authorize-departure') {
        if(!manager(actor)) fail('Solo Administración puede autorizar una salida.', 'permission-denied');
        if(order.estado!=='lista') fail('La preparación debe estar terminada antes de autorizar.');
        validateDeparture(order,data.justificacion);
        const sourceRefs=order.lineas.map(l=>db.collection(l.sourceType==='cajita'?'cajitas_inventario':'insumos_inventario').doc(l.sourceId));
        const sourceDocs=await tx.getAll(...sourceRefs);
        sourceDocs.forEach((s,i)=>{
          const l=order.lineas[i];if(!s.exists)fail('Un artículo ya no existe.');
          if(l.sourceType==='inventario') {if(!Number.isSafeInteger(s.data().cantidad_disponible)||s.data().cantidad_disponible<l.preparada)fail(`Stock insuficiente: ${l.nombre}.`);}
          else if(l.preparada>0&&(l.preparada!==1||s.data().estado!=='asignado'||s.data().ordenInstalacionId||s.data().traspaso_pendiente_id||s.data().trabajador_actual_id!==l.propietarioId))fail(`La Cajita ya no tiene disponible ${l.nombre}.`);
        });
        const frozen=order.lineas.map(l=>({...l,entregada:l.preparada}));
        const snapshotHash=hash(wire({orderId:id,version:order.version,lineas:frozen,preparadorId:order.preparadorId,transportistaId:order.transportistaId}));
        Object.assign(changes,{estado:'autorizada',salida:{version:order.version,lineas:frozen,hash:snapshotHash,autorizadaPor:uid,autorizadaNombre:text(actor.nombre,160),fechaAutorizacion:now,justificacion:text(data.justificacion,2000),fotos:order.fotos||[]},firmas:{},version:order.version+1});
        sourceDocs.forEach((s,i)=>{
          const l=frozen[i];if(l.entregada===0)return;
          if(l.sourceType==='inventario')tx.update(sourceRefs[i],{cantidad_disponible:s.data().cantidad_disponible-l.entregada,ultima_actualizacion:now});
          else tx.update(sourceRefs[i],{ordenInstalacionId:id,prestamoProyectoId:order.proyectoId,prestamoProyectoFase:'reservada',prestamoProyectoDesde:now});
          const req=db.collection('solicitudes_herramientas').doc(`inst_${id}_${l.id}`);
          tx.create(req,{origenOrden:id,sourceType:l.sourceType,proyectoId:order.proyectoId,proyectoNombre:order.proyectoTitulo,trabajadorId:order.transportistaId,trabajadorNombre:order.transportistaNombre,insumoId:l.sourceType==='inventario'?l.sourceId:'',cajitaId:l.sourceType==='cajita'?l.sourceId:'',nombreInsumo:l.nombre,cantidad:l.entregada,esRetornable:l.tipo==='retornable',estatus:'aprobada',marcadoDevueltoTrabajador:false,devueltoConfirmadoAdmin:false,tieneReporteFalla:false,fechaSolicitud:order.creadoEn,fechaAprobacion:now,fechaLimiteDevolucion:order.fechaRegreso,autorizadoPorAdminId:uid});
          tx.create(req.collection('historial').doc('salida'),{accion:'salida',origenOrden:id,solicitudId:req.id,insumoId:l.sourceId,cantidad:l.entregada,responsableId:uid,responsableNombre:text(actor.nombre,160),trabajadorId:order.transportistaId,fecha:now,conFalla:l.estadoFisico!=='bueno',observacion:'Reservado para la salida firmada de instalación.'});
        });
        tx.update(db.collection('actividades').doc(`instalacion_${id}`),{estatus:'completado',ultimoAvance:100,aprobadoPor:uid,aprobadoEn:now,actualizadoEn:now});
        for(const recipient of new Set([order.preparadorId,order.transportistaId])) notice(tx,db,operationId,recipient,'Salida por firmar',`Confirma la entrega de herramientas para ${order.proyectoTitulo}.`,id,uid);
      } else if(action==='sign-departure') {
        if(order.estado!=='autorizada')fail('Esta salida ya no está disponible para firma.');
        const side=data.side==='entrega'?'entrega':data.side==='recibe'?'recibe':null;if(!side)fail('Firma inválida.');
        const expected=side==='entrega'?order.preparadorId:order.transportistaId;
        if(uid!==expected)fail('Cada responsable debe firmar con su propia cuenta.', 'permission-denied');
        if(order.firmas?.[side])fail('Esta firma ya está guardada.');
        if(data.snapshotHash!==order.salida.hash)fail('Actualiza la orden antes de firmar.', 'aborted');
        const signed={usuarioId:uid,nombre:text(actor.nombre,160),fecha:now,trazos:signature(data.signature),snapshotHash:order.salida.hash};
        const signatures={...(order.firmas||{}),[side]:signed};
        changes.firmas=signatures;
        if(signatures.entrega&&signatures.recibe) {
          if(order.preparadorId===order.transportistaId&&!order.validacionMismaPersona) changes.estado='validacion_administrativa';
          else {changes.estado='en_instalacion';changes.salidaConfirmadaEn=now;}
        }
        if(changes.estado==='validacion_administrativa')adminNotice(tx,db,operationId,'Entrega y recepción por validar','La misma persona firmó entrega y recepción. Revisa la circunstancia.',id,uid);
        result.phase='salida';
      } else if(action==='validate-same-person') {
        if(!manager(actor)||order.estado!=='validacion_administrativa'||!text(data.justificacion))fail('Administración debe justificar esta validación.', 'permission-denied');
        Object.assign(changes,{validacionMismaPersona:{usuarioId:uid,nombre:text(actor.nombre,160),fecha:now,justificacion:text(data.justificacion,2000)},estado:'en_instalacion',salidaConfirmadaEn:now});
        result.phase='salida';
      } else if(action==='upload-photo'){
        if(order.estado==='cancelada'||order.estado==='cerrada'||(order.fotos||[]).length>=20)fail('Esta orden no permite más fotografías.');
        changes.fotos=[...(order.fotos||[]),uploadedPhoto];event.foto=uploadedPhoto;
      } else if(action==='report') {
        if(!['autorizada','en_instalacion','devolucion','diferencias'].includes(order.estado)||!text(data.observaciones))fail('Describe el daño, pérdida, consumo o ajuste.');
        event.observaciones=text(data.observaciones,2000);event.tipo=['danio','perdida','consumo','traspaso','ajuste'].includes(data.tipo)?data.tipo:'ajuste';
        if(event.tipo==='traspaso'){
          if(!order.participantes.includes(data.destinoId))fail('El destinatario debe ser responsable de esta orden.');
          event.destinoId=data.destinoId;event.custodiaNoConfirmada=true;
        }
        adminNotice(tx,db,operationId,'Reporte de instalación','Hay un reporte de materiales por revisar.',id,uid);
      } else if(action==='request-transfer'){
        if(order.estado!=='en_instalacion'||order.traspasoPendiente)fail('No hay una custodia disponible para traspasar.');
        const owner=order.custodioActualId||order.transportistaId;
        if(uid!==owner&&!manager(actor))fail('Solo el responsable actual puede iniciar el traspaso.', 'permission-denied');
        const target=key(data.destinoId);if(target===owner||!order.participantes.includes(target))fail('Selecciona otro integrante de esta instalación.');
        const targetSnap=await tx.get(db.collection('usuarios').doc(target));if(!targetSnap.exists||!active(targetSnap.data()))fail('El destinatario no tiene una cuenta activa.');
        changes.traspasoPendiente={desdeId:owner,haciaId:target,haciaNombre:text(targetSnap.data().nombre,160),solicitadoPor:uid,fecha:now,snapshotHash:order.salida.hash};
        notice(tx,db,operationId,target,'Resguardo por confirmar','Confirma que recibiste las herramientas de la instalación.',id,uid);
      } else if(action==='accept-transfer'){
        const pending=order.traspasoPendiente;
        if(order.estado!=='en_instalacion'||!pending||pending.haciaId!==uid)fail('Esta recepción no está asignada a tu cuenta.', 'permission-denied');
        if(data.snapshotHash!==pending.snapshotHash)fail('La entrega cambió. Actualiza antes de confirmar.', 'aborted');
        event.firma={usuarioId:uid,nombre:text(actor.nombre,160),fecha:now,trazos:signature(data.signature),snapshotHash:pending.snapshotHash};event.traspaso=pending;
        changes.custodioActualId=uid;changes.custodioActualNombre=text(actor.nombre,160);changes.traspasoPendiente=FieldValue.delete();
        notice(tx,db,operationId,pending.desdeId,'Resguardo confirmado','El técnico confirmó la recepción de las herramientas.',id,uid);
      } else if(action==='cancel-transfer'){
        if(order.estado!=='en_instalacion'||!order.traspasoPendiente||(!manager(actor)&&![order.traspasoPendiente.desdeId,order.traspasoPendiente.haciaId].includes(uid)))fail('No puedes cancelar este traspaso.', 'permission-denied');
        event.traspaso=order.traspasoPendiente;changes.traspasoPendiente=FieldValue.delete();
      } else if(action==='start-return') {
        if(order.estado!=='en_instalacion')fail('La salida debe estar firmada y validada antes de registrar el regreso.');
        const owner=order.custodioActualId||order.transportistaId;
        if(uid!==owner&&!manager(actor))fail('Solo el responsable de resguardo o Administración puede registrar la devolución.', 'permission-denied');
        if(order.traspasoPendiente)fail('Confirma o cancela el traspaso pendiente antes de devolver.');
        const returned=returnLines(order,data.lineas);
        const snapshotHash=hash(wire({salidaHash:order.salida.hash,lineas:returned,version:order.version}));
        Object.assign(changes,{estado:'devolucion',devolucion:{lineas:returned,version:order.version,hash:snapshotHash,registradaPor:uid,fechaRegistro:now,devuelveId:owner,devuelveNombre:order.custodioActualNombre||order.transportistaNombre,fotos:order.fotos||[]},firmasDevolucion:{},version:order.version+1});
        notice(tx,db,operationId,owner,'Devolución por firmar','Firma el regreso de las herramientas.',id,uid);
        notice(tx,db,operationId,order.receptorTallerId,'Recepción de herramientas','Revisa y firma las cantidades que vuelven al taller.',id,uid);
      } else if(action==='sign-return') {
        if(order.estado!=='devolucion')fail('No hay una devolución pendiente de firma.');
        const side=data.side==='devuelve'?'devuelve':data.side==='recibe'?'recibe':null;if(!side)fail('Firma inválida.');
        if(uid!==(side==='devuelve'?(order.devolucion.devuelveId||order.transportistaId):order.receptorTallerId))fail('Cada responsable debe firmar con su propia cuenta.', 'permission-denied');
        if(order.firmasDevolucion?.[side])fail('Esta firma ya está guardada.');
        if(data.snapshotHash!==order.devolucion.hash)fail('La devolución cambió. Actualiza antes de firmar.', 'aborted');
        const signatures={...(order.firmasDevolucion||{}),[side]:{usuarioId:uid,nombre:text(actor.nombre,160),fecha:now,trazos:signature(data.signature),snapshotHash:order.devolucion.hash}};
        changes.firmasDevolucion=signatures;
        if(signatures.devuelve&&signatures.recibe){changes.estado='diferencias';adminNotice(tx,db,operationId,'Devolución por conciliar','Revisa faltantes, daños y consumos antes de cerrar.',id,uid);}
        result.phase='devolucion';
      } else if(action==='resolve-personal-tool'){
        if(!manager(actor)||order.estado!=='cerrada'||!text(data.resolucion))fail('Administración debe documentar esta recuperación.', 'permission-denied');
        const line=order.devolucion.lineas.find(l=>l.id===data.lineId&&l.sourceType==='cajita'&&l.entregada===1&&l.devuelta===0);
        if(!line||order.resolucionesCajita?.[line.id])fail('Esta herramienta no tiene una recuperación pendiente.');
        const sourceRef=db.collection('cajitas_inventario').doc(line.sourceId),source=await tx.get(sourceRef);
        if(!source.exists||source.data().ordenInstalacionId!==id)fail('La herramienta ya no está vinculada a esta orden.');
        tx.update(sourceRef,{ordenInstalacionId:FieldValue.delete(),prestamoProyectoId:FieldValue.delete(),prestamoProyectoFase:FieldValue.delete(),prestamoProyectoDesde:FieldValue.delete(),ultimoRegresoInstalacionEn:now});
        changes.resolucionesCajita={...(order.resolucionesCajita||{}),[line.id]:{usuarioId:uid,fecha:now,resolucion:text(data.resolucion,2000)}};
      } else if(action==='close-return') {
        if(!manager(actor)||order.estado!=='diferencias'||!order.firmasDevolucion?.devuelve||!order.firmasDevolucion?.recibe)fail('Administración debe revisar ambas firmas antes de cerrar.', 'permission-denied');
        const missing=order.devolucion.lineas.some(l=>l.faltante>0);
        if(missing&&!text(data.resolucion))fail('No se puede cerrar con faltantes sin una resolución administrativa.');
        if((order.devolucion.devuelveId||order.transportistaId)===order.receptorTallerId&&!text(data.resolucion))fail('Justifica la devolución recibida por la misma persona.');
        const sourceRefs=order.devolucion.lineas.map(l=>db.collection(l.sourceType==='cajita'?'cajitas_inventario':'insumos_inventario').doc(l.sourceId));
        const sourceDocs=await tx.getAll(...sourceRefs);
        sourceDocs.forEach((s,i)=>{if(!s.exists)fail('Un artículo ya no existe. Conserva la orden y resuelve su inventario.');const l=order.devolucion.lineas[i];if(l.sourceType==='cajita'&&l.entregada>0&&s.data().ordenInstalacionId!==id)fail('La herramienta personal ya no está vinculada a esta orden.');});
        sourceDocs.forEach((s,i)=>{
          const l=order.devolucion.lineas[i];if(l.entregada===0)return;
          if(l.sourceType==='inventario')tx.update(sourceRefs[i],{cantidad_disponible:integer(s.data().cantidad_disponible)+l.devuelta,en_reparacion:integer(s.data().en_reparacion||0)+l.danada,ultima_actualizacion:now});
          else if(l.devuelta===1)tx.update(sourceRefs[i],{ordenInstalacionId:FieldValue.delete(),prestamoProyectoId:FieldValue.delete(),prestamoProyectoFase:FieldValue.delete(),prestamoProyectoDesde:FieldValue.delete(),ultimoRegresoInstalacionEn:now});
          else tx.update(sourceRefs[i],{prestamoProyectoFase:l.danada?'en_reparacion':'extraviada',resolucionInstalacion:text(data.resolucion,2000)});
          const req=db.collection('solicitudes_herramientas').doc(`inst_${id}_${l.id}`);
          tx.update(req,{marcadoDevueltoTrabajador:l.devuelta+l.danada===l.entregada,devueltoConfirmadoAdmin:!l.faltante,tieneReporteFalla:l.danada>0,fechaRecepcion:now,recibidoPor:uid,devolucionOrden:{devuelta:l.devuelta,danada:l.danada,utilizada:l.utilizada,desperdicio:l.desperdicio,instalada:l.instalada,faltante:l.faltante},resolucionAdministrativa:text(data.resolucion,2000)});
          tx.create(req.collection('historial').doc('entrada'),{accion:'entrada',origenOrden:id,solicitudId:req.id,insumoId:l.sourceId,cantidad:l.devuelta+l.danada,responsableId:uid,responsableNombre:text(actor.nombre,160),trabajadorId:order.transportistaId,fecha:now,conFalla:l.danada>0,observacion:text(data.resolucion,2000)});
        });
        Object.assign(changes,{estado:'cerrada',cerradaPor:uid,cerradaNombre:text(actor.nombre,160),cerradaEn:now,resolucion:text(data.resolucion,2000)});
        notice(tx,db,operationId,order.transportistaId,'Devolución conciliada','Administración registró la recepción y resolvió las diferencias.',id,uid);
        result.phase='devolucion';
      } else if(action==='cancel') {
        if(!manager(actor)||!['preparacion','lista'].includes(order.estado))fail('Solo puede cancelarse una orden sin salida autorizada.', 'permission-denied');
        Object.assign(changes,{estado:'cancelada',canceladaPor:uid,canceladaEn:now});
        tx.update(db.collection('actividades').doc(`instalacion_${id}`),{estatus:'cancelada',actualizadoEn:now});
      } else if(action==='set-editors') {
        if(!manager(actor)||!['preparacion','lista'].includes(order.estado))fail('Solo Administración puede cambiar los editores antes de la salida.', 'permission-denied');
        const editors=Array.isArray(data.editores)?[...new Set(data.editores.map(key))]:[];
        if(editors.length>10||editors.some(e=>!order.participantes.includes(e)))fail('Los editores deben ser responsables de esta orden.');
        changes.editores=editors;
        for(const editor of editors) if(!(order.editores||[]).includes(editor)) notice(tx,db,operationId,editor,'Preparación de materiales','Administración te habilitó para editar el checklist de esta orden.',id,uid);
      } else fail('Acción no disponible.', 'invalid-argument');
      tx.update(orderRef,changes);
      tx.create(orderRef.collection('eventos').doc(operationId),{...event,...(data.observaciones?{observaciones:text(data.observaciones,2000)}:{}),estadoAnterior:order.estado,estadoNuevo:changes.estado||order.estado});
    }
    tx.create(opRef,{uid,action,orderId:id,fingerprint,result,fecha:now});
    return result;
  });
  if(result.phase&&storage){
    try{await ensureDocument(db,storage,result.orderId,result.phase);}catch(error){result.documentPending=true;}
  }
  return result;
}

// Small server PDF writer: signatures are vector paths from the authenticated
// saved strokes. No client-generated document can replace the signed snapshot.
function jpegSize(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes[0]!==255 || bytes[1]!==216) return null;
  let offset=2;
  while(offset+8<bytes.length){
    if(bytes[offset++]!==255) return null;
    let marker=bytes[offset++];while(marker===255&&offset<bytes.length)marker=bytes[offset++];
    if(marker===217||marker===218)return null;
    if(marker===216||marker===1||(marker>=208&&marker<=215))continue;
    if(offset+2>bytes.length)return null;
    const length=bytes.readUInt16BE(offset);if(length<2||offset+length>bytes.length)return null;
    if([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)){
      const height=bytes.readUInt16BE(offset+3),width=bytes.readUInt16BE(offset+5),components=bytes[offset+7];
      return width>0&&height>0&&width<=10000&&height<=10000&&[1,3].includes(components)?{width,height,components}:null;
    }
    offset+=length;
  }
  return null;
}
function createActaPdf(order, phase, imageFiles=[]) {
  const isReturn=phase==='devolucion',snapshot=isReturn?order.devolucion:order.salida;
  if(!snapshot)fail('No hay una versión autorizada para generar el acta.');
  const signatures=isReturn?order.firmasDevolucion:order.firmas;
  const entries=[];
  entries.push('SAUNA STILO',isReturn?'ACTA DE DEVOLUCION DE HERRAMIENTAS':'ACTA DE ENTREGA DE HERRAMIENTAS',`Orden: ${order.folio} | Version: ${snapshot.version}`,`Proyecto: ${order.proyectoTitulo}`,`Salida: ${iso(order.fechaSalida)} | Regreso previsto: ${iso(order.fechaRegreso)}`,`Huella: ${snapshot.hash}`,'');
  for(const line of snapshot.lineas){
    entries.push(`${line.nombre} | ${line.tipo} | Serie: ${line.numeroSerie||'No registrada'}`,isReturn?`Salio ${line.entregada} | Devuelta ${line.devuelta} | Danada ${line.danada} | Falta ${line.faltante}`:`Cantidad entregada: ${line.entregada} | Estado: ${line.estadoFisico}`,isReturn?`Utilizado ${line.utilizada} | Desperdicio ${line.desperdicio} | Instalado ${line.instalada}`:`Observaciones: ${line.observaciones||'-'}`);
    if(isReturn&&line.observacionesRegreso)entries.push(line.observacionesRegreso);
  }
  entries.push('',`Autorizo: ${order.salida.autorizadaNombre} | ${iso(order.salida.fechaAutorizacion)}`,`Justificacion: ${order.salida.justificacion||'-'}`,`Observaciones: ${order.observaciones||'-'}`);
  if(isReturn)entries.push(`Resolucion administrativa: ${order.resolucion||'Pendiente de revision'}`,`Revision: ${order.cerradaNombre||'Pendiente'} | ${iso(order.cerradaEn)||'-'}`);
  for(const photo of snapshot.fotos||[])entries.push(`Fotografia: ${photo.path} | ${photo.sha256}`);
  entries.push('Las firmas corresponden a confirmaciones internas autenticadas. No son e.firma del SAT.');
  const pages=[];let page='',y=800;
  const esc=s=>String(s).replace(/[^\x20-\xFF]/g,'?').replace(/[\\()]/g,'\\$&');
  function next(){if(page)pages.push(page);page='';y=800;}
  function line(s){for(let offset=0;offset<String(s).length||offset===0;offset+=92){if(y<65)next();page+=`BT /F1 10 Tf 42 ${y} Td (${esc(String(s).slice(offset,offset+92))}) Tj ET\n`;y-=15;}}
  entries.forEach(line);
  for(const [side,sign]of Object.entries(signatures||{})){
    if(y<170)next();line(`Firma ${side}: ${sign.nombre} | ${iso(sign.fecha)} | Usuario ${sign.usuarioId}`);
    const x0=45,y0=y-90,w=240,h=78;
    page+='0.1 0.1 0.1 RG 1 w\n';
    for(const stroke of sign.trazos){const points=Array.isArray(stroke)?stroke.map(p=>({x:p[0],y:p[1]})):stroke.puntos;points.forEach((p,i)=>{page+=`${(x0+p.x*w).toFixed(2)} ${(y0+(1-p.y)*h).toFixed(2)} ${i?'l':'m'}\n`;});page+='S\n';}y-=115;
  }
  next();
  const photos=imageFiles.map(file=>({...file,size:jpegSize(file.bytes)})).filter(file=>file.size).slice(0,3);
  photos.forEach((photo,index)=>{
    line(`Fotografia: ${photo.nombre||index+1}`);
    const scale=Math.min(510/photo.size.width,650/photo.size.height);
    const w=photo.size.width*scale,h=photo.size.height*scale;
    page+=`q ${w.toFixed(2)} 0 0 ${h.toFixed(2)} 42 ${(y-h).toFixed(2)} cm /Im${index} Do Q\n`;
    next();
  });
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'];
  const imageRefs=photos.map(photo=>{
    objects.push(`<< /Type /XObject /Subtype /Image /Width ${photo.size.width} /Height ${photo.size.height} /ColorSpace /${photo.size.components===1?'DeviceGray':'DeviceRGB'} /BitsPerComponent 8 /Filter /DCTDecode /Length ${photo.bytes.length} >>\nstream\n${photo.bytes.toString('latin1')}\nendstream`);
    return objects.length;
  });
  const imageResources=imageRefs.length?` /XObject << ${imageRefs.map((id,index)=>`/Im${index} ${id} 0 R`).join(' ')} >>`:'';
  const kids=[];
  for(const content of pages){const pageId=objects.length+1,contentId=pageId+1;kids.push(`${pageId} 0 R`);objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> ${imageResources} >> /Contents ${contentId} 0 R >>`);objects.push(`<< /Length ${Buffer.byteLength(content,'latin1')} >>\nstream\n${content}endstream`);}
  objects[1]=`<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${kids.length} >>`;
  let out='%PDF-1.4\n%\xFF\xFF\xFF\xFF\n';const offsets=[0];
  objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(out,'latin1'));out+=`${i+1} 0 obj\n${o}\nendobj\n`;});
  const xref=Buffer.byteLength(out,'latin1');out+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach(n=>out+=`${String(n).padStart(10,'0')} 00000 n \n`);
  out+=`trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(out,'latin1');
}
async function immutableFile(storage,path,bytes,contentType,metadata){
  const file=storage.bucket().file(path);
  try{await file.save(bytes,{resumable:false,contentType,preconditionOpts:{ifGenerationMatch:0},metadata:{cacheControl:'private, max-age=0',metadata}});}
  catch(error){if(Number(error.code)!==412)throw error;const [old]=await file.getMetadata();if(old.metadata?.sha256!==metadata.sha256)fail('Ya existe otro archivo para esta operación. Conserva el registro original.', 'already-exists');}
}
async function ensureDocument(db,storage,id,phase){
  if(!storage)fail('El almacenamiento no está configurado.');
  const ref=db.collection(ORDERS).doc(id),snap=await ref.get(),order=snap.data();if(!snap.exists)fail('La orden no existe.', 'not-found');
  const signatures=phase==='devolucion'?order.firmasDevolucion:order.firmas;
  const complete=phase==='devolucion'?signatures?.devuelve&&signatures?.recibe:signatures?.entrega&&signatures?.recibe&&order.estado!=='validacion_administrativa';
  if(!complete)fail('Ambas confirmaciones deben estar firmadas y validadas.');
  const version=phase==='devolucion'?(order.estado==='cerrada'?'final':order.devolucion.version):order.salida.version;
  const path=`instalaciones/${id}/documentos/${phase}-v${version}.pdf`;
  const field=phase==='devolucion'?'actaDevolucion':'actaSalida';
  if(order[field]?.path===path)return order[field];
  const photos=[];
  const snapshot=phase==='devolucion'?order.devolucion:order.salida;
  for(const photo of (snapshot.fotos||[]).slice(0,3)){
    if(typeof photo.path!=='string'||!photo.path.startsWith(`instalaciones/${id}/evidencias/`))continue;
    try{
      const file=storage.bucket().file(photo.path),[metadata]=await file.getMetadata();
      if(Number(metadata.size)>3*1024*1024)continue;
      const [bytes]=await file.download();
      if(jpegSize(bytes))photos.push({bytes,nombre:photo.nombre});
    }catch(_){ /* Original references remain listed if an image is unavailable. */ }
  }
  const bytes=createActaPdf(order,phase,photos),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  await immutableFile(storage,path,bytes,'application/pdf',{orderId:id,sha256,snapshotHash:phase==='devolucion'?order.devolucion.hash:order.salida.hash});
  const document={path,sha256,version:String(version),snapshotHash:phase==='devolucion'?order.devolucion.hash:order.salida.hash,creadoEn:Timestamp.now()};
  await db.runTransaction(async tx=>{const current=await tx.get(ref);if(!current.exists)return;const d=current.data();if(phase==='devolucion'&&d.estado==='cerrada'&&version!=='final')return;const expected=phase==='devolucion'?d.devolucion?.hash:d.salida?.hash;if(expected!==document.snapshotHash)return;tx.update(ref,{[field]:document});tx.set(ref.collection('eventos').doc(`pdf_${phase}_${version}`),{accion:'documento_generado',usuarioId:'sistema',fecha:stamp(),path,sha256,snapshotHash:document.snapshotHash});});
  return document;
}

const enterpriseInstallations=onCall({timeoutSeconds:120,memory:'512MiB'},async request=>runInstallationAction({db:getFirestore(),uid:request.auth?.uid,data:request.data||{},storage:getStorage()}));
module.exports={enterpriseInstallations,runInstallationAction,createActaPdf,normalizeLines,returnLines,validateDeparture,completion,signature};
