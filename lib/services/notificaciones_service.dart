import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notificacion_model.dart';
class NotificacionesService {
 final FirebaseFirestore _db; NotificacionesService({FirebaseFirestore? firestore}):_db=firestore??FirebaseFirestore.instance;
 CollectionReference<Map<String,dynamic>> get _ref=>_db.collection('notificaciones');
 Stream<List<NotificacionApp>> avisosPara({required String usuarioId,required String rol})=>_ref.snapshots().map((s){final a=s.docs.map(NotificacionApp.fromDocument).where((n)=>n.visiblePara(usuarioId:usuarioId,rol:rol)).toList();a.sort((x,y)=>y.fecha.compareTo(x.fecha));return a;});
 Stream<int> noLeidosPara({required String usuarioId,required String rol})=>avisosPara(usuarioId:usuarioId,rol:rol).map((a)=>a.where((n)=>!n.leidaPor(usuarioId)).length);
 Future<void> marcarLeida(String avisoId,String usuarioId)=>_ref.doc(avisoId).update({'leidosPor':FieldValue.arrayUnion([usuarioId])});
 Future<void> marcarTodasLeidas({required String usuarioId,required String rol}) async {final s=await _ref.get();final p=s.docs.map(NotificacionApp.fromDocument).where((a)=>a.visiblePara(usuarioId:usuarioId,rol:rol)&&!a.leidaPor(usuarioId)).toList();for(var i=0;i<p.length;i+=400){final b=_db.batch();for(final a in p.sublist(i,(i+400<p.length)?i+400:p.length)){b.update(_ref.doc(a.id),{'leidosPor':FieldValue.arrayUnion([usuarioId])});}await b.commit();}}
 Future<String> llamarATodoElEquipo({String mensaje='Administración solicita la atención inmediata de todo el equipo.'}) async {final uid=FirebaseAuth.instance.currentUser?.uid??'';if(uid.isEmpty)throw StateError('Debes iniciar sesión como administrador.');final t=mensaje.trim();if(t.isEmpty)throw ArgumentError('Escribe el motivo de la alerta.');final r=await _ref.add({'titulo':'🚨 LLAMADA GENERAL · SAUNA STILO','mensaje':t.length>420?t.substring(0,420):t,'tipo':'alarma_admin','destinatarioId':'todos','rolesDestinatarios':<String>['todos'],'leidosPor':<String>[],'creadoPor':uid,'fecha':FieldValue.serverTimestamp(),'prioridad':'critica','requiereAtencion':true,'esLlamada':true,'ruta':'mensajes'});return r.id;}
 static Map<String,dynamic> datosAviso({required String titulo,required String mensaje,required String tipo,String destinatarioId='',List<String> rolesDestinatarios=const<String>[]})=>{'titulo':titulo.trim(),'mensaje':mensaje.trim(),'tipo':tipo,'destinatarioId':destinatarioId,'rolesDestinatarios':rolesDestinatarios,'leidosPor':<String>[],'creadoPor':FirebaseAuth.instance.currentUser?.uid??'','fecha':FieldValue.serverTimestamp()};
}
