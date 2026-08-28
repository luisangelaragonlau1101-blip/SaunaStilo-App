import 'dart:io'; // <-- NUEVO: Para manejar el archivo físico de la imagen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // <-- NUEVO: Para Storage
import '../models/insumo_model.dart';

class InventarioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // <-- NUEVO

  // ==========================================
  //  --- MÉTODOS NUEVOS PARA STORAGE ---
  // ==========================================

  /// Sube la imagen a Storage y retorna la URL de descarga
  Future<String> subirImagenInsumo(File archivoImagen, String nombreInsumo) async {
    // Creamos un nombre único usando el timestamp y limpiando el nombre del insumo
    String nombreLimpio = nombreInsumo.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    String paraNombreArchivo = '${DateTime.now().millisecondsSinceEpoch}_$nombreLimpio.jpg';
    
    // Referencia de la ruta: insumos_inventario/nombre_archivo.jpg
    Reference ref = _storage.ref().child('insumos_inventario').child(paraNombreArchivo);
    
    // Subir archivo
    UploadTask uploadTask = ref.putFile(archivoImagen);
    TaskSnapshot snapshot = await uploadTask;
    
    // Retornar la URL pública de descarga
    return await snapshot.ref.getDownloadURL();
  }

  /// Elimina una imagen de Storage usando su URL de descarga
  Future<void> eliminarImagenPorUrl(String url) async {
    if (url.isEmpty) return;
    try {
      Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Error al eliminar imagen de Storage: $e');
      // Puedes manejar el error o dejar que continúe si la imagen ya no existía
    }
  }

  // ==========================================
  //  --- C  R  U  D  ---  PRODUCTOS  ---
  // ==========================================
  
  Stream<List<InsumoModel>> getInsumosStream() {
    return _db.collection('insumos_inventario').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => InsumoModel.fromFirestore(doc)).toList());
  }

  Future<void> crearInsumo(InsumoModel insumo) async {
    await _db.collection('insumos_inventario').add(insumo.toFirestore());
  }

  Future<void> editarInsumo(String id, Map<String, dynamic> datos) async {
    datos['ultima_actualizacion'] = Timestamp.now();
    await _db.collection('insumos_inventario').doc(id).update(datos);
  }

  /// MODIFICADO: Ahora recibe opcionalmente la url de la imagen para borrarla de Storage también
  Future<void> eliminarInsumo(String id, {String? imagenUrl}) async {
    // 1. Si tiene imagen en Storage, la borramos primero
    if (imagenUrl != null && imagenUrl.isNotEmpty) {
      await eliminarImagenPorUrl(imagenUrl);
    }
    // 2. Borramos el documento de Firestore
    await _db.collection('insumos_inventario').doc(id).delete();
  }

  // AUXILIARES PARA CATEGORÍAS EN DROPDOWNS 
  Future<List<String>> getCategoriasList() async {
    var snap = await _db.collection('categorias_inventario').get();
    return snap.docs.map((doc) => doc['nombre'].toString()).toList();
  }

  Future<List<String>> getSubcategoriasListFiltradas(String categoriaPadre) async {
    var snap = await _db
        .collection('subcategorias_inventario')
        .where('categoriaNombre', isEqualTo: categoriaPadre.trim().toLowerCase())
        .get();
    return snap.docs.map((doc) => doc['nombre'].toString()).toList();
  }

  Future<void> crearCategoria(String nombre) async {
    await _db.collection('categorias_inventario').add({'nombre': nombre});
  }

  Future<void> crearSubcategoria(String nombre, String categoriaPadre) async {
    await _db.collection('subcategorias_inventario').add({
      'nombre': nombre,
      'categoriaNombre': categoriaPadre.trim().toLowerCase(),
    });
  }

  Future<void> actualizarCategoriaEnCascada(String idCategoria, String nombreAnterior, String nombreNuevo) async {
    WriteBatch batch = _db.batch();
    String viejo = nombreAnterior.trim().toLowerCase();
    String nuevo = nombreNuevo.trim().toLowerCase();

    DocumentReference catRef = _db.collection('categorias_inventario').doc(idCategoria);
    batch.update(catRef, {'nombre': nombreNuevo});

    var subcatSnap = await _db.collection('subcategorias_inventario')
        .where('categoriaNombre', isEqualTo: viejo)
        .get();
    for (var doc in subcatSnap.docs) {
      batch.update(doc.reference, {'categoriaNombre': nuevo});
    }

    var insumosSnap = await _db.collection('insumos_inventario')
        .where('categoria', isEqualTo: viejo)
        .get();
    for (var doc in insumosSnap.docs) {
      batch.update(doc.reference, {'categoria': nuevo});
    }

    await batch.commit();
  }

  Future<void> actualizarSubcategoriaEnCascada(String idSubcategoria, String nombreAnterior, String nombreNuevo) async {
    WriteBatch batch = _db.batch();
    String viejo = nombreAnterior.trim().toLowerCase();
    String nuevo = nombreNuevo.trim().toLowerCase();

    DocumentReference subRef = _db.collection('subcategorias_inventario').doc(idSubcategoria);
    batch.update(subRef, {'nombre': nombreNuevo});

    var insumosSnap = await _db.collection('insumos_inventario') 
        .where('subcategoria', isEqualTo: viejo)
        .get();

    for (var doc in insumosSnap.docs) {
      batch.update(doc.reference, {'subcategoria': nuevo});
    }

    await batch.commit();
  }

  Future<void> completarPedidoInsumo(String idCompra, String idInsumo, double cantidad) async {
    WriteBatch batch = _db.batch();

    DocumentReference compraRef = _db.collection('compras_insumos').doc(idCompra);
    batch.update(compraRef, {
      'status_pedido': 'completado',
      'fecha_entrega_final': Timestamp.now(),
    });

    DocumentReference insumoRef = _db.collection('insumos_inventario').doc(idInsumo);
    batch.update(insumoRef, {
      'cantidad_disponible': FieldValue.increment(cantidad),
      'ultima_actualizacion': Timestamp.now(),
    });

    await batch.commit();
  }

  Future<bool> existeNombreInsumo(String nombre, {String? excluirId}) async {
    String nombreLimpio = nombre.trim().toLowerCase();
    var snap = await _db.collection('insumos_inventario').get();
    
    for (var doc in snap.docs) {
      if (excluirId != null && doc.id == excluirId) continue;
      String nombreDoc = (doc.data()['nombre'] ?? '').toString().trim().toLowerCase();
      if (nombreDoc == nombreLimpio) {
        return true; 
      }
    }
    return false;
  }

// ==========================================
  //  --- MÉTODOS PARA CÓDIGO DE BARRAS ---
  // ==========================================

  /// Busca un insumo específico usando su código de barras
  Future<InsumoModel?> buscarPorCodigoBarras(String codigo) async {
    if (codigo.trim().isEmpty) return null;

    var snap = await _db
        .collection('insumos_inventario')
        .where('codigo_barras', isEqualTo: codigo.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return null; // No se encontró ningún producto con ese código
    }

    return InsumoModel.fromFirestore(snap.docs.first);
  }

  /// Verifica si un código de barras ya está registrado (para evitar duplicados)
  Future<bool> existeCodigoBarras(String codigo, {String? excluirId}) async {
    if (codigo.trim().isEmpty) return false;

    var snap = await _db
        .collection('insumos_inventario')
        .where('codigo_barras', isEqualTo: codigo.trim())
        .get();

    for (var doc in snap.docs) {
      if (excluirId != null && doc.id == excluirId) continue;
      return true; // Existe otro documento con este mismo código
    }
    
    return false; // El código está libre
  }


  Future<void> recepcionMasivaInsumos(Map<String, int> insumosRecibidos) async {
    WriteBatch batch = _db.batch();

    insumosRecibidos.forEach((idInsumo, cantidadAAgregar) {
      DocumentReference ref = _db.collection('insumos_inventario').doc(idInsumo);
      batch.update(ref, {
        'cantidad_disponible': FieldValue.increment(cantidadAAgregar), 
        'ultima_actualizacion': FieldValue.serverTimestamp(), 
      });
    });

    DocumentReference historialRef = _db.collection('historial_recepciones').doc();
    batch.set(historialRef, {
      'fecha_recepcion': FieldValue.serverTimestamp(),
      'articulos_recibidos': insumosRecibidos, 
    });

    await batch.commit(); 
  }
}