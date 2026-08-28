import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/proveedor_model.dart';

class ProveedorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Leer todos los proveedores
  Stream<List<Proveedor>> getProveedores() {
    return _db.collection('proveedores').snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => Proveedor.fromMap(doc.data(), doc.id)).toList()
    );
  }

  // Crear un nuevo proveedor
  Future<void> addProveedor(Proveedor proveedor) {
    return _db.collection('proveedores').add(proveedor.toMap());
  }

  // Actualizar un proveedor existente
  Future<void> updateProveedor(Proveedor proveedor) {
    return _db.collection('proveedores').doc(proveedor.id).update(proveedor.toMap());
  }

  // Eliminar un proveedor
  Future<void> deleteProveedor(String id) {
    return _db.collection('proveedores').doc(id).delete();
  }


// --- MÉTODO PARA COMPLETAR PEDIDO Y SUMAR AL INVENTARIO ---
  Future<void> completarPedidoInsumo(String idCompra, String idInsumo, double cantidad) async {
    WriteBatch batch = _db.batch();

    // 1. Actualizar el pedido a 'completado' y registrar la fecha de llegada
    DocumentReference compraRef = _db.collection('compras_insumos').doc(idCompra);
    batch.update(compraRef, {
      'status_pedido': 'completado',
      'fecha_entrega_final': Timestamp.now(),
    });

    // 2. Sumar la cantidad al inventario existente
    DocumentReference insumoRef = _db.collection('insumos_inventario').doc(idInsumo);
    batch.update(insumoRef, {
      'cantidad_disponible': FieldValue.increment(cantidad),
      'ultima_actualizacion': Timestamp.now(),
    });

    // Ejecutar ambas instrucciones de forma atómica
    await batch.commit();
  }
}