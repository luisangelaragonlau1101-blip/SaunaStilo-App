import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/historia_social_model.dart';
import '../models/user_model.dart';
import 'media_upload_service.dart';
import 'notificaciones_service.dart';

class SocialService {
  final FirebaseFirestore _db;
  final MediaUploadService _media;

  SocialService({
    FirebaseFirestore? firestore,
    MediaUploadService? media,
  })
    : _db = firestore ?? FirebaseFirestore.instance,
      _media = media ?? MediaUploadService();

  Stream<QuerySnapshot<Map<String, dynamic>>> publicaciones() =>
      _db.collection('publicaciones_sociales').snapshots();

  Stream<List<HistoriaSocialModel>> historiasVigentes() => _db
      .collection('historias_sociales')
      .orderBy('creadaEn', descending: true)
      .limit(80)
      .snapshots()
      .map((snapshot) {
        final ahora = DateTime.now();
        return snapshot.docs
            .map(HistoriaSocialModel.fromFirestore)
            .where(
              (historia) =>
                  historia.autorId.isNotEmpty &&
                  historia.estaVigente(ahora) &&
                  (historia.texto.isNotEmpty || historia.imagenUrl.isNotEmpty),
            )
            .toList(growable: false);
      });

  Future<void> crearHistoria({
    required UserModel autor,
    required String texto,
    XFile? imagen,
  }) async {
    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty && imagen == null) {
      throw ArgumentError('Escribe una nota o agrega una fotografía.');
    }
    if (textoLimpio.length > 400) {
      throw ArgumentError('La nota puede tener hasta 400 caracteres.');
    }

    final historiaRef = _db.collection('historias_sociales').doc();
    MediaUploadResult? subida;
    try {
      if (imagen != null) {
        final nombreSeguro = _nombreSeguro(imagen.name);
        subida = await _media.upload(
          bytes: await imagen.readAsBytes(),
          fileName: nombreSeguro,
          contentType: _tipoMime(imagen.name),
          folder: 'historias/${autor.id}/${historiaRef.id}',
        );
      }

      final creadaEn = DateTime.now();
      await historiaRef.set({
        'autorId': autor.id,
        'autorNombre': autor.nombre,
        'autorFotoUrl': autor.fotoUrl ?? '',
        'autorRol': autor.rol,
        'texto': textoLimpio,
        'imagenUrl': subida?.url ?? '',
        'imagenRuta': subida?.path ?? '',
        'creadaEn': FieldValue.serverTimestamp(),
        'expiraEn': Timestamp.fromDate(creadaEn.add(const Duration(hours: 24))),
      });
    } catch (_) {
      if (subida != null) {
        try {
          await _media.delete(url: subida.url, path: subida.path);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> eliminarHistoria({
    required HistoriaSocialModel historia,
    required UserModel solicitante,
  }) async {
    if (solicitante.rol != AppRoles.admin &&
        historia.autorId != solicitante.id) {
      throw StateError('Solo puedes eliminar tus propias historias.');
    }
    if (historia.autorId == solicitante.id &&
        (historia.imagenUrl.isNotEmpty || historia.imagenRuta.isNotEmpty)) {
      try {
        await _media.delete(
          url: historia.imagenUrl,
          path: historia.imagenRuta,
        );
      } catch (_) {
        // La historia debe poder ocultarse aunque su archivo ya no exista.
      }
    }
    await _db.collection('historias_sociales').doc(historia.id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comentarios(String publicacionId) =>
      _db
          .collection('publicaciones_sociales')
          .doc(publicacionId)
          .collection('comentarios')
          .snapshots();

  Future<void> crearPublicacion({
    required UserModel autor,
    required String texto,
    required List<XFile> imagenes,
    List<XFile> videos = const <XFile>[],
    String tipo = 'avance',
  }) async {
    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty && imagenes.isEmpty && videos.isEmpty) {
      throw ArgumentError(
        'Escribe algo o agrega por lo menos una foto o un video.',
      );
    }
    final publicacionRef = _db.collection('publicaciones_sociales').doc();
    final urlsImagenes = <String>[];
    final rutasImagenes = <String>[];
    final urlsVideos = <String>[];
    final rutasVideos = <String>[];
    final subidos = <MediaUploadResult>[];
    try {
      // Validamos el permiso antes de transferir fotografías. Así el usuario
      // recibe un error inmediato y no espera una carga que después se pierde.
      await publicacionRef.set({
        'autorId': autor.id,
        'autorNombre': autor.nombre,
        'autorFotoUrl': autor.fotoUrl ?? '',
        'autorRol': autor.rol,
        'texto': textoLimpio,
        'imagenes': <String>[],
        'rutasStorage': <String>[],
        'videos': <String>[],
        'rutasVideosStorage': <String>[],
        'tipo': tipo,
        'likesPor': <String>[],
        'comentariosCount': 0,
        'estado': imagenes.isEmpty && videos.isEmpty
            ? 'publicado'
            : 'subiendo',
        'fecha': FieldValue.serverTimestamp(),
      });

      for (var index = 0; index < imagenes.length; index++) {
        final imagen = imagenes[index];
        final bytes = await imagen.readAsBytes();
        final nombreSeguro = _nombreSeguro(imagen.name);
        final ruta =
            'comunidad/${autor.id}/${publicacionRef.id}/${index}_$nombreSeguro';
        final resultado = await _media.upload(
          bytes: bytes,
          fileName: nombreSeguro,
          contentType: _tipoMime(imagen.name),
          folder: ruta,
        );
        subidos.add(resultado);
        rutasImagenes.add(resultado.path);
        urlsImagenes.add(resultado.url);
      }

      for (var index = 0; index < videos.length; index++) {
        final video = videos[index];
        final bytes = await video.readAsBytes();
        final nombreSeguro = _nombreSeguro(video.name);
        final ruta =
            'comunidad/${autor.id}/${publicacionRef.id}/videos/$index';
        final resultado = await _media.upload(
          bytes: bytes,
          fileName: nombreSeguro,
          contentType: _tipoMimeVideo(video.name, video.mimeType),
          folder: ruta,
        );
        subidos.add(resultado);
        rutasVideos.add(resultado.path);
        urlsVideos.add(resultado.url);
      }

      if (imagenes.isNotEmpty || videos.isNotEmpty) {
        await publicacionRef.update({
          'imagenes': urlsImagenes,
          'rutasStorage': rutasImagenes,
          'videos': urlsVideos,
          'rutasVideosStorage': rutasVideos,
          'estado': 'publicado',
        });
      }
      // El backend crea un único aviso cuando la publicación queda lista.
      // Evitamos duplicar notificaciones si hubo fotografías o videos.
    } catch (_) {
      for (final archivo in subidos.reversed) {
        try {
          await _media.delete(url: archivo.url, path: archivo.path);
        } catch (_) {}
      }
      try {
        await publicacionRef.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> comentar({
    required String publicacionId,
    required String autorPublicacionId,
    required UserModel autorComentario,
    required String texto,
  }) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    final postRef = _db.collection('publicaciones_sociales').doc(publicacionId);
    final comentarioRef = postRef.collection('comentarios').doc();
    final batch = _db.batch();
    batch.set(comentarioRef, {
      'autorId': autorComentario.id,
      'autorNombre': autorComentario.nombre,
      'autorFotoUrl': autorComentario.fotoUrl ?? '',
      'texto': limpio,
      'fecha': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {'comentariosCount': FieldValue.increment(1)});
    await batch.commit();
    // El trigger del backend publica un único aviso para el comentario.
  }

  Future<void> comentarAudio({
    required String publicacionId,
    required String autorPublicacionId,
    required UserModel autorComentario,
    required Uint8List wav,
    required int duracionSegundos,
  }) async {
    final postRef = _db.collection('publicaciones_sociales').doc(publicacionId);
    final comentarioRef = postRef.collection('comentarios').doc();
    final ruta =
        'comunidad/${autorComentario.id}/$publicacionId/comentarios/${comentarioRef.id}.wav';
    final archivo = await _media.upload(
      bytes: wav,
      fileName: '${comentarioRef.id}.wav',
      contentType: 'audio/wav',
      folder: ruta,
    );
    try {
      final batch = _db.batch();
      batch.set(comentarioRef, {
        'autorId': autorComentario.id,
        'autorNombre': autorComentario.nombre,
        'autorFotoUrl': autorComentario.fotoUrl ?? '',
        'texto': '',
        'audioUrl': archivo.url,
        'audioRuta': archivo.path,
        'duracionSegundos': duracionSegundos,
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'comentariosCount': FieldValue.increment(1)});
      await batch.commit();
      // El trigger del backend publica un único aviso para el audio.
    } catch (_) {
      try {
        await _media.delete(url: archivo.url, path: archivo.path);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> alternarMeGusta({
    required String publicacionId,
    required UserModel usuario,
    required String autorPublicacionId,
    required bool yaLeGusta,
  }) async {
    await _db.collection('publicaciones_sociales').doc(publicacionId).update({
      'likesPor': yaLeGusta
          ? FieldValue.arrayRemove([usuario.id])
          : FieldValue.arrayUnion([usuario.id]),
    });
    if (!yaLeGusta &&
        autorPublicacionId.isNotEmpty &&
        autorPublicacionId != usuario.id) {
      await _crearAvisoSeguro(
        NotificacionesService.datosAviso(
          titulo: 'A alguien le gustó tu publicación',
          mensaje: '${usuario.nombre} indicó que le gusta tu avance.',
          tipo: 'social',
          destinatarioId: autorPublicacionId,
        ),
      );
    }
  }

  Future<void> _crearAvisoSeguro(Map<String, dynamic> datos) async {
    try {
      await _db.collection('notificaciones').add(datos);
    } catch (_) {
      // Una notificación nunca debe cancelar una publicación o comentario.
    }
  }

  String seguimientoId(String seguidorId, String seguidoId) =>
      '${seguidorId}_$seguidoId';

  Stream<bool> siguiendo({required String seguidorId, required String seguidoId}) {
    return _db
        .collection('seguimientos')
        .doc(seguimientoId(seguidorId, seguidoId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> alternarSeguimiento({
    required UserModel seguidor,
    required String seguidoId,
    required String seguidoNombre,
    required bool siguiendo,
  }) async {
    if (seguidor.id == seguidoId) return;
    final ref = _db
        .collection('seguimientos')
        .doc(seguimientoId(seguidor.id, seguidoId));
    if (siguiendo) {
      await ref.delete();
      return;
    }
    final avisoRef = _db.collection('notificaciones').doc();
    final batch = _db.batch();
    batch.set(ref, {
      'seguidorId': seguidor.id,
      'seguidorNombre': seguidor.nombre,
      'seguidoId': seguidoId,
      'seguidoNombre': seguidoNombre,
      'fecha': FieldValue.serverTimestamp(),
    });
    batch.set(
      avisoRef,
      NotificacionesService.datosAviso(
        titulo: 'Nuevo seguidor',
        mensaje: '${seguidor.nombre} comenzó a seguir tus avances.',
        tipo: 'social',
        destinatarioId: seguidoId,
      ),
    );
    await batch.commit();
  }

  static String _nombreSeguro(String nombre) {
    final limpio = nombre.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return limpio.isEmpty ? 'foto.jpg' : limpio;
  }

  static String _tipoMime(String nombre) {
    final n = nombre.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static String _tipoMimeVideo(String nombre, String? mimeType) {
    final detectado = mimeType?.split(';').first.trim().toLowerCase() ?? '';
    if (detectado.startsWith('video/')) return detectado;
    final n = nombre.toLowerCase();
    if (n.endsWith('.webm')) return 'video/webm';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.m4v')) return 'video/x-m4v';
    if (n.endsWith('.3gp')) return 'video/3gpp';
    return 'video/mp4';
  }

  static String _resumenMultimedia(int fotos, int videos) {
    if (fotos > 0 && videos > 0) return 'publicó fotos y videos';
    if (videos > 0) {
      return videos == 1 ? 'publicó un video' : 'publicó videos';
    }
    return fotos == 1
        ? 'publicó una fotografía'
        : 'publicó fotografías';
  }
}
