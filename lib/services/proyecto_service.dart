import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/proyecto_model.dart';

class ProyectoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Crear proyecto con subcolección de finanzas completa
  Future<void> crearProyecto(Proyecto proyecto, double cotizacion, double pagoInicial) async {
    final batch = _db.batch();
    
    DocumentReference proyectoRef = _db.collection('proyectos').doc(); 

    batch.set(proyectoRef, proyecto.toMap());

    // Al crear, el 'monto_pagado' arranca siendo igual al pago inicial
    batch.set(proyectoRef.collection('finanzas').doc('datos_pago'), {
      'cotizacion': cotizacion,
      'pago_inicial': pagoInicial,
      'monto_pagado': pagoInicial,
      'fecha_registro': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 2. Obtener lista de proyectos
  Stream<List<Proyecto>> getProyectos({bool soloAsignados = false}) {
    Query<Map<String, dynamic>> query = _db.collection('proyectos');
    if (soloAsignados) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return const Stream.empty();
      query = query.where('encargados', arrayContains: uid);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Proyecto.fromFirestore(doc)).toList());
  }

  // 3. Obtener finanzas (Stream en tiempo real)
  Stream<DocumentSnapshot> getFinanzasStream(String proyectoId) {
    return _db
        .collection('proyectos')
        .doc(proyectoId)
        .collection('finanzas')
        .doc('datos_pago')
        .snapshots();
  }

  // 4. Actualizar toda la estructura financiera (Evita errores de documento no encontrado)
  Future<void> actualizarFinanzas(String proyectoId, double cotizacion, double pagoInicial, double montoPagado) async {
    await _db
        .collection('proyectos')
        .doc(proyectoId)
        .collection('finanzas')
        .doc('datos_pago')
        .set(
          {
            'cotizacion': cotizacion,
            'pago_inicial': pagoInicial,
            'monto_pagado': montoPagado,
          },
          SetOptions(merge: true),
        );
  }

  // Eliminar Proyecto 
  Future<void> eliminarProyecto(String proyectoId) async {
    var finanzasRef = _db.collection('proyectos').doc(proyectoId).collection('finanzas').doc('datos_pago');
    await finanzasRef.delete();
    await _db.collection('proyectos').doc(proyectoId).delete();
  }

  // Modificar Proyecto
  Future<void> actualizarProyecto(Proyecto proyecto) async {
    await _db.collection('proyectos').doc(proyecto.id).update(proyecto.toMap());
  }


  // --- MÓDULO DE REPORTES PDF Y CSV ---
  
  // Generar lista de proyectos finalizados para reportes mensuales/anuales
  Future<List<Map<String, dynamic>>> obtenerReporteProyectos(int anio, int mes) async {
    // 1. Definir los límites de tiempo
    DateTime inicioMes = DateTime(anio, mes, 1, 0, 0, 0);
    
    // El día '0' del mes siguiente nos da automáticamente el último día del mes actual
    DateTime finMes = mes == 12 
        ? DateTime(anio + 1, 1, 0, 23, 59, 59) 
        : DateTime(anio, mes + 1, 0, 23, 59, 59);

    // 2. Consultar proyectos finalizados dentro del rango
    final snap = await _db
        .collection('proyectos')
        .where('estatus', isEqualTo: 'finalizado')
        .where('fecha_entrega', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
        .where('fecha_entrega', isLessThanOrEqualTo: Timestamp.fromDate(finMes))
        .get();

    List<Map<String, dynamic>> dataReporte = [];

    // 3. Extraer el monto de la subcolección finanzas por cada proyecto
    for (var doc in snap.docs) {
      final proyecto = Proyecto.fromFirestore(doc);
      
      final finanzasDoc = await doc.reference.collection('finanzas').doc('datos_pago').get();
      double montoRecaudado = 0.0;
      
      if (finanzasDoc.exists) {
        montoRecaudado = (finanzasDoc.data()?['monto_pagado'] ?? 0.0).toDouble();
      }

      dataReporte.add({
        'proyecto': proyecto,
        'monto': montoRecaudado,
      });
    }

    // 4. Ordenar cronológicamente (más recientes primero)
    dataReporte.sort((a, b) => (b['proyecto'] as Proyecto).fechaEntrega.compareTo((a['proyecto'] as Proyecto).fechaEntrega));

    return dataReporte;
  }
}
