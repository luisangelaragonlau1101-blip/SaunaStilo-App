import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

int? moneyInCents(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final cents = int.parse(parts[0]) * 100 + (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return cents > 0 ? cents : null;
}

class AdminWorkspaceService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  AdminWorkspaceService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth}) : db = firestore ?? FirebaseFirestore.instance, auth = firebaseAuth ?? FirebaseAuth.instance;
  Future<void> savePersonnel(String personId, Map<String, dynamic> fields) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión.');
    const allowed = {'puesto','area','contrato','ingreso','notas','induccion','equipoEntregado','documentosRevisados'};
    if (!fields.keys.every(allowed.contains) || fields.values.whereType<String>().any((v) => v.length > 2000)) throw ArgumentError('Revisa los datos del expediente.');
    await db.runTransaction((tx) async {
      final actor = await tx.get(db.collection('usuarios').doc(uid));
      final target = await tx.get(db.collection('usuarios').doc(personId));
      if (actor.data()?['rol'] != 'admin' || actor.data()?['activo'] == false || !target.exists) throw StateError('Solo Administración puede guardar un expediente existente.');
      tx.set(db.collection('rh_expedientes').doc(personId), {...fields, 'actualizadoPor': uid, 'actualizadoEn': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }
  Future<void> addMovement({required String id, required String kind, required String concept, required int cents, required String category, required DateTime date, required String reference}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || !['ingreso','egreso'].contains(kind) || cents <= 0 || cents > 99999999999 || concept.trim().length < 3 || concept.length > 160 || reference.length > 200) throw ArgumentError('Revisa el concepto, importe y referencia.');
    final ref = db.collection('gestion_movimientos').doc(id);
    await db.runTransaction((tx) async {
      final actor = await tx.get(db.collection('usuarios').doc(uid));
      final existing = await tx.get(ref);
      if (actor.data()?['rol'] != 'admin' || actor.data()?['activo'] == false) throw StateError('Solo Administración puede registrar movimientos.');
      if (existing.exists) {
        final old = existing.data()!;
        if (old['tipo'] != kind || old['concepto'] != concept.trim() || old['centavos'] != cents || old['categoria'] != category || old['referencia'] != reference.trim() || old['fecha'] != Timestamp.fromDate(date)) throw StateError('Este movimiento ya se guardó con otros datos. Cierra el formulario y revisa el registro.');
        return;
      }
      tx.set(ref, {'tipo': kind, 'concepto': concept.trim(), 'centavos': cents, 'moneda': 'MXN', 'categoria': category, 'fecha': Timestamp.fromDate(date), 'referencia': reference.trim(), 'creadoPor': uid, 'creadoEn': FieldValue.serverTimestamp()});
    });
  }
}
