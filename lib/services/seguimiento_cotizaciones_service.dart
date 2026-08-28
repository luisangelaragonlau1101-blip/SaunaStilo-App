import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seguimiento_cotizaciones_model.dart';

class SeguimientoCotizacionesServicio {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Obtener las cotizaciones con estatus PENDIENTE en tiempo real
  Stream<List<SeguimientoCotizacionModel>> escucharCotizacionesPendientes() {
    return _db
        .collection('seguimiento_cotizaciones')
       // .where('estatus_cotizacion', isEqualTo: 'PENDIENTE')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SeguimientoCotizacionModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // 2. Agregar una nueva nota al historial de seguimiento
  Future<void> agregarNotaSeguimiento(String cotizacionId, NotaSeguimiento nuevaNota) async {
    await _db.collection('seguimiento_cotizaciones').doc(cotizacionId).update({
      'notas_seguimiento': FieldValue.arrayUnion([nuevaNota.toJson()])
    });
  }

  // 3. PROCESO CRÍTICO: Aceptar cotización y migrar datos
  Future<void> aceptarYConvertirCotizacion(SeguimientoCotizacionModel cotizacion) async {
    // Usamos un batch para asegurarnos de que si algo falla, no se guarden datos incompletos
    final WriteBatch batch = _db.batch();

    String idClienteFinal = cotizacion.idCliente;

    // PASO A: Si el cliente es nuevo, lo creamos en la colección 'clientes'
    if (cotizacion.clienteEsNuevo) {
      final DocumentReference nuevoClienteRef = _db.collection('clientes').doc();
      idClienteFinal = nuevoClienteRef.id; // Obtenemos el ID generado automáticamente

      batch.set(nuevoClienteRef, {
        'nombre': cotizacion.datosCliente.nombre,
        'telefono': cotizacion.datosCliente.telefono,
        'direccion': cotizacion.datosCliente.direccion,
        'fecha_registro': FieldValue.serverTimestamp(), // Se genera al momento
      });
    }

    // PASO B: Creamos el documento en la colección 'proyectos'
    final DocumentReference nuevoProyectoRef = _db.collection('proyectos').doc();
    
    batch.set(nuevoProyectoRef, {
      'titulo': cotizacion.datosProyecto.titulo,
      'descripcion': cotizacion.datosProyecto.descripcion,
      'id_sauna': cotizacion.datosProyecto.idSauna,
      'medidas': cotizacion.datosProyecto.medidas,
      'id_cliente': idClienteFinal, // Enlazamos el cliente correcto
      'estatus': 'pendiente',       // Inicia como pendiente operativo
      'fecha_inicio': FieldValue.serverTimestamp(),
      'fecha_entrega': null,        // El admin lo asignará después en la IU
      'encargados': [cotizacion.adminEncargado], // Asignamos al admin creador inicialmente
    });

    // PASO C: Creamos la subcolección de finanzas dentro del nuevo proyecto
    final DocumentReference finanzasRef = nuevoProyectoRef
        .collection('finanzas')
        .doc('datos_pago'); // ID fijo tal como lo tienes en tu consola

    batch.set(finanzasRef, {
      'cotizacion': cotizacion.montoCotizado,
      'monto_pagado': cotizacion.montoCotizado, // El total a pagar pactado
      'pago_inicial': 0.0,                      // Se actualizará cuando registren el primer abono
      'fecha_registro': FieldValue.serverTimestamp(),
    });

    // PASO D: Actualizamos el estatus de la cotización para que salga de la "Sala de Espera"
    final DocumentReference cotizacionRef = 
        _db.collection('seguimiento_cotizaciones').doc(cotizacion.id);
        
    batch.update(cotizacionRef, {
      'id_cliente': idClienteFinal, // Dejamos registro de qué cliente le tocó
      'estatus_cotizacion': 'ACEPTADO',
    });

    // Ejecutar todas las operaciones juntas en Firebase
    await batch.commit();
  }

  // En seguimiento_cotizaciones_service.dart
Future<void> crearCotizacion(SeguimientoCotizacionModel cotizacion) async {
  await _db.collection('seguimiento_cotizaciones').add(cotizacion.toJson());
}
}