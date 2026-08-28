import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart'; 
import '../models/compra_model.dart';
import '../models/proyecto_model.dart'; // Agregamos este import para poder leer los proyectos

// --- MODELO UNIFICADO PARA LA UI ---
// Este modelo vive aquí porque nos sirve para mandar la info ya procesada a tu pantalla
class VentaGeneralItem {
  final String idDocumento;
  final String tipo; // 'compra' o 'proyecto'
  final String titulo;
  final DateTime fecha;
  final double montoTotal;
  final dynamic dataOriginal; // Guarda el Proyecto o CompraModel completo

  VentaGeneralItem({
    required this.idDocumento,
    required this.tipo,
    required this.titulo,
    required this.fecha,
    required this.montoTotal,
    required this.dataOriginal,
  });
}

class VentasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MÓDULO DE CLIENTES ---

  // Crear Cliente
  Future<void> crearCliente(ClienteModel cliente) async {
    await _db.collection('clientes').add(cliente.toMap());
  }

  // Obtener Stream de clientes (para actualizaciones en tiempo real)
  Stream<List<ClienteModel>> obtenerClientes() {
    return _db.collection('clientes').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => ClienteModel.fromJson(doc.id, doc.data()))
        .toList());
  }

  // Actualizar un cliente existente
  Future<void> actualizarCliente(String id, Map<String, dynamic> datosActualizados) async {
    await _db.collection('clientes').doc(id).update(datosActualizados);
  }

  // Eliminar un cliente
  Future<void> eliminarCliente(String id) async {
    await _db.collection('clientes').doc(id).delete();
  }

  // --- MÓDULO DE COMPRAS ---

  // Registrar una Compra y descontar automáticamente del inventario
  Future<void> registrarCompra(CompraModel compra) async {
    final batch = _db.batch();

    // 1. Crear la referencia para el nuevo documento de la compra
    final nuevaCompraRef = _db.collection('compras').doc();
    batch.set(nuevaCompraRef, compra.toMap());

    // 2. Iterar los productos agregados para descontar su stock en el inventario
    for (var prod in compra.productosExtra) {
      final String? idProducto = prod['id_producto'];
      final int cantidad = prod['cantidad'] ?? 0;

      if (idProducto != null && idProducto.isNotEmpty) {
        final productoRef = _db.collection('insumos_inventario').doc(idProducto);
        
        // Restamos la cantidad utilizando FieldValue.increment con valor negativo
        batch.update(productoRef, {
          'cantidad_disponible': FieldValue.increment(-cantidad),
        });
      }
    }

    // 3. Ejecutar todas las operaciones en una sola petición atómica
    await batch.commit();
  }

  // Obtener el historial de compras de UN cliente específico usando su ID
  Stream<List<CompraModel>> obtenerComprasPorCliente(String idCliente) {
    print("DEBUG: Buscando compras con ID: '$idCliente'");
    
    return _db
        .collection('compras')
        .where('id_cliente', isEqualTo: idCliente)
        .snapshots()
        .map((snapshot) {
          print("DEBUG: Se encontraron ${snapshot.docs.length} documentos.");
          return snapshot.docs.map((doc) => CompraModel.fromJson(doc.id, doc.data())).toList();
        });
  }

  // --- MÓDULO DE VENTAS GENERALES (HISTORIAL UNIFICADO) ---

  // Obtener todo el historial unificado (Compras Extra + Proyectos Finalizados)
  Future<List<VentaGeneralItem>> obtenerTodasLasVentas() async {
    List<VentaGeneralItem> historialVentas = [];

    // 1. Obtener todas las Compras (Productos Extra)
    final comprasSnap = await _db.collection('compras').get();
    for (var doc in comprasSnap.docs) {
      final compraData = CompraModel.fromJson(doc.id, doc.data());
      
      // Armar un título descriptivo basado en los productos
      String descripcion = 'Compra Extra';
      if (compraData.productosExtra.isNotEmpty) {
        descripcion = compraData.productosExtra.map((p) => p['nombre_producto']).join(', ');
      }

      historialVentas.add(
        VentaGeneralItem(
          idDocumento: doc.id,
          tipo: 'compra',
          titulo: descripcion,
          fecha: compraData.fechaCompra,
          montoTotal: compraData.montoTotal,
          dataOriginal: compraData,
        )
      );
    }

    // 2. Obtener todos los Proyectos Finalizados
    final proySnap = await _db.collection('proyectos')
        .where('estatus', isEqualTo: 'finalizado')
        .get();

    for (var doc in proySnap.docs) {
      final proyectoData = Proyecto.fromFirestore(doc);
      
      // Consultamos la subcolección finanzas
      var finanzas = await doc.reference.collection('finanzas').doc('datos_pago').get();
      double montoPagado = finanzas.exists ? (finanzas.data()?['monto_pagado'] ?? 0.0).toDouble() : 0.0;
      
      historialVentas.add(
        VentaGeneralItem(
          idDocumento: doc.id,
          tipo: 'proyecto',
          titulo: 'Proyecto: ${proyectoData.titulo}',
          fecha: proyectoData.fechaEntrega,
          montoTotal: montoPagado,
          dataOriginal: proyectoData,
        )
      );
    }

    // 3. Ordenar todo por fecha descendente (lo más nuevo arriba)
    historialVentas.sort((a, b) => b.fecha.compareTo(a.fecha));
    
    return historialVentas;
  }
}