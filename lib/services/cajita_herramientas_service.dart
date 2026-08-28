import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cajita_herramientas_model.dart';

class CajitaInventarioProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _cargando = false;

  bool get cargando => _cargando;

  void _setCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  // 1. STREAM DE CAJITA (Renombrado para que aplique a maestros y trabajadores)
  Stream<List<CajitaHerramientaModel>> streamCajitaUsuario(String usuarioId) {
    return _db
        .collection('cajitas_inventario')
        // Seguimos consultando la llave de Firestore original para no romper la BD
        .where('trabajador_actual_id', isEqualTo: usuarioId)
        .where('estado', whereIn: ['asignado', 'en_transito']) 
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CajitaHerramientaModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // 2. INICIAR UN TRASPASO
  Future<bool> iniciarTraspaso({
    required String herramientaId,
    required String origenId, 
    required String destinoId, 
    required String nombreHerramienta,
  }) async {
    _setCargando(true);
    try {
      await _db.runTransaction((transaction) async {
        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc();

        // Obtener nombres de los usuarios involucrados
        DocumentSnapshot origenSnap = await transaction.get(_db.collection('usuarios').doc(origenId));
        DocumentSnapshot destinoSnap = await transaction.get(_db.collection('usuarios').doc(destinoId));
        
        String origenNombre = origenSnap.exists ? (origenSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';
        String destinoNombre = destinoSnap.exists ? (destinoSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';

        transaction.update(herramientaRef, {
          'estado': 'en_transito',
        });

        transaction.set(traspasoRef, {
          'herramienta_id': herramientaId,
          'nombre_herramienta': nombreHerramienta,
          'origen_usuario_id': origenId,
          'origen_usuario_nombre': origenNombre, 
          'destino_usuario_id': destinoId,
          'destino_usuario_nombre': destinoNombre, 
          'estado': 'pendiente',
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
      });

      _setCargando(false);
      return true;
    } catch (e) {
      _setCargando(false);
      debugPrint("Error al iniciar traspaso: $e");
      return false;
    }
  }

  // 3. ESCUCHAR TRASPASOS PENDIENTES
  Stream<QuerySnapshot> streamTraspasosPendientes(String usuarioId) {
    return _db
        .collection('traspasos_inventario')
        .where('destino_usuario_id', isEqualTo: usuarioId)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots();
  }

  // 4. ACEPTAR EL TRASPASO
  Future<bool> aceptarTraspaso(String traspasoId, String nuevoUsuarioId) async {
    _setCargando(true);
    try {
      await _db.runTransaction((transaction) async {
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc(traspasoId);
        DocumentSnapshot traspasoSnap = await transaction.get(traspasoRef);
        if (!traspasoSnap.exists) throw Exception("El traspaso no existe");
        
        final dataTraspaso = traspasoSnap.data() as Map<String, dynamic>;
        final String herramientaId = dataTraspaso['herramienta_id'];
        final String origenUsuarioId = dataTraspaso['origen_usuario_id'];
        final String origenUsuarioNombre = dataTraspaso['origen_usuario_nombre'] ?? 'Compañero';

        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);
        DocumentSnapshot herramientaSnap = await transaction.get(herramientaRef);
        if (!herramientaSnap.exists) throw Exception("La herramienta no existe");
        
        final dataHerramienta = herramientaSnap.data() as Map<String, dynamic>;
        
        String? propietarioOriginalId = dataHerramienta['propietario_original_id'];
        String? propietarioOriginalNombre = dataHerramienta['propietario_original_nombre'];
        
        // Si no tenía dueño previo, el que la prestó se convierte en el dueño original
        if (propietarioOriginalId == null) {
          propietarioOriginalId = origenUsuarioId;
          propietarioOriginalNombre = origenUsuarioNombre;
        }

        // Obtener el nombre del usuario que está aceptando
        DocumentSnapshot nuevoUsuSnap = await transaction.get(_db.collection('usuarios').doc(nuevoUsuarioId));
        String nuevoUsuNombre = nuevoUsuSnap.exists ? (nuevoUsuSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';

        transaction.update(herramientaRef, {
          'trabajador_actual_id': nuevoUsuarioId,
          'trabajador_actual_nombre': nuevoUsuNombre,
          'estado': 'asignado',
          'propietario_original_id': propietarioOriginalId,
          'propietario_original_nombre': propietarioOriginalNombre,
        });

        transaction.update(traspasoRef, {
          'estado': 'completado',
          'fecha_aceptacion': FieldValue.serverTimestamp(),
        });
      });

      _setCargando(false);
      return true;
    } catch (e) {
      _setCargando(false);
      debugPrint("Error al aceptar traspaso: $e");
      return false;
    }
  }

  // 5. RECHAZAR O CANCELAR EL TRASPASO
  Future<bool> rechazarTraspaso(String traspasoId) async {
    _setCargando(true);
    try {
      await _db.runTransaction((transaction) async {
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc(traspasoId);
        
        DocumentSnapshot traspasoSnap = await transaction.get(traspasoRef);
        if (!traspasoSnap.exists) throw Exception("El traspaso no existe");
        
        final String herramientaId = traspasoSnap.get('herramienta_id');
        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);

        transaction.update(herramientaRef, {'estado': 'asignado'});
        
        transaction.update(traspasoRef, {
          'estado': 'rechazado',
          'fecha_rechazo': FieldValue.serverTimestamp(),
        });
      });
      _setCargando(false);
      return true;
    } catch (e) {
      _setCargando(false);
      debugPrint("Error al rechazar traspaso: $e");
      return false;
    }
  }

  // 6. DEVOLVER HERRAMIENTA PRESTADA
  Future<bool> devolverHerramienta({
    required String herramientaId, 
    required String propietarioId
  }) async {
    _setCargando(true);
    try {
      DocumentSnapshot propSnap = await _db.collection('usuarios').doc(propietarioId).get();
      String propNombre = propSnap.exists ? (propSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';

      DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);

      await herramientaRef.update({
        'trabajador_actual_id': propietarioId,
        'trabajador_actual_nombre': propNombre,
        'estado': 'asignado',
        'propietario_original_id': FieldValue.delete(), 
        'propietario_original_nombre': FieldValue.delete(), 
      });

      _setCargando(false);
      return true;
    } catch (e) {
      _setCargando(false);
      debugPrint("Error al devolver herramienta: $e");
      return false;
    }
  }
}