import 'warehouse_operations_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/solicitud_herramienta_model.dart';

class SolicitudesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> aprobarSolicitud(SolicitudHerramientaModel solicitud, String adminUid) => WarehouseOperationsService().apply(solicitud.id, 'salida');

  // NUEVO: 2. Método para que el Trabajador reporte la devolución
  // Llamarás a este método desde tu UI en lugar de usar FirebaseFirestore.instance directamente
  Future<void> reportarDevolucionTrabajador({
    required String solicitudId,
    required bool tieneFalla,
    required String observaciones,
    required String fotoUrl,
  }) async {
    await _db.collection('solicitudes_herramientas').doc(solicitudId).update({
      'marcadoDevueltoTrabajador': true,
      'tieneReporteFalla': tieneFalla,
      'observacionesDevolucion': observaciones,
      'fotoDevolucionUrl': fotoUrl,
      'fechaMarcadoDevuelto': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmarDevolucionPorAdmin(SolicitudHerramientaModel solicitud) => WarehouseOperationsService().apply(solicitud.id, 'entrada');
}
