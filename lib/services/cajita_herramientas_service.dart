import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid != origenId || destinoId == origenId) {
        throw StateError('El usuario no puede iniciar este traspaso');
      }

      await _db.runTransaction((transaction) async {
        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc();
        DocumentReference avisoRef = _db.collection('notificaciones').doc();

        final herramientaSnap = await transaction.get(herramientaRef);
        if (!herramientaSnap.exists) throw StateError('La herramienta no existe');
        final herramientaData = herramientaSnap.data() as Map<String, dynamic>;
        if (herramientaData['trabajador_actual_id'] != currentUid ||
            herramientaData['estado'] != 'asignado') {
          throw StateError('La herramienta ya no está disponible para prestar');
        }

        final propietarioOriginalId =
            herramientaData['propietario_original_id'] as String?;
        final esDevolucion = propietarioOriginalId != null &&
            propietarioOriginalId.isNotEmpty;
        if (esDevolucion && destinoId != propietarioOriginalId) {
          throw StateError('Una herramienta prestada solo puede volver a su dueño');
        }

        // Obtener nombres de los usuarios involucrados
        DocumentSnapshot origenSnap = await transaction.get(_db.collection('usuarios').doc(origenId));
        DocumentSnapshot destinoSnap = await transaction.get(_db.collection('usuarios').doc(destinoId));
        
        String origenNombre = origenSnap.exists ? (origenSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';
        String destinoNombre = destinoSnap.exists ? (destinoSnap.data() as Map<String, dynamic>)['nombre'] ?? 'Compañero' : 'Compañero';

        transaction.update(herramientaRef, {
          'estado': 'en_transito',
          'traspaso_pendiente_id': traspasoRef.id,
          'traspaso_destino_id': destinoId,
        });

        transaction.set(traspasoRef, {
          'herramienta_id': herramientaId,
          'nombre_herramienta': nombreHerramienta,
          'origen_usuario_id': origenId,
          'origen_usuario_nombre': origenNombre, 
          'destino_usuario_id': destinoId,
          'destino_usuario_nombre': destinoNombre, 
          'participantes': [origenId, destinoId],
          'tipo': esDevolucion ? 'devolucion' : 'prestamo',
          'estado': 'pendiente',
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
        transaction.set(avisoRef, {
          'titulo': esDevolucion
              ? 'Devolución por confirmar'
              : 'Herramienta por confirmar',
          'mensaje': esDevolucion
              ? '$origenNombre te está devolviendo $nombreHerramienta.'
              : '$origenNombre quiere prestarte $nombreHerramienta.',
          'tipo': 'traspaso_herramienta',
          'destinatarioId': destinoId,
          'rolesDestinatarios': <String>[],
          'leidosPor': <String>[],
          'creadoPor': currentUid,
          'fecha': FieldValue.serverTimestamp(),
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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid != nuevoUsuarioId) {
        throw StateError('Solo el destinatario puede aceptar el traspaso');
      }

      await _db.runTransaction((transaction) async {
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc(traspasoId);
        DocumentReference avisoRef = _db.collection('notificaciones').doc();
        DocumentSnapshot traspasoSnap = await transaction.get(traspasoRef);
        if (!traspasoSnap.exists) throw Exception("El traspaso no existe");
        
        final dataTraspaso = traspasoSnap.data() as Map<String, dynamic>;
        final String herramientaId = dataTraspaso['herramienta_id'];
        final String origenUsuarioId = dataTraspaso['origen_usuario_id'];
        final String origenUsuarioNombre = dataTraspaso['origen_usuario_nombre'] ?? 'Compañero';
        if (dataTraspaso['destino_usuario_id'] != currentUid ||
            dataTraspaso['estado'] != 'pendiente') {
          throw StateError('Este traspaso no está disponible para el usuario');
        }

        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);
        DocumentSnapshot herramientaSnap = await transaction.get(herramientaRef);
        if (!herramientaSnap.exists) throw Exception("La herramienta no existe");
        
        final dataHerramienta = herramientaSnap.data() as Map<String, dynamic>;
        final pendienteId = dataHerramienta['traspaso_pendiente_id'];
        final destinoPendienteId = dataHerramienta['traspaso_destino_id'];
        if (dataHerramienta['estado'] != 'en_transito' ||
            (pendienteId != null && pendienteId != traspasoId) ||
            (destinoPendienteId != null && destinoPendienteId != currentUid)) {
          throw StateError('El traspaso ya cambió o fue cancelado');
        }
        
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

        final devuelveAlPropietario = propietarioOriginalId != null &&
            propietarioOriginalId == currentUid;
        final cambiosHerramienta = <String, dynamic>{
          'trabajador_actual_id': nuevoUsuarioId,
          'trabajador_actual_nombre': nuevoUsuNombre,
          'estado': 'asignado',
          'ultimo_traspaso_id': traspasoId,
          'traspaso_pendiente_id': FieldValue.delete(),
          'traspaso_destino_id': FieldValue.delete(),
        };
        if (devuelveAlPropietario) {
          cambiosHerramienta['propietario_original_id'] = FieldValue.delete();
          cambiosHerramienta['propietario_original_nombre'] = FieldValue.delete();
        } else {
          cambiosHerramienta['propietario_original_id'] = propietarioOriginalId;
          cambiosHerramienta['propietario_original_nombre'] = propietarioOriginalNombre;
        }
        transaction.update(herramientaRef, cambiosHerramienta);

        transaction.update(traspasoRef, {
          'estado': 'completado',
          'fecha_aceptacion': FieldValue.serverTimestamp(),
          'confirmado_por': currentUid,
          'participantes': [origenUsuarioId, currentUid],
          'tipo': devuelveAlPropietario ? 'devolucion' : 'prestamo',
        });
        transaction.set(avisoRef, {
          'titulo': devuelveAlPropietario
              ? 'Herramienta devuelta'
              : 'Préstamo aceptado',
          'mensaje': '$nuevoUsuNombre confirmó la recepción de la herramienta.',
          'tipo': 'traspaso_herramienta',
          'destinatarioId': origenUsuarioId,
          'rolesDestinatarios': <String>[],
          'leidosPor': <String>[],
          'creadoPor': currentUid,
          'fecha': FieldValue.serverTimestamp(),
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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) throw StateError('Debes iniciar sesión');

      await _db.runTransaction((transaction) async {
        DocumentReference traspasoRef = _db.collection('traspasos_inventario').doc(traspasoId);
        DocumentReference avisoRef = _db.collection('notificaciones').doc();
        
        DocumentSnapshot traspasoSnap = await transaction.get(traspasoRef);
        if (!traspasoSnap.exists) throw Exception("El traspaso no existe");
        
        final traspasoData = traspasoSnap.data() as Map<String, dynamic>;
        if (traspasoData['destino_usuario_id'] != currentUid ||
            traspasoData['estado'] != 'pendiente') {
          throw StateError('Solo el destinatario puede rechazar el traspaso');
        }

        final String herramientaId = traspasoData['herramienta_id'];
        DocumentReference herramientaRef = _db.collection('cajitas_inventario').doc(herramientaId);

        final herramientaSnap = await transaction.get(herramientaRef);
        if (!herramientaSnap.exists) throw StateError('La herramienta no existe');
        final herramientaData = herramientaSnap.data() as Map<String, dynamic>;
        final pendienteId = herramientaData['traspaso_pendiente_id'];
        final destinoPendienteId = herramientaData['traspaso_destino_id'];
        if (herramientaData['estado'] != 'en_transito' ||
            (pendienteId != null && pendienteId != traspasoId) ||
            (destinoPendienteId != null && destinoPendienteId != currentUid)) {
          throw StateError('El traspaso ya cambió o fue cancelado');
        }

        transaction.update(herramientaRef, {
          'estado': 'asignado',
          'ultimo_traspaso_id': traspasoId,
          'traspaso_pendiente_id': FieldValue.delete(),
          'traspaso_destino_id': FieldValue.delete(),
        });
        
        transaction.update(traspasoRef, {
          'estado': 'rechazado',
          'fecha_rechazo': FieldValue.serverTimestamp(),
          'confirmado_por': currentUid,
          'participantes': [
            traspasoData['origen_usuario_id'],
            currentUid,
          ],
          'tipo': (herramientaData['propietario_original_id'] as String?)
                      ?.isNotEmpty ==
                  true
              ? 'devolucion'
              : 'prestamo',
        });
        transaction.set(avisoRef, {
          'titulo': 'Traspaso rechazado',
          'mensaje': '${traspasoData['destino_usuario_nombre'] ?? 'El destinatario'} rechazó ${traspasoData['nombre_herramienta'] ?? 'la herramienta'}.',
          'tipo': 'traspaso_herramienta',
          'destinatarioId': traspasoData['origen_usuario_id'],
          'rolesDestinatarios': <String>[],
          'leidosPor': <String>[],
          'creadoPor': currentUid,
          'fecha': FieldValue.serverTimestamp(),
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
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) throw StateError('Debes iniciar sesión');
      final herramientaSnap =
          await _db.collection('cajitas_inventario').doc(herramientaId).get();
      if (!herramientaSnap.exists) throw StateError('La herramienta no existe');
      final data = herramientaSnap.data()!;
      if (data['trabajador_actual_id'] != currentUid ||
          data['propietario_original_id'] != propietarioId) {
        throw StateError('Esta devolución ya no está disponible');
      }

      // La devolución también pasa por confirmación del destinatario. Así el
      // historial conserva quién entregó, quién recibió y la hora exacta.
      return iniciarTraspaso(
        herramientaId: herramientaId,
        origenId: currentUid,
        destinoId: propietarioId,
        nombreHerramienta: (data['nombre'] ?? 'Herramienta').toString(),
      );
    } catch (e) {
      debugPrint("Error al devolver herramienta: $e");
      return false;
    }
  }
}
