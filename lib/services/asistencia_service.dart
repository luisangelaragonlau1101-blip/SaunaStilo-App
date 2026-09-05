import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'team_profile_helpers.dart';
import 'package:firebase_storage/firebase_storage.dart'; 

class AsistenciaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // 1. Verificar permisos y obtener la ubicación actual del dispositivo
  Future<Position?> obtenerUbicacionActual() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Los permisos de ubicación están denegados permanentemente, no podemos solicitar permisos.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
    );
  }

 Future<Map<String, dynamic>> validarUbicacionesMultiples(List<Map<String, dynamic>> zonasPermitidas) async {
    try {
      Position? position = await obtenerUbicacionActual();
      if (position == null) {
        return {'valido': false, 'lat': 0.0, 'lon': 0.0, 'error': 'No se pudo obtener la ubicación'};
      }

      // FILTRO 1: Ignorar ubicaciones cacheadas viejas (más de 1 minuto)
      if (DateTime.now().difference(position.timestamp).inSeconds > 60) {
        return {'valido': false, 'lat': 0.0, 'lon': 0.0, 'error': 'Ubicación obsoleta, esperando actualización...'};
      }

      // FILTRO 2: Ignorar GPS con mala precisión (más de 60 metros de error)
      if (position.accuracy > 60.0) {
        return {'valido': false, 'lat': 0.0, 'lon': 0.0, 'error': 'Señal GPS débil. Esperando mejor precisión...'};
      }

      for (var zona in zonasPermitidas) {
        double distanciaEnMetros = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          zona['lat'],
          zona['lon'],
        );

        if (distanciaEnMetros <= zona['radio']) {
          return {
            'valido': true,
            'lat': position.latitude,
            'lon': position.longitude,
            'zonaDetectada': zona['nombre'],
            'distancia': distanciaEnMetros,
          };
        }
      }

      return {
        'valido': false,
        'lat': position.latitude,
        'lon': position.longitude,
        'error': 'Fuera del rango de todas las zonas',
      };
    } catch (e) {
      return {'valido': false, 'lat': 0.0, 'lon': 0.0, 'error': e.toString()};
    }
  }

  Future<void> registrarEntradaAutomatica({
    required String trabajadorId,
    required List<Map<String, dynamic>> zonasPermitidas,
    required String horaEntradaConfig, 
    required int toleranciaMinutos,
  }) async {
    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;
    double lat = validacionUbicacion['lat'] ?? 0.0;
    double lon = validacionUbicacion['lon'] ?? 0.0;

    if (!ubicacionValida) throw StateError(validacionUbicacion['error']?.toString() ?? 'No se validó la ubicación.');
    await _actualizarAsistenciaBackend(
      accion: 'entrada',
      latitud: lat,
      longitud: lon,
    );
  }

  Future<Map<String, dynamic>> registrarEntrada({required List<Map<String, dynamic>> zonasPermitidas}) async {
    final location = await validarUbicacionesMultiples(zonasPermitidas);
    if (location['valido'] != true) throw StateError(location['error']?.toString() ?? 'Debes estar en una zona autorizada.');
    return _actualizarAsistenciaBackend(accion: 'entrada',
      latitud: (location['lat'] as num).toDouble(), longitud: (location['lon'] as num).toDouble());
  }

  // 4. Solicitar salida a comer (Enviado por el trabajador)
  Future<void> solicitarSalidaComida(String trabajadorId) async {
    await _actualizarAsistenciaBackend(accion: 'solicitar_comida');
  }

  // 5. Registrar reingreso de comer (Validando ubicación y límite de 70 min)
  Future<Map<String, dynamic>> registrarRegresoComida({
    required String trabajadorId,
    required List<Map<String, dynamic>> zonasPermitidas,
  }) async {
    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;

    // Si están en los tacos y le dan regresar, los bloquea:
    if (!ubicacionValida) {
      return {'exito': false, 'mensaje': 'Debes estar dentro de la empresa para registrar tu regreso.'};
    }

    return _actualizarAsistenciaBackend(
      accion: 'regreso_comida',
      latitud: (validacionUbicacion['lat'] as num?)?.toDouble(),
      longitud: (validacionUbicacion['lon'] as num?)?.toDouble(),
    );
  }

// 6. Enviar justificación de falta o retardo
Future<void> enviarJustificacion({
  required String trabajadorId,
  required DateTime fechaAsistencia,
  required String motivo,
  required String? evidenciaUrl,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final reason = motivo.trim();
  final day = DateTime(fechaAsistencia.year, fechaAsistencia.month, fechaAsistencia.day);
  if (uid != trabajadorId || reason.isEmpty || reason.length > 2000 || day.isAfter(mexicoToday())) {
    throw StateError('Revisa la sesión, la fecha y el motivo (hasta 2000 caracteres).');
  }
  final docId = '${trabajadorId}_${DateFormat('yyyyMMdd').format(day)}';
  String? savedUrl;
  if (evidenciaUrl != null && evidenciaUrl.isNotEmpty) {
    // XFile supports both native files and the blob URLs returned by Safari.
    if (evidenciaUrl.startsWith('https://')) {
      final reference = FirebaseStorage.instance.refFromURL(evidenciaUrl);
      if (!reference.fullPath.startsWith('justification_evidence/$uid/')) throw StateError('La evidencia no pertenece a tu cuenta.');
      savedUrl = evidenciaUrl;
    } else {
      final bytes = await XFile(evidenciaUrl).readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) throw StateError('La evidencia debe pesar menos de 5 MB.');
      final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78;
      final jpeg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
      final webp = bytes.length > 12 && bytes[0] == 82 && bytes[1] == 73 && bytes[8] == 87 && bytes[9] == 69;
      if (!png && !jpeg && !webp) throw StateError('Usa una imagen JPG, PNG o WebP.');
      final extension = png ? 'png' : webp ? 'webp' : 'jpg';
      final ref = FirebaseStorage.instance.ref('justification_evidence/$uid/$docId/${DateTime.now().microsecondsSinceEpoch}.$extension');
      await ref.putData(bytes, SettableMetadata(contentType: png ? 'image/png' : webp ? 'image/webp' : 'image/jpeg'));
      savedUrl = await ref.getDownloadURL();
    }
  }
  final ref = _firestore.collection('asistencias').doc(docId);
  await _firestore.runTransaction((transaction) async {
    final record = await transaction.get(ref);
    if (record.exists && record.data()?['estatusJustificacion'] == 'aprobada') throw StateError('Esta fecha ya tiene una justificación aprobada.');
    final changes = <String, dynamic>{'motivoFalta': reason, 'estatusJustificacion': 'pendiente_revision', 'evidenciaJustificacionUrl': savedUrl ?? record.data()?['evidenciaJustificacionUrl']?.toString() ?? ''};
    if (record.exists) {
      transaction.update(ref, changes); // Never overwrite hours or attendance status.
    } else {
      transaction.set(ref, {...changes, 'id': docId, 'trabajadorId': trabajadorId, 'fecha': Timestamp.fromDate(DateTime.utc(day.year, day.month, day.day, 18)), 'estatus': 'falta', 'estatusComida': 'ninguna', 'ubicacionValida': false});
    }
  });
}

  Future<void> actualizarObservaciones({
    required String asistenciaId,
    String? observacionesTrabajador,
    String? observacionesAdmin,
  }) async {
    Map<String, dynamic> datosAActualizar = {};
    if (observacionesTrabajador != null) datosAActualizar['observacionesTrabajador'] = observacionesTrabajador;
    if (observacionesAdmin != null) datosAActualizar['observacionesAdmin'] = observacionesAdmin;

    await _firestore.collection('asistencias').doc(asistenciaId).update(datosAActualizar);
  }

Future<Map<String, dynamic>> registrarSalida({
    required String trabajadorId,
    required List<Map<String, dynamic>> zonasPermitidas,
    String? horaSalidaOficial, // NUEVO PARÁMETRO (Ej. '18:00')
  }) async {
    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;

    if (!ubicacionValida) {
      return {'exito': false, 'mensaje': 'Acércate a la empresa para registrar tu salida.'};
    }

    return _actualizarAsistenciaBackend(
      accion: 'salida',
      latitud: (validacionUbicacion['lat'] as num?)?.toDouble(),
      longitud: (validacionUbicacion['lon'] as num?)?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _actualizarAsistenciaBackend({
    required String accion,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'updateAttendance',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call(<String, dynamic>{
        'accion': accion,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
      });
      if (result.data is! Map) throw StateError('El servidor no confirmó el registro.');
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['exito'] != true) throw StateError(data['mensaje']?.toString() ?? 'El servidor no confirmó el registro.');
      return data;
    } on FirebaseFunctionsException catch (error) {
      if (['not-found', 'unavailable', 'internal'].contains(error.code)) {
        throw StateError('El servicio de asistencia no está disponible. Administración debe activar updateAttendance en Firebase. Tu horario NO se registró.');
      }
      throw StateError(error.message ?? 'No se pudo registrar la asistencia. Tu horario NO se registró.');
    }
  }

// 9. (Admin) Justificación de una falta o retardo
  Future<void> resolverJustificacion({
    required String asistenciaId,
    required bool aprobada,
    String? notaAdmin,
  }) async {
    await _firestore.collection('asistencias').doc(asistenciaId).update({
      'estatusJustificacion': aprobada ? 'aprobada' : 'rechazada',
      'estatus': aprobada ? 'justificado' : 'falta',
      'observacionesAdmin': notaAdmin ?? (aprobada ? 'Justificación aprobada' : 'Justificación rechazada'),
    });
  }


// Cerrar turnos olvidados de días anteriores usando la hora de salida oficial
  Future<void> auditarYCerrarDiasAnteriores(String trabajadorId, String? horaSalidaConfig) async {
    DateTime ayer = DateTime.now().subtract(const Duration(days: 1));
    String docIdAyer = "${trabajadorId}_${DateFormat('yyyyMMdd').format(ayer)}";

    DocumentReference docRef = _firestore.collection('asistencias').doc(docIdAyer);
    DocumentSnapshot docSnap = await docRef.get();

    if (docSnap.exists) {
      Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
      
      // Si tiene entrada pero NO tiene salida
      if (data['horaEntrada'] != null && data['horaSalida'] == null) {
        DateTime cierreAutomatico;
        
        // Verificamos que el trabajador tenga una hora de salida asignada 
        if (horaSalidaConfig != null && horaSalidaConfig.isNotEmpty) {
          List<String> partes = horaSalidaConfig.split(':');
          cierreAutomatico = DateTime(
            ayer.year, 
            ayer.month, 
            ayer.day, 
            int.parse(partes[0]), 
            int.parse(partes[1])
          );
        } else {
          // Respaldo de seguridad por si el perfil del trabajador está incompleto
          cierreAutomatico = DateTime(ayer.year, ayer.month, ayer.day, 23, 59, 59);
        }
        
        String obsActual = data['observacionesAdmin'] ?? '';
        String notaCierre = '⚠️ Sistema: Cierre automático por omisión. Se asignó la hora de salida oficial.';
        
        await docRef.update({
          'horaSalida': Timestamp.fromDate(cierreAutomatico),
          'observacionesAdmin': obsActual.isEmpty ? notaCierre : '$obsActual\n$notaCierre',
        });
      }
    }
  }


}
