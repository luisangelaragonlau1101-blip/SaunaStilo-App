import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/proyecto_model.dart';

class ResultadoSalidaInstalacion {
  final String registroId;
  final bool incluyoUbicacion;

  const ResultadoSalidaInstalacion({
    required this.registroId,
    required this.incluyoUbicacion,
  });
}

class SalidaInstalacionService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SalidaInstalacionService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  Future<ResultadoSalidaInstalacion> registrarSalida({
    required Proyecto proyecto,
    required String usuarioNombre,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para registrar tu salida.');
    }

    final proyectoActual = await _db
        .collection('proyectos')
        .doc(proyecto.id)
        .get();
    if (!proyectoActual.exists) {
      throw StateError('El proyecto ya no está disponible.');
    }
    final proyectoData = proyectoActual.data() ?? const <String, dynamic>{};
    final encargados = proyectoData['encargados'] is Iterable
        ? (proyectoData['encargados'] as Iterable)
              .map((item) => item.toString())
              .toList(growable: false)
        : const <String>[];
    if (!encargados.contains(user.uid)) {
      throw StateError('Este proyecto no está asignado a tu perfil.');
    }

    final perfil = await _db.collection('usuarios').doc(user.uid).get();
    final nombrePerfil = perfil.data()?['nombre']?.toString().trim() ?? '';
    final nombreResuelto = nombrePerfil.isNotEmpty
        ? nombrePerfil
        : usuarioNombre.trim().isNotEmpty
        ? usuarioNombre.trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Trabajador');
    final posicion = await _ubicacionDisponible();
    final data = <String, dynamic>{
      'proyectoId': proyecto.id,
      'proyectoTitulo':
          proyectoData['titulo']?.toString().trim().isNotEmpty == true
          ? proyectoData['titulo'].toString().trim()
          : proyecto.titulo.trim().isEmpty
          ? 'Proyecto Sauna Stilo'
          : proyecto.titulo.trim(),
      'usuarioId': user.uid,
      'usuarioNombre': nombreResuelto,
      'fecha': FieldValue.serverTimestamp(),
      'ubicacionRegistrada': posicion != null,
      'origen': 'proyecto',
      if (posicion != null) ...{
        'ubicacion': GeoPoint(posicion.latitude, posicion.longitude),
        'precisionMetros': posicion.accuracy,
      },
    };

    final registro = await _db.collection('salidas_instalacion').add(data);
    return ResultadoSalidaInstalacion(
      registroId: registro.id,
      incluyoUbicacion: posicion != null,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> historial({
    required String proyectoId,
    required String usuarioId,
  }) {
    return _db
        .collection('salidas_instalacion')
        .where('proyectoId', isEqualTo: proyectoId)
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots();
  }

  Future<Position?> _ubicacionDisponible() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      // El registro sigue siendo válido aunque el dispositivo no entregue GPS.
      return null;
    }
  }
}
