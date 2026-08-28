import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; 
import '../models/asistencia_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart'; 

class AsistenciaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      desiredAccuracy: LocationAccuracy.best, 
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
    DateTime ahora = DateTime.now();

    // Fijamos la fecha a las 12:00 p.m. para evitar brincos de zona horaria
    DateTime hoyFecha = DateTime(ahora.year, ahora.month, ahora.day, 12, 0, 0);

    String docId = "${trabajadorId}_${DateFormat('yyyyMMdd').format(ahora)}";

    // Validar ubicación GPS contra la lista de coordenadas
    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;
    double lat = validacionUbicacion['lat'] ?? 0.0;
    double lon = validacionUbicacion['lon'] ?? 0.0;

    // Si no está en ninguna zona de la empresa, abortamos el registro de entrada
    if (!ubicacionValida) return;

    DocumentReference docRef = _firestore.collection('asistencias').doc(docId);
    DocumentSnapshot docSnap = await docRef.get();

    // Si NO existe el documento de hoy, lo creamos (es su entrada)
    if (!docSnap.exists) {
      // Calcular si llegó a tiempo o con retardo
      List<String> partesHora = horaEntradaConfig.split(':');
      int horaConf = int.parse(partesHora[0]);
      int minConf = int.parse(partesHora[1]);

      DateTime limiteTiempo = DateTime(ahora.year, ahora.month, ahora.day, horaConf, minConf)
          .add(Duration(minutes: toleranciaMinutos));

      String estatus = ahora.isAfter(limiteTiempo) ? 'retardo' : 'a_tiempo';

      AsistenciaModel nuevaAsistencia = AsistenciaModel(
        id: docId,
        trabajadorId: trabajadorId,
        fecha: hoyFecha,
        horaEntrada: ahora,
        estatus: estatus,
        ubicacionValida: true,
        latitudRegistro: lat,
        longitudRegistro: lon,
observacionesTrabajador: 'Entrada registrada en: ${validacionUbicacion['zonaDetectada']}',
      );
// Convertimos el modelo a datos de Firestore
      Map<String, dynamic> datosAsistencia = nuevaAsistencia.toJson();
      
      // 🚀 TRUCO MAESTRO: Forzamos la hora exacta, in-hackeable, de los servidores de Google
      datosAsistencia['horaEntrada'] = FieldValue.serverTimestamp();

      await docRef.set(datosAsistencia);
    }
  }

  // 4. Solicitar salida a comer (Enviado por el trabajador)
  Future<void> solicitarSalidaComida(String trabajadorId) async {
    DateTime ahora = DateTime.now();
    String docId = "${trabajadorId}_${DateFormat('yyyyMMdd').format(ahora)}";

    await _firestore.collection('asistencias').doc(docId).update({
      'salidaComidaSolicitada': Timestamp.fromDate(ahora),
      'estatusComida': 'pendiente_aprobacion',
    });
  }

  // 5. Registrar reingreso de comer (Validando ubicación y límite de 70 min)
  Future<Map<String, dynamic>> registrarRegresoComida({
    required String trabajadorId,
    required List<Map<String, dynamic>> zonasPermitidas,
  }) async {
    DateTime ahora = DateTime.now();
    String docId = "${trabajadorId}_${DateFormat('yyyyMMdd').format(ahora)}";

    // 1. Validar ubicación contra toda la malla de la empresa
    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;

    // Si están en los tacos y le dan regresar, los bloquea:
    if (!ubicacionValida) {
      return {'exito': false, 'mensaje': 'Debes estar dentro de la empresa para registrar tu regreso.'};
    }

    // 2. Traer el registro para saber a qué hora exacta los dejó salir el admin
    DocumentSnapshot docSnap = await _firestore.collection('asistencias').doc(docId).get();
    if (!docSnap.exists) return {'exito': false, 'mensaje': 'No hay registro de asistencia hoy.'};

    Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
    if (data['salidaComidaReal'] == null) {
      return {'exito': false, 'mensaje': 'No se registró tu hora de salida a comer.'};
    }

    DateTime salidaReal = (data['salidaComidaReal'] as Timestamp).toDate();
    
    // 3. Calcular si están dentro de los 70 minutos (60 min + 10 de tolerancia)
    int minutosTranscurridos = ahora.difference(salidaReal).inMinutes;
    bool regresoATiempo = minutosTranscurridos <= 70;

    String notaTiempo = regresoATiempo 
        ? 'Regreso de comida a tiempo ($minutosTranscurridos min)'
        : 'Retardo en comida ($minutosTranscurridos min. de los 70 permitidos)';

    // Agregar la nota automática a las observaciones del trabajador
    String obsActual = data['observacionesTrabajador'] ?? '';
    String nuevaObs = obsActual.isEmpty ? notaTiempo : '$obsActual\n$notaTiempo';

    await _firestore.collection('asistencias').doc(docId).update({
      'regresoComidaReal': Timestamp.fromDate(ahora),
      'estatusComida': 'finalizada',
      'ubicacionRegresoComidaValida': true,
      'observacionesTrabajador': nuevaObs, 
    });

    return {
      'exito': true, 
      'mensaje': regresoATiempo 
          ? '¡Regreso a tiempo! Te tomó $minutosTranscurridos minutos.' 
          : 'Regresaste con retardo. Tiempo total: $minutosTranscurridos minutos.'
    };
  }

// 6. Enviar justificación de falta o retardo
Future<void> enviarJustificacion({
  required String trabajadorId,
  required DateTime fechaAsistencia,
  required String motivo,
  required String? evidenciaUrl, 
}) async {
  String docId = "${trabajadorId}_${DateFormat('yyyyMMdd').format(fechaAsistencia)}";
  String? urlDescarga;

  // Fijamos la fecha a las 12:00 p.m. también aquí
  DateTime fechaSinHora = DateTime(fechaAsistencia.year, fechaAsistencia.month, fechaAsistencia.day, 12, 0, 0);

  if (evidenciaUrl != null && evidenciaUrl.isNotEmpty && !evidenciaUrl.startsWith('http')) {
    try {
      File archivoImagen = File(evidenciaUrl);
      String nombreArchivo = 'justificaciones/${docId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(nombreArchivo);
      await ref.putFile(archivoImagen);
      urlDescarga = await ref.getDownloadURL();
    } catch (e) {
      print("Error al subir la imagen: $e");
    }
  } else {
    urlDescarga = evidenciaUrl;
  }

  DocumentReference docRef = _firestore.collection('asistencias').doc(docId);
  DocumentSnapshot docSnap = await docRef.get();

  Map<String, dynamic> datosJustificacion = {
    'motivoFalta': motivo,
    if (urlDescarga != null) 'evidenciaJustificacionUrl': urlDescarga, 
    'estatusJustificacion': 'pendiente_revision',
  };

if (docSnap.exists) {
    await docRef.update(datosJustificacion);
  } else {
    datosJustificacion.addAll({
      'id': docId,
      'trabajadorId': trabajadorId,
      'fecha': Timestamp.fromDate(fechaSinHora),
      'estatus': 'falta',
      'estatusComida': 'ninguna',
      'ubicacionValida': false,
    });
    await docRef.set(datosJustificacion);
  }
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
    DateTime ahora = DateTime.now();
    String docId = "${trabajadorId}_${DateFormat('yyyyMMdd').format(ahora)}";

    Map<String, dynamic> validacionUbicacion = await validarUbicacionesMultiples(zonasPermitidas);
    bool ubicacionValida = validacionUbicacion['valido'] ?? false;

    if (!ubicacionValida) {
      return {'exito': false, 'mensaje': 'Acércate a la empresa para registrar tu salida.'};
    }

    DocumentSnapshot docSnap = await _firestore.collection('asistencias').doc(docId).get();
    if (!docSnap.exists) {
      return {'exito': false, 'mensaje': 'No tienes registro de entrada el día de hoy.'};
    }

    Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
    String obsActual = data['observacionesTrabajador'] ?? '';
    String notaSalida = 'Salida registrada en: ${validacionUbicacion['zonaDetectada']}';

    if (horaSalidaOficial != null) {
      List<String> partes = horaSalidaOficial.split(':');
      DateTime limiteSalida = DateTime(ahora.year, ahora.month, ahora.day, int.parse(partes[0]), int.parse(partes[1]));
      
      if (ahora.isBefore(limiteSalida)) {
        int minutosFaltantes = limiteSalida.difference(ahora).inMinutes;
        notaSalida += '\n SALIDA ANTICIPADA: Se retiró $minutosFaltantes min. antes de su hora.';
      }
    }

    String nuevaObs = obsActual.isEmpty ? notaSalida : '$obsActual\n$notaSalida';

 await _firestore.collection('asistencias').doc(docId).update({
      'horaSalida': FieldValue.serverTimestamp(),
      'observacionesTrabajador': nuevaObs,
    });

    return {
      'exito': true,
      'mensaje': 'Salida registrada a las ${DateFormat('HH:mm').format(ahora)}'
    };
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