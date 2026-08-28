import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _fechaDocumento(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  return DateTime.now();
}

int _enteroDocumento(dynamic valor) {
  if (valor is num) return valor.toInt();
  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

String _textoDocumento(dynamic valor) => valor is String ? valor : '';

class EvidenciaActividad {
  final String id;
  final String url;
  final String storagePath;
  final String nombre;
  final String tipoMime;
  final int tamanioBytes;
  final String usuarioId;
  final String avanceId;
  final DateTime creadoEn;

  const EvidenciaActividad({
    required this.id,
    required this.url,
    required this.storagePath,
    required this.nombre,
    required this.tipoMime,
    required this.tamanioBytes,
    required this.usuarioId,
    required this.avanceId,
    required this.creadoEn,
  });

  bool get esImagen => tipoMime.toLowerCase().startsWith('image/');

  factory EvidenciaActividad.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return EvidenciaActividad(
      id: document.id,
      url: _textoDocumento(data['url']),
      storagePath: _textoDocumento(data['storagePath']),
      nombre: _textoDocumento(data['nombre']),
      tipoMime: _textoDocumento(data['tipoMime']),
      tamanioBytes: _enteroDocumento(data['tamanioBytes']),
      usuarioId: _textoDocumento(data['usuarioId']),
      avanceId: _textoDocumento(data['avanceId']),
      creadoEn: _fechaDocumento(data['creadoEn']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'storagePath': storagePath,
      'nombre': nombre,
      'tipoMime': tipoMime,
      'tamanioBytes': tamanioBytes,
      'usuarioId': usuarioId,
      'avanceId': avanceId,
      'creadoEn': creadoEn,
    };
  }
}

class AvanceActividad {
  final String id;
  final String comentario;
  final String trabajadorId;
  final DateTime fecha;
  final bool esCierre;
  final int cantidadEvidencias;

  const AvanceActividad({
    required this.id,
    required this.comentario,
    required this.trabajadorId,
    required this.fecha,
    required this.esCierre,
    required this.cantidadEvidencias,
  });

  factory AvanceActividad.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AvanceActividad(
      id: document.id,
      comentario: _textoDocumento(data['comentario']),
      trabajadorId: _textoDocumento(data['trabajadorId']),
      fecha: _fechaDocumento(data['fecha']),
      esCierre: data['esCierre'] is bool ? data['esCierre'] as bool : false,
      cantidadEvidencias: _enteroDocumento(data['cantidadEvidencias']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comentario': comentario,
      'trabajadorId': trabajadorId,
      'fecha': fecha,
      'esCierre': esCierre,
      'cantidadEvidencias': cantidadEvidencias,
    };
  }
}

class ArchivoEvidenciaPendiente {
  final String nombre;
  final String tipoMime;
  final int tamanioBytes;
  final Future<Uint8List> Function() _lectorBytes;

  ArchivoEvidenciaPendiente({
    required this.nombre,
    required this.tipoMime,
    required this.tamanioBytes,
    required Future<Uint8List> Function() lectorBytes,
  }) : _lectorBytes = lectorBytes;

  /// Lee el archivo solamente cuando llega su turno de subida. Así una
  /// selección grande no mantiene todos los binarios simultáneamente en RAM.
  Future<Uint8List> cargarBytes() => _lectorBytes();
}
