import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asistencia_model.dart';
import 'attendance_gateway_service.dart';

class AttendanceHistory {
  final List<AsistenciaModel> rows;
  final bool cached;
  final String? notice;
  const AttendanceHistory(this.rows, {this.cached = false, this.notice});
}

/// A single history for streaks and payroll details. Includes recent receipts
/// while retaining the complete ledger, bonuses and administrative corrections.
class AttendanceHistoryService {
  static Map<String,dynamic> mergeReceipt(Map<String,dynamic>? ledger, Map<String,dynamic> receipt) {
    if (ledger == null) return receipt;
    final merged = {...ledger};
    final integrated = ledger['movimientosServidor'] as Map? ?? {};
    final incoming = receipt['movimientosServidor'] as Map? ?? {};
    for (final field in ['horaEntrada','salidaComidaSolicitada','salidaComidaReal','regresoComidaReal','horaSalida']) {
      if (integrated[field] != null || incoming[field] == null || ledger[field] != null || receipt[field] == null) continue;
      merged[field] = receipt[field];
      if (field == 'horaEntrada') merged['estatus'] = ledger['estatusJustificacion'] == 'aprobada' ? 'justificado' : receipt['estatus'];
      if (field == 'salidaComidaReal' || field == 'regresoComidaReal') merged['estatusComida'] = receipt['estatusComida'];
    }
    final knownPauses = <String, Map<String,dynamic>>{
      for (final p in ledger['pausasJornada'] as List? ?? []) (p as Map)['id'] as String: Map<String,dynamic>.from(p),
    };
    for (final p in receipt['pausasJornada'] as List? ?? []) {
      final incomingPause = Map<String,dynamic>.from(p as Map);
      final id = incomingPause['id'] as String;
      final old = knownPauses[id];
      if (old == null) { knownPauses[id] = incomingPause; }
      else if (old['regresoId'] == null && old['regreso'] == null && incomingPause['regresoId'] != null) {
        knownPauses[id] = {...old, 'regreso': incomingPause['regreso'], 'regresoId': incomingPause['regresoId']};
      }
    }
    if (knownPauses.isNotEmpty) merged['pausasJornada'] = knownPauses.values.toList();
    return merged;
  }

  static Stream<AttendanceHistory> watch(String uid, {bool team = false}) {
    late StreamController<AttendanceHistory> controller;
    StreamSubscription? ledgerSub, receiptSub;
    Map<String, Map<String,dynamic>>? ledger;
    List<Map<String,dynamic>> recent = [];
    bool cached = false;
    String? notice;
    void emit() {
      if (ledger == null || controller.isClosed) return;
      final merged = {for (final row in ledger!.entries) row.key: AsistenciaModel.fromData(row.key, row.value)};
      for (final receipt in recent) {
        final id = receipt['asistenciaId'] as String;
        final data = Map<String,dynamic>.from(receipt['data'] as Map);
        if (data.isNotEmpty) merged[id] = AsistenciaModel.fromData(id, mergeReceipt(ledger![id], data));
      }
      controller.add(AttendanceHistory(merged.values.toList()..sort((a,b) => b.fecha.compareTo(a.fecha)), cached: cached, notice: notice));
    }
    controller = StreamController<AttendanceHistory>(onListen: () {
      final collection = FirebaseFirestore.instance.collection('asistencias');
      final query = team ? collection : collection.where('trabajadorId', isEqualTo: uid);
      ledgerSub = query.snapshots(includeMetadataChanges: true).listen((snapshot) {
        try { ledger = {for(final doc in snapshot.docs) doc.id: doc.data()}; cached = snapshot.metadata.isFromCache; emit(); }
        catch (e, st) { controller.addError(e, st); }
      }, onError: (Object e, StackTrace st) => controller.addError(e, st));
      if (!team) {
        receiptSub = AttendanceGatewayService().watchRecentReceipts(uid).listen((rows) {
          recent = rows; notice = null; emit();
        }, onError: (Object error) {
          notice = 'Se muestran los registros integrados. No se pudieron actualizar los movimientos recientes.';
          emit();
        });
      }
    }, onCancel: () async { await ledgerSub?.cancel(); await receiptSub?.cancel(); });
    return controller.stream;
  }
}
