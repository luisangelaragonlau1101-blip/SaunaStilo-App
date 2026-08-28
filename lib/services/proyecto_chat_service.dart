import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import 'media_upload_service.dart';
import 'notificaciones_service.dart';

class ProyectoChatService {
  final FirebaseFirestore _db;
  final MediaUploadService _media;

  ProyectoChatService({
    FirebaseFirestore? firestore,
    MediaUploadService? media,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _media = media ?? MediaUploadService();

  CollectionReference<Map<String, dynamic>> _mensajes(String proyectoId) =>
      _db.collection('proyectos').doc(proyectoId).collection('conversacion');

  Stream<QuerySnapshot<Map<String, dynamic>>> mensajes(String proyectoId) =>
      _mensajes(proyectoId).orderBy('fecha').snapshots();

  Future<void> enviarMensaje({
    required Proyecto proyecto,
    required UserModel autor,
    required String texto,
    required List<XFile> imagenes,
  }) async {
    final limpio = texto.trim();
    if (limpio.isEmpty && imagenes.isEmpty) return;
    final mensajeRef = _mensajes(proyecto.id).doc();
    final urls = <String>[];
    final rutas = <String>[];
    final subidos = <MediaUploadResult>[];
    try {
      for (var index = 0; index < imagenes.length; index++) {
        final imagen = imagenes[index];
        final ruta =
            'proyectos/${proyecto.id}/chat/${mensajeRef.id}/${index}_${_safeName(imagen.name)}';
        final archivo = await _media.upload(
          bytes: await imagen.readAsBytes(),
          fileName: _safeName(imagen.name),
          contentType: _imageMime(imagen.name),
          folder: ruta,
        );
        subidos.add(archivo);
        rutas.add(archivo.path);
        urls.add(archivo.url);
      }
      await mensajeRef.set({
        'autorId': autor.id,
        'autorNombre': autor.nombre,
        'autorRol': autor.rol,
        'autorFotoUrl': autor.fotoUrl ?? '',
        'texto': limpio,
        'imagenes': urls,
        'rutasStorage': rutas,
        'tipo': imagenes.isNotEmpty ? 'avance' : 'texto',
        'likesPor': <String>[],
        'fecha': FieldValue.serverTimestamp(),
      });
      await _avisarParticipantes(
        proyecto: proyecto,
        autor: autor,
        titulo: 'Nuevo avance · ${proyecto.titulo}',
        mensaje: imagenes.isNotEmpty
            ? '${autor.nombre} compartió fotografías del proyecto.'
            : '${autor.nombre}: $limpio',
      );
    } catch (_) {
      for (final archivo in subidos.reversed) {
        try {
          await _media.delete(url: archivo.url, path: archivo.path);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> enviarAudio({
    required Proyecto proyecto,
    required UserModel autor,
    required Uint8List wav,
    required int duracionSegundos,
  }) async {
    final mensajeRef = _mensajes(proyecto.id).doc();
    final ruta =
        'proyectos/${proyecto.id}/chat/${mensajeRef.id}/audio_${autor.id}.wav';
    final archivo = await _media.upload(
      bytes: wav,
      fileName: 'audio_${autor.id}.wav',
      contentType: 'audio/wav',
      folder: ruta,
    );
    try {
      await mensajeRef.set({
        'autorId': autor.id,
        'autorNombre': autor.nombre,
        'autorRol': autor.rol,
        'autorFotoUrl': autor.fotoUrl ?? '',
        'texto': '',
        'audioUrl': archivo.url,
        'audioRuta': archivo.path,
        'duracionSegundos': duracionSegundos,
        'imagenes': <String>[],
        'tipo': 'audio',
        'likesPor': <String>[],
        'fecha': FieldValue.serverTimestamp(),
      });
      await _avisarParticipantes(
        proyecto: proyecto,
        autor: autor,
        titulo: 'Nuevo audio · ${proyecto.titulo}',
        mensaje: '${autor.nombre} envió una nota de voz al proyecto.',
      );
    } catch (_) {
      try {
        await _media.delete(url: archivo.url, path: archivo.path);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> anunciarReunion({
    required Proyecto proyecto,
    required UserModel autor,
    required String url,
    required bool soloAudio,
  }) async {
    await _mensajes(proyecto.id).add({
      'autorId': autor.id,
      'autorNombre': autor.nombre,
      'autorRol': autor.rol,
      'autorFotoUrl': autor.fotoUrl ?? '',
      'texto': soloAudio
          ? '${autor.nombre} inició una llamada grupal.'
          : '${autor.nombre} inició una videollamada grupal.',
      'reunionUrl': url,
      'tipo': soloAudio ? 'llamada' : 'videollamada',
      'imagenes': <String>[],
      'likesPor': <String>[],
      'fecha': FieldValue.serverTimestamp(),
    });
    await _avisarParticipantes(
      proyecto: proyecto,
      autor: autor,
      titulo: soloAudio
          ? 'Llamada grupal · ${proyecto.titulo}'
          : 'Videollamada grupal · ${proyecto.titulo}',
      mensaje: '${autor.nombre} inició la reunión. Entra desde el chat del proyecto.',
    );
  }

  Future<void> alternarMeGusta({
    required String proyectoId,
    required String mensajeId,
    required String usuarioId,
    required bool activo,
  }) {
    return _mensajes(proyectoId).doc(mensajeId).update({
      'likesPor': activo
          ? FieldValue.arrayRemove([usuarioId])
          : FieldValue.arrayUnion([usuarioId]),
    });
  }

  Future<void> _avisarParticipantes({
    required Proyecto proyecto,
    required UserModel autor,
    required String titulo,
    required String mensaje,
  }) async {
    final destinatarios = proyecto.encargados
        .map((item) => item.toString())
        .where((id) => id.isNotEmpty && id != autor.id)
        .toSet();
    try {
      await _db.collection('notificaciones').add(
        NotificacionesService.datosAviso(
          titulo: titulo,
          mensaje: mensaje,
          tipo: 'proyecto_chat',
          rolesDestinatarios: const ['admin'],
        ),
      );
    } catch (_) {}
    for (final destinatario in destinatarios) {
      try {
        await _db.collection('notificaciones').add(
          NotificacionesService.datosAviso(
            titulo: titulo,
            mensaje: mensaje,
            tipo: 'proyecto_chat',
            destinatarioId: destinatario,
          ),
        );
      } catch (_) {}
    }
  }

  static String _safeName(String value) {
    final clean = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return clean.isEmpty ? 'foto.jpg' : clean;
  }

  static String _imageMime(String value) {
    final name = value.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
