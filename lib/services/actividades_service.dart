import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/actividad_model.dart';
import '../models/evidencia_actividad_model.dart';
import 'media_upload_service.dart';
import 'notificaciones_service.dart';

class ActividadesService {
  final FirebaseFirestore _db;
  final FirebaseAuth? _auth;
  final MediaUploadService _media;

  ActividadesService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    MediaUploadService? media,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth,
       _media = media ?? MediaUploadService(auth: auth);

  CollectionReference<Map<String, dynamic>> get _actividadesRef =>
      _db.collection('actividades');

  CollectionReference<Map<String, dynamic>> _evidenciasRef(
    String actividadId,
  ) => _actividadesRef.doc(actividadId).collection('evidencias');

  CollectionReference<Map<String, dynamic>> _avancesRef(String actividadId) =>
      _actividadesRef.doc(actividadId).collection('avances');

  // Task persistence is independent of notification delivery. A retry reuses its ID.
  Future<void> crearActividad(ActividadModel actividad) async {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión para asignar tareas.');
    if (actividad.id.isEmpty) actividad.id = _actividadesRef.doc().id;
    final ref = _actividadesRef.doc(actividad.id);
    await _db.runTransaction((tx) async {
      final profile = await tx.get(_db.collection('usuarios').doc(uid));
      final target = await tx.get(_db.collection('usuarios').doc(actividad.asignadoATrabajadorId));
      final role = profile.data()?['rol'];
      if (!profile.exists || profile.data()?['activo'] == false) throw StateError('Tu cuenta no está activa.');
      if (!target.exists || target.data()?['activo'] == false) throw StateError('La persona no tiene una cuenta activa.');
      if (actividad.proyectoId.isNotEmpty) {
        final project = await tx.get(_db.collection('proyectos').doc(actividad.proyectoId));
        final members = (project.data()?['encargados'] as List? ?? const []).whereType<String>().toList();
        if (!project.exists) throw StateError('El proyecto ya no existe.');
        if (role != 'admin' && (role != 'maestro' || !members.contains(uid) || !members.contains(target.id))) {
          throw StateError('El maestro debe estar asignado al proyecto y elegir a uno de sus integrantes.');
        }
      } else if (role != 'admin') {
        throw StateError('Solo Administración puede asignar tareas generales sin proyecto.');
      }
      if (actividad.titulo.trim().length < 3 || actividad.titulo.length > 150 || actividad.descripcion.length > 2000 || !actividad.fechaTermino.isAfter(actividad.fechaInicio)) {
        throw StateError('Revisa el título, las indicaciones y la fecha de entrega.');
      }
      final old = await tx.get(ref);
      if (old.exists) {
        if (old.data()?['creadoPor'] != uid || old.data()?['proyectoId'] != actividad.proyectoId || old.data()?['titulo'] != actividad.titulo || old.data()?['descripcion'] != actividad.descripcion || old.data()?['asignadoATrabajadorId'] != actividad.asignadoATrabajadorId) {
          throw StateError('El identificador de la tarea ya está en uso.');
        }
        return; // Previously confirmed; never reset progress on a retry.
      }
      tx.set(ref, actividad.toJson()..addAll({'creadoPor': uid, 'creadoEn': FieldValue.serverTimestamp()}));
      // Creating a task must not rewrite the project or its financial workflow.
    });
    try {
      final notice = NotificacionesService.datosAviso(titulo: 'Nueva tarea asignada', mensaje: actividad.titulo,
        tipo: 'tarea', destinatarioId: actividad.asignadoATrabajadorId)
        ..addAll({'actividadId': ref.id, 'proyectoId': actividad.proyectoId});
      await _db.collection('notificaciones').doc('tarea_${ref.id}').set(notice).timeout(const Duration(seconds: 8));
    } catch (_) {
      // The task remains saved; a failed push must never make the user create it twice.
    }
  }

  // Obtener actividades por proyecto. Se ordena localmente para no exigir un
  // índice compuesto adicional en Firestore.
  Stream<List<ActividadModel>> obtenerActividadesPorProyecto(
    String proyectoId,
  ) {
    return _actividadesRef
        .where('proyectoId', isEqualTo: proyectoId)
        .snapshots()
        .map((snapshot) {
          final lista = snapshot.docs
              .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
              .toList(growable: true);
          lista.sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
          return lista;
        });
  }

  /// Evidencias más recientes primero. El orden se realiza en Dart para evitar
  /// que documentos históricos sin `creadoEn` rompan la consulta.
  Stream<List<EvidenciaActividad>> obtenerEvidenciasActividad(
    String actividadId,
  ) {
    return _evidenciasRef(actividadId).snapshots().map((snapshot) {
      final evidencias = snapshot.docs
          .map(EvidenciaActividad.fromDocument)
          .toList(growable: true);
      evidencias.sort((a, b) {
        final porFecha = b.creadoEn.compareTo(a.creadoEn);
        return porFecha != 0 ? porFecha : b.id.compareTo(a.id);
      });
      return evidencias;
    });
  }

  /// Avances más recientes primero, ordenados del lado del cliente.
  Stream<List<AvanceActividad>> obtenerAvancesActividad(String actividadId) {
    return _avancesRef(actividadId).snapshots().map((snapshot) {
      final avances = snapshot.docs
          .map(AvanceActividad.fromDocument)
          .toList(growable: true);
      avances.sort((a, b) {
        final porFecha = b.fecha.compareTo(a.fecha);
        return porFecha != 0 ? porFecha : b.id.compareTo(a.id);
      });
      return avances;
    });
  }

  /// Registra un avance y sube todos sus archivos, uno por uno, sin imponer un
  /// límite de cantidad. Cada archivo vive en su propio documento para evitar
  /// que el documento principal alcance el límite de tamaño de Firestore.
  Future<void> registrarAvance({
    required String actividadId,
    required String trabajadorId,
    required String comentario,
    required List<ArchivoEvidenciaPendiente> archivos,
    bool esCierre = false,
  }) async {
    final actividadIdLimpio = actividadId.trim();
    final trabajadorIdLimpio = trabajadorId.trim();
    final comentarioLimpio = comentario.trim();

    if (actividadIdLimpio.isEmpty) {
      throw ArgumentError('La actividad es obligatoria.');
    }
    if (trabajadorIdLimpio.isEmpty) {
      throw ArgumentError('El trabajador es obligatorio.');
    }
    _validarSesionAutenticada(trabajadorIdLimpio);
    if (comentarioLimpio.isEmpty && archivos.isEmpty) {
      throw ArgumentError(
        'Escribe un avance o adjunta por lo menos una evidencia.',
      );
    }
    final actividadRef = _actividadesRef.doc(actividadIdLimpio);
    final actividadSnapshot = await actividadRef.get();
    if (!actividadSnapshot.exists) {
      throw StateError('La actividad ya no existe.');
    }
    final actividadData =
        actividadSnapshot.data() ?? const <String, dynamic>{};
    _validarTrabajadorAsignado(actividadData, trabajadorIdLimpio);
    if (_estatus(actividadData) == 'completado') {
      throw StateError('Una actividad completada ya no admite avances.');
    }

    final avanceRef = _avancesRef(actividadIdLimpio).doc();
    final evidenciasSubidas = <_EvidenciaSubida>[];
    final documentosEvidenciaEscritos =
        <DocumentReference<Map<String, dynamic>>>[];

    try {
      // La subida deliberadamente es secuencial: no se crea un pico de memoria
      // ni de conexiones aunque el trabajador seleccione muchos archivos.
      for (final archivo in archivos) {
        final bytes = await archivo.cargarBytes();
        if (bytes.isEmpty) {
          throw ArgumentError(
            'El archivo "${archivo.nombre}" está vacío y no se puede subir.',
          );
        }
        final evidenciaRef = _evidenciasRef(actividadIdLimpio).doc();
        final nombreSeguro = _nombreSeguro(archivo.nombre);
        final storagePath =
            'actividades_evidencias/$actividadIdLimpio/'
            '${avanceRef.id}/${evidenciaRef.id}_$nombreSeguro';
        final tipoMime = archivo.tipoMime.trim().isEmpty
            ? 'application/octet-stream'
            : archivo.tipoMime.trim();
        final archivoSubido = await _media.upload(
          bytes: bytes,
          fileName: nombreSeguro,
          contentType: tipoMime,
          folder: storagePath,
        );
        evidenciasSubidas.add(
          _EvidenciaSubida(
            documentRef: evidenciaRef,
            url: archivoSubido.url,
            storagePath: archivoSubido.path,
            nombre: archivo.nombre,
            tipoMime: tipoMime,
            tamanioBytes: bytes.length,
          ),
        );
      }

      // Firestore permite como máximo 500 operaciones por lote. Escribimos
      // las evidencias en grupos para no imponer un límite de archivos desde
      // la aplicación, aunque el trabajador adjunte cientos en un avance.
      const tamanioLote = 400;
      for (var inicio = 0;
          inicio < evidenciasSubidas.length;
          inicio += tamanioLote) {
        final fin = (inicio + tamanioLote < evidenciasSubidas.length)
            ? inicio + tamanioLote
            : evidenciasSubidas.length;
        final loteEvidencias = _db.batch();
        for (final evidencia in evidenciasSubidas.sublist(inicio, fin)) {
          loteEvidencias.set(evidencia.documentRef, {
            'url': evidencia.url,
            'storagePath': evidencia.storagePath,
            'nombre': evidencia.nombre,
            'tipoMime': evidencia.tipoMime,
            'tamanioBytes': evidencia.tamanioBytes,
            'usuarioId': trabajadorIdLimpio,
            'avanceId': avanceRef.id,
            'creadoEn': FieldValue.serverTimestamp(),
          });
        }
        await loteEvidencias.commit();
        documentosEvidenciaEscritos.addAll(
          evidenciasSubidas
              .sublist(inicio, fin)
              .map((evidencia) => evidencia.documentRef),
        );
      }

      // Relee la actividad al confirmar. Así una reasignación, eliminación u
      // otro avance concurrente no permite que un estado viejo gane la carrera.
      // El avance final y el cambio a completado se guardan atómicamente.
      await _db.runTransaction((transaction) async {
        final snapshotActual = await transaction.get(actividadRef);
        if (!snapshotActual.exists) {
          throw StateError('La actividad ya no existe.');
        }
        final dataActual =
            snapshotActual.data() ?? const <String, dynamic>{};
        _validarTrabajadorAsignado(dataActual, trabajadorIdLimpio);

        final estatusActual = _estatus(dataActual);
        if (estatusActual == 'completado') {
          throw StateError('La actividad ya fue completada.');
        }
        if (esCierre && estatusActual != 'en_progreso') {
          throw StateError(
            'La actividad debe estar en progreso antes de completarla.',
          );
        }
        if (!esCierre &&
            estatusActual != 'pendiente' &&
            estatusActual != 'en_progreso') {
          throw StateError('La actividad no admite nuevos avances.');
        }

        final totalEvidencias =
            _contadorEvidencias(dataActual) + evidenciasSubidas.length;
        if (esCierre && totalEvidencias <= 0) {
          throw StateError(
            'Debes subir por lo menos una evidencia antes de completar la tarea.',
          );
        }

        transaction.set(avanceRef, {
          'comentario': comentarioLimpio,
          'trabajadorId': trabajadorIdLimpio,
          'fecha': FieldValue.serverTimestamp(),
          'esCierre': esCierre,
          'cantidadEvidencias': evidenciasSubidas.length,
        });

        final actualizaciones = <String, dynamic>{
          'ultimoAvance': FieldValue.serverTimestamp(),
        };
        if (comentarioLimpio.isNotEmpty) {
          actualizaciones['comentariosTrabajador'] = comentarioLimpio;
        }
        if (evidenciasSubidas.isNotEmpty || esCierre) {
          actualizaciones['evidenciasCount'] = totalEvidencias;
          actualizaciones['cantidadEvidencias'] = totalEvidencias;
        }
        if (esCierre) {
          actualizaciones['estatus'] = 'completado';
          actualizaciones['completadoEn'] = FieldValue.serverTimestamp();
          final avisoRef = _db.collection('notificaciones').doc();
          transaction.set(
            avisoRef,
            NotificacionesService.datosAviso(
              titulo: 'Tarea terminada',
              mensaje: (dataActual['titulo'] is String)
                  ? dataActual['titulo'] as String
                  : 'Un trabajador terminó una actividad',
              tipo: 'tarea',
              rolesDestinatarios: const ['admin'],
            ),
          );
        } else if (estatusActual == 'pendiente') {
          actualizaciones['estatus'] = 'en_progreso';
          actualizaciones['iniciadoEn'] = FieldValue.serverTimestamp();
        }
        transaction.update(actividadRef, actualizaciones);
      });
    } catch (e) {
      await _eliminarDocumentosEvidencia(documentosEvidenciaEscritos);
      await _eliminarBlobsSubidos(evidenciasSubidas);
      throw Exception('No se pudo registrar el avance: $e');
    }
  }

  /// Pasa una actividad pendiente a en progreso. La operación es idempotente
  /// para el trabajador que ya la inició.
  Future<void> iniciarActividad({
    required String actividadId,
    required String trabajadorId,
  }) async {
    _validarSesionAutenticada(trabajadorId.trim());
    final actividadRef = _actividadesRef.doc(actividadId.trim());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(actividadRef);
      if (!snapshot.exists) throw StateError('La actividad ya no existe.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      _validarTrabajadorAsignado(data, trabajadorId.trim());

      final estatusActual = _estatus(data);
      if (estatusActual == 'en_progreso') return;
      if (estatusActual != 'pendiente') {
        throw StateError(
          'Solo se puede iniciar una actividad que esté pendiente.',
        );
      }
      transaction.update(actividadRef, {
        'estatus': 'en_progreso',
        'iniciadoEn': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Completa la tarea únicamente si pertenece al trabajador, está en progreso
  /// y ya tiene por lo menos una evidencia nueva o histórica.
  Future<void> completarActividadConEvidencia({
    required String actividadId,
    required String trabajadorId,
  }) async {
    _validarSesionAutenticada(trabajadorId.trim());
    final actividadRef = _actividadesRef.doc(actividadId.trim());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(actividadRef);
      if (!snapshot.exists) throw StateError('La actividad ya no existe.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      _validarTrabajadorAsignado(data, trabajadorId.trim());

      final estatusActual = _estatus(data);
      if (estatusActual != 'en_progreso') {
        throw StateError(
          'La actividad debe estar en progreso antes de completarla.',
        );
      }
      final totalEvidencias = _contadorEvidencias(data);
      if (totalEvidencias <= 0) {
        throw StateError(
          'Debes subir por lo menos una evidencia antes de completar la tarea.',
        );
      }

      transaction.update(actividadRef, {
        'estatus': 'completado',
        'completadoEn': FieldValue.serverTimestamp(),
        // Normaliza documentos antiguos que solo tenían evidenciaFotos.
        'evidenciasCount': totalEvidencias,
        'cantidadEvidencias': totalEvidencias,
      });
    });
  }

  // El cierre debe pasar por registrarAvance(esCierre: true) o por el método
  // de compatibilidad completarActividadConEvidencia.
  Future<void> actualizarEstatusActividad(
    String actividadId,
    String nuevoEstatus,
  ) async {
    final estatusLimpio = nuevoEstatus.trim().toLowerCase();
    const estadosDeCierre = {
      'completado',
      'completada',
      'completed',
      'finalizado',
      'terminado',
    };
    if (estadosDeCierre.contains(estatusLimpio)) {
      throw StateError(
        'Para completar una tarea usa completarActividadConEvidencia.',
      );
    }
    if (estatusLimpio.isEmpty) {
      throw ArgumentError('El estatus es obligatorio.');
    }

    try {
      await _actividadesRef.doc(actividadId).update({
        'estatus': estatusLimpio,
      });
    } catch (e) {
      throw Exception('Error al actualizar el estatus: $e');
    }
  }

  // Registrar observaciones del administrador.
  Future<void> registrarObservacionesAdmin(
    String actividadId,
    String observaciones,
  ) async {
    try {
      await _actividadesRef.doc(actividadId).update({
        'observacionesAdmin': observaciones,
      });
    } catch (e) {
      throw Exception('Error al registrar observaciones: $e');
    }
  }

  // Marcar una herramienta como entregada de vuelta.
  Future<void> devolverHerramienta(
    String actividadId,
    int posicionHerramienta,
  ) async {
    try {
      final doc = await _actividadesRef.doc(actividadId).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        final herramientasCrudas = data['herramientasSolicitadas'];
        final herramientas = herramientasCrudas is List
            ? List<dynamic>.from(herramientasCrudas)
            : <dynamic>[];
        if (posicionHerramienta >= 0 &&
            posicionHerramienta < herramientas.length) {
          final herramienta = herramientas[posicionHerramienta];
          if (herramienta is Map) {
            herramienta['entregada'] = true;
            await _actividadesRef.doc(actividadId).update({
              'herramientasSolicitadas': herramientas,
            });
          }
        }
      }
    } catch (e) {
      throw Exception('Error al registrar la devolución de la herramienta: $e');
    }
  }

  Future<void> eliminarActividad(String actividadId) async {
    final actividadIdLimpio = actividadId.trim();
    try {
      final evidenciasSnapshot =
          await _evidenciasRef(actividadIdLimpio).get();
      final avancesSnapshot = await _avancesRef(actividadIdLimpio).get();

      // Limpia los binarios nuevos. Los archivos históricos no guardaban su
      // ruta de Storage, por lo que se conservan para no borrar por conjetura.
      for (final evidencia in evidenciasSnapshot.docs) {
        final datos = evidencia.data();
        final storagePath = datos['storagePath'];
        final url = datos['url'];
        if (storagePath is String && storagePath.trim().isNotEmpty) {
          try {
            await _media.delete(
              url: url is String ? url : '',
              path: storagePath,
            );
          } catch (_) {
            // Si el archivo ya no existe, la eliminación puede continuar.
          }
        }
      }

      await _eliminarDocumentosEnLotes([
        ...evidenciasSnapshot.docs.map((documento) => documento.reference),
        ...avancesSnapshot.docs.map((documento) => documento.reference),
      ]);
      await _actividadesRef.doc(actividadIdLimpio).delete();
    } catch (e) {
      throw Exception('Error al eliminar la actividad: $e');
    }
  }

  /// Solo actualiza los campos administrables. Contadores, evidencias, avances,
  /// estado y fechas del flujo del trabajador permanecen intactos.
  Future<void> actualizarActividad(ActividadModel actividad) async {
    await _actividadesRef.doc(actividad.id).update({
      'titulo': actividad.titulo, 'descripcion': actividad.descripcion,
      'asignadoATrabajadorId': actividad.asignadoATrabajadorId,
      'fechaTermino': actividad.fechaTermino, 'fechaAsignada': actividad.fechaAsignada,
    });
  }

  static String _estatus(Map<String, dynamic> data) {
    final estatus =
        (data['estatus'] is String ? data['estatus'] as String : 'pendiente')
            .trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_');
    const completados = {
      'completada',
      'completed',
      'finalizado',
      'finalizada',
      'terminado',
      'terminada',
    };
    if (completados.contains(estatus)) return 'completado';
    if (estatus == 'en_proceso' || estatus == 'progreso') {
      return 'en_progreso';
    }
    return estatus.isEmpty ? 'pendiente' : estatus;
  }

  static void _validarTrabajadorAsignado(
    Map<String, dynamic> data,
    String trabajadorId,
  ) {
    final asignado = data['asignadoATrabajadorId'] is String
        ? (data['asignadoATrabajadorId'] as String).trim()
        : '';
    if (trabajadorId.isEmpty || asignado != trabajadorId) {
      throw StateError(
        'Esta actividad no está asignada al trabajador autenticado.',
      );
    }
  }

  void _validarSesionAutenticada(String trabajadorId) {
    final uid = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (uid == null || uid.isEmpty || uid != trabajadorId) {
      throw StateError(
        'La sesión autenticada no corresponde al trabajador de la actividad.',
      );
    }
  }

  static int _contadorEvidencias(Map<String, dynamic> data) {
    final contadorNuevo = data['evidenciasCount'];
    if (contadorNuevo is num && contadorNuevo.toInt() > 0) {
      return contadorNuevo.toInt();
    }
    final contadorAnterior = data['cantidadEvidencias'];
    if (contadorAnterior is num && contadorAnterior.toInt() > 0) {
      return contadorAnterior.toInt();
    }
    final fotos = data['evidenciaFotos'];
    return fotos is List ? fotos.length : 0;
  }

  static String _nombreSeguro(String nombre) {
    final limpio = nombre.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    return limpio.isEmpty ? 'evidencia' : limpio;
  }

  Future<void> _eliminarBlobsSubidos(
    List<_EvidenciaSubida> evidencias,
  ) async {
    for (final evidencia in evidencias.reversed) {
      try {
        await _media.delete(
          url: evidencia.url,
          path: evidencia.storagePath,
        );
      } catch (_) {
        // Limpieza de mejor esfuerzo: se conserva el error original de subida o
        // escritura para que la interfaz muestre la causa real al usuario.
      }
    }
  }

  static Future<void> _eliminarDocumentosEvidencia(
    List<DocumentReference<Map<String, dynamic>>> documentos,
  ) async {
    for (final documento in documentos.reversed) {
      try {
        await documento.delete();
      } catch (_) {
        // Limpieza de mejor esfuerzo; se conserva el error que originó el
        // rollback para mostrarlo al trabajador.
      }
    }
  }

  Future<void> _eliminarDocumentosEnLotes(
    List<DocumentReference<Map<String, dynamic>>> documentos,
  ) async {
    const tamanioLote = 400;
    for (var inicio = 0; inicio < documentos.length; inicio += tamanioLote) {
      final fin = (inicio + tamanioLote < documentos.length)
          ? inicio + tamanioLote
          : documentos.length;
      final lote = _db.batch();
      for (final documento in documentos.sublist(inicio, fin)) {
        lote.delete(documento);
      }
      await lote.commit();
    }
  }
}

class _EvidenciaSubida {
  final DocumentReference<Map<String, dynamic>> documentRef;
  final String url;
  final String storagePath;
  final String nombre;
  final String tipoMime;
  final int tamanioBytes;

  _EvidenciaSubida({
    required this.documentRef,
    required this.url,
    required this.storagePath,
    required this.nombre,
    required this.tipoMime,
    required this.tamanioBytes,
  });
}
