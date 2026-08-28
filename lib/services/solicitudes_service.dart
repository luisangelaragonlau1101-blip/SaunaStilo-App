import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/solicitud_herramienta_model.dart';

class SolicitudesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Método para que el Admin apruebe y descuente del inventario
  Future<void> aprobarSolicitud(SolicitudHerramientaModel solicitud, String adminUid) async {
    DateTime ahora = DateTime.now();
    Map<String, dynamic> updateData = {
      'estatus': 'aprobada',
      'fechaAprobacion': Timestamp.fromDate(ahora),
      'autorizadoPorAdminId': adminUid,
    };
    
    if (solicitud.esRetornable) {
      updateData['fechaLimiteDevolucion'] = Timestamp.fromDate(ahora.add(const Duration(days: 1)));
    }

    return _db.runTransaction((transaction) async {
      DocumentReference solRef = _db.collection('solicitudes_herramientas').doc(solicitud.id);
      
   
      DocumentReference insumoRef = _db.collection('insumos_inventario').doc(solicitud.insumoId);

      transaction.update(solRef, updateData);

      transaction.update(insumoRef, {
        'cantidad_disponible': FieldValue.increment(-solicitud.cantidad),
        'ultima_actualizacion': Timestamp.fromDate(ahora)
      });
    });
  }

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

  // 3. Método modificado para que el Admin confirme la entrega
  Future<void> confirmarDevolucionPorAdmin(SolicitudHerramientaModel solicitud) async {
    return _db.runTransaction((transaction) async {
      DocumentReference solRef = _db.collection('solicitudes_herramientas').doc(solicitud.id);
      DocumentReference insumoRef = _db.collection('insumos_inventario').doc(solicitud.insumoId);

      // Marcar como completamente devuelto
      transaction.update(solRef, {
        'devueltoConfirmadoAdmin': true
      });

      // LÓGICA CRUCIAL: Solo devolvemos al stock disponible si NO hay fallas
      if (!solicitud.tieneReporteFalla) {
        transaction.update(insumoRef, {
          'cantidad_disponible': FieldValue.increment(solicitud.cantidad),
          'ultima_actualizacion': Timestamp.fromDate(DateTime.now())
        });
      } else {
     
      }
    });
  }
}