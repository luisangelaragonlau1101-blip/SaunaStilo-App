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
  static Stream<AttendanceHistory> watch(String uid, {bool team = false}) {
    late StreamController<AttendanceHistory> controller;
    StreamSubscription? ledgerSub, receiptSub;
    List<AsistenciaModel>? ledger;
    List<AsistenciaModel> recent = [];
    bool cached = false;
    String? notice;
    void emit() {
      if (ledger == null || controller.isClosed) return;
      final merged = {for (final row in ledger!) row.id: row};
      for (final row in recent) { merged[row.id] = row; }
      controller.add(AttendanceHistory(merged.values.toList()..sort((a,b) => b.fecha.compareTo(a.fecha)), cached: cached, notice: notice));
    }
    controller = StreamController<AttendanceHistory>(onListen: () {
      final collection = FirebaseFirestore.instance.collection('asistencias');
      final query = team ? collection : collection.where('trabajadorId', isEqualTo: uid);
      ledgerSub = query.snapshots(includeMetadataChanges: true).listen((snapshot) {
        try { ledger = snapshot.docs.map(AsistenciaModel.fromFirestore).toList(); cached = snapshot.metadata.isFromCache; emit(); }
        catch (e, st) { controller.addError(e, st); }
      }, onError: (Object e, StackTrace st) => controller.addError(e, st));
      if (!team) {
        final today = AttendanceGatewayService.today;
        receiptSub = AttendanceGatewayService().watchHistory(uid, today.subtract(const Duration(days: 6)), today).listen((rows) {
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
