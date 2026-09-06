import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notificaciones_service.dart';

/// Three immutable, deterministic events per request prevent duplicate stock moves.
class WarehouseOperationsService {
  final FirebaseFirestore db;
  WarehouseOperationsService({FirebaseFirestore? firestore}):db=firestore??FirebaseFirestore.instance;
  Future<void> apply(String id,String action,{String note=''}) async {
    if(!['salida','rechazo','entrada'].contains(action))throw ArgumentError('Acción inválida');
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null)throw StateError('Inicia sesión.');
    final req=db.collection('solicitudes_herramientas').doc(id);
    String recipient='',name='';
    await db.runTransaction((tx)async{
      final profile=await tx.get(db.collection('usuarios').doc(uid));
      if(!['admin','almacenista'].contains(profile.data()?['rol']))throw StateError('Solo Administración o Almacén puede confirmar este movimiento.');
      final snap=await tx.get(req);if(!snap.exists)throw StateError('La solicitud ya no existe.');
      final d=snap.data()!;recipient=d['trabajadorId']?.toString()??'';name=d['nombreInsumo']?.toString()??'Herramienta';
      if(action=='entrada'&&d['devueltoConfirmadoAdmin']==true)return;
      if(action=='salida'&&d['estatus']=='aprobada')return;
      if(action=='rechazo'&&d['estatus']=='rechazada')return;
      if(action=='entrada'&&(d['estatus']!='aprobada'||d['esRetornable']!=true))throw StateError('No hay un préstamo retornable aprobado para recibir.');
      if(action!='entrada'&&d['estatus']!='pendiente')throw StateError('La solicitud ya fue procesada. Actualiza la lista.');
      final raw=d['cantidad'];
      final qty=raw is num?raw.toInt():int.tryParse(raw?.toString()??'');
      if(qty==null||qty<=0||(raw is num&&raw!=qty))throw StateError('Cantidad inválida. Revisa la solicitud.');
      Map<String,dynamic>? stock;
      DocumentReference<Map<String,dynamic>>? item;
      if(action!='rechazo'){
        final key=d['insumoId']?.toString()??'';if(key.isEmpty)throw StateError('La solicitud no tiene un insumo asociado.');
        item=db.collection('insumos_inventario').doc(key);
        final s=await tx.get(item);if(!s.exists)throw StateError('El insumo ya no existe. No se modificó el stock.');stock=s.data()!;
      }
      final available=_number(stock?['cantidad_disponible']);
      if(action=='salida'&&available<qty)throw StateError('No hay stock suficiente. No se autorizó la salida ni se descontaron existencias.');
      final changes=<String,dynamic>{};
      if(action=='salida'){
        changes.addAll({'estatus':'aprobada','fechaAprobacion':FieldValue.serverTimestamp(),'autorizadoPorAdminId':uid,'notaAdmin':note});
        if(d['esRetornable']==true)changes['fechaLimiteDevolucion']=Timestamp.fromDate(DateTime.now().add(const Duration(days:1)));
        tx.update(item!,{'cantidad_disponible':available-qty});
      }else if(action=='rechazo'){
        changes.addAll({'estatus':'rechazada','rechazadoPor':uid,'fechaRechazo':FieldValue.serverTimestamp(),'notaAdmin':note});
      }else{
        final damaged=d['tieneReporteFalla']==true;
        tx.update(item!,damaged?{'en_reparacion':_number(stock?['en_reparacion'])+qty}:{'cantidad_disponible':available+qty});
        changes.addAll({'devueltoConfirmadoAdmin':true,'recibidoPor':uid,'fechaRecepcion':FieldValue.serverTimestamp()});
      }
      tx.update(req,changes);
      tx.set(req.collection('historial').doc(action),{'accion':action,'solicitudId':id,'insumoId':d['insumoId']??'','cantidad':qty,
        'responsableId':uid,'responsableNombre':profile.data()?['nombre']??'Almacén','trabajadorId':recipient,
        'fecha':FieldValue.serverTimestamp(),'observacion':note,'conFalla':action=='entrada'&&d['tieneReporteFalla']==true});
    });
    if(recipient.isNotEmpty){try{await db.collection('notificaciones').doc('almacen_${id}_$action').set(NotificacionesService.datosAviso(
      titulo:action=='entrada'?'Recepción confirmada':action=='salida'?'Salida autorizada':'Solicitud rechazada',mensaje:name,tipo:'almacen',destinatarioId:recipient)).timeout(const Duration(seconds:8));}catch(_){/* Stock and history already committed. */}}
  }
  static int _number(dynamic n)=>n is num?n.toInt():int.tryParse(n?.toString()??'')??0;
}
