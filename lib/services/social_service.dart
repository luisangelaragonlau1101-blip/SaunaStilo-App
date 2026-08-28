import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import 'notificaciones_service.dart';

class SocialService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  SocialService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> publicaciones() =>
      _db.collection('publicaciones_sociales').snapshots();

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
    String tipo = 'avance',
  }) async {
    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty && imagenes.isEmpty) {
      throw ArgumentError('Escribe algo o agrega por lo menos una fotografía.');
    }
    final publicacionRef = _db.collection('publicaciones_sociales').doc();
    final urls = <String>[];
    final rutas = <String>[];
    try {
      for (var index = 0; index < imagenes.length; index++) {
        final imagen = imagenes[index];
        final bytes = await imagen.readAsBytes();
        final nombreSeguro = _nombreSeguro(imagen.name);
        final ruta =
            'comunidad/${autor.id}/${publicacionRef.id}/${index}_$nombreSeguro';
        final ref = _storage.ref(ruta);
        await ref.putData(
          bytes,
          SettableMetadata(contentType: _tipoMime(imagen.name)),
        );
        rutas.add(ruta);
        urls.add(await ref.getDownloadURL());
      }

      await publicacionRef.set({
        'autorId': autor.id,
        'autorNombre': autor.nombre,
        'autorFotoUrl': autor.fotoUrl ?? '',
        'autorRol': autor.rol,
        'texto': textoLimpio,
        'imagenes': urls,
        'rutasStorage': rutas,
        'tipo': tipo,
        'likesPor': <String>[],
        'comentariosCount': 0,
        'fecha': FieldValue.serverTimestamp(),
      });
      await _crearAvisoSeguro(
        NotificacionesService.datosAviso(
          titulo: autor.rol == AppRoles.admin
              ? 'Nuevo comunicado de Sauna Stilo'
              : 'Nuevo avance en la comunidad',
          mensaje: '${autor.nombre}: ${textoLimpio.isEmpty ? 'publicó fotografías' : textoLimpio}',
          tipo: 'social',
          rolesDestinatarios: autor.rol == AppRoles.admin
              ? const ['todos']
              : const ['admin'],
        ),
      );
    } catch (_) {
      for (final ruta in rutas) {
        try {
          await _storage.ref(ruta).delete();
        } catch (_) {}
      }
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
    await _crearAvisoSeguro(
      NotificacionesService.datosAviso(
        titulo: 'Nuevo comentario en la comunidad',
        mensaje: '${autorComentario.nombre}: $limpio',
        tipo: 'social',
        rolesDestinatarios: const ['todos'],
      ),
    );
    if (autorPublicacionId.isNotEmpty &&
        autorPublicacionId != autorComentario.id) {
      await _crearAvisoSeguro(
        NotificacionesService.datosAviso(
          titulo: 'Nueva sugerencia en tu publicación',
          mensaje: '${autorComentario.nombre}: $limpio',
          tipo: 'social',
          destinatarioId: autorPublicacionId,
        ),
      );
    }
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
    final storageRef = _storage.ref(ruta);
    await storageRef.putData(
      wav,
      SettableMetadata(
        contentType: 'audio/wav',
        customMetadata: <String, String>{
          'autorId': autorComentario.id,
          'duracionSegundos': '$duracionSegundos',
        },
      ),
    );
    try {
      final audioUrl = await storageRef.getDownloadURL();
      final batch = _db.batch();
      batch.set(comentarioRef, {
        'autorId': autorComentario.id,
        'autorNombre': autorComentario.nombre,
        'autorFotoUrl': autorComentario.fotoUrl ?? '',
        'texto': '',
        'audioUrl': audioUrl,
        'audioRuta': ruta,
        'duracionSegundos': duracionSegundos,
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'comentariosCount': FieldValue.increment(1)});
      await batch.commit();
      await _crearAvisoSeguro(
        NotificacionesService.datosAviso(
          titulo: 'Nuevo audio en la comunidad',
          mensaje: '${autorComentario.nombre} envió un comentario de voz.',
          tipo: 'social',
          rolesDestinatarios: const ['todos'],
        ),
      );
      if (autorPublicacionId.isNotEmpty &&
          autorPublicacionId != autorComentario.id) {
        await _crearAvisoSeguro(
          NotificacionesService.datosAviso(
            titulo: 'Nuevo audio en tu publicación',
            mensaje: '${autorComentario.nombre} comentó con una nota de voz.',
            tipo: 'social',
            destinatarioId: autorPublicacionId,
          ),
        );
      }
    } catch (_) {
      try {
        await storageRef.delete();
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
}
