import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fechaDesdeFirestore(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  return null;
}

String _textoSeguro(dynamic valor) => valor is String ? valor : '';

int _enteroSeguro(dynamic valor) {
  if (valor is num) return valor.toInt();
  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

List<String> _listaTextosGrowable(dynamic valor) {
  if (valor is! Iterable || valor is String) return <String>[];
  return valor.whereType<String>().toList(growable: true);
}

String _normalizarEstatus(dynamic valor) {
  final estatus = _textoSeguro(valor)
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  switch (estatus) {
    case 'completada':
    case 'completed':
    case 'finalizado':
    case 'finalizada':
    case 'terminado':
    case 'terminada':
      return 'completado';
    case 'en_proceso':
    case 'progreso':
      return 'en_progreso';
    case '':
      return 'pendiente';
    default:
      return estatus;
  }
}

class ActividadModel {
  String id;
  String proyectoId;
  String titulo;
  String descripcion;
  String asignadoATrabajadorId;
  DateTime fechaInicio;
  DateTime fechaTermino;
  DateTime fechaAsignada;
  DateTime? completadoEn;
  String estatus;
  String observacionesAdmin;
  String comentariosTrabajador;
  List<String> evidenciaFotos;
  List<EventoActividad> historialEventos;
  int evidenciasCount;
  DateTime? ultimoAvance;
  bool requiereEvidencia;

  ActividadModel({
    required this.id,
    required this.proyectoId,
    required this.titulo,
    required this.descripcion,
    required this.asignadoATrabajadorId,
    required this.fechaInicio,
    required this.fechaTermino,
    DateTime? fechaAsignada,
    this.completadoEn,
    this.estatus = 'pendiente',
    this.observacionesAdmin = '',
    this.comentariosTrabajador = '',
    List<String>? evidenciaFotos,
    List<EventoActividad>? historialEventos,
    int evidenciasCount = 0,
    this.ultimoAvance,
    this.requiereEvidencia = true,
  }) : fechaAsignada = fechaAsignada ?? fechaInicio,
       evidenciaFotos = List<String>.from(evidenciaFotos ?? const <String>[]),
       historialEventos = List<EventoActividad>.from(
         historialEventos ?? const <EventoActividad>[],
       ),
       evidenciasCount = evidenciasCount < 0 ? 0 : evidenciasCount;

  /// Usa el contador de la nueva estructura y cae al arreglo histórico sin
  /// sumarlos, porque durante la migración ambos pueden representar los mismos
  /// archivos.
  int get totalEvidencias =>
      evidenciasCount > 0 ? evidenciasCount : evidenciaFotos.length;

  factory ActividadModel.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    final fechaInicio =
        _fechaDesdeFirestore(json['fechaInicio']) ??
        _fechaDesdeFirestore(json['fechaAsignada']) ??
        DateTime.now();
    final fechaTermino =
        _fechaDesdeFirestore(json['fechaTermino']) ?? fechaInicio;
    final evidenciaFotos = _listaTextosGrowable(json['evidenciaFotos']);
    final contadorNuevo = _enteroSeguro(json['evidenciasCount']);
    final contadorAnterior = _enteroSeguro(json['cantidadEvidencias']);

    final historialEventos = <EventoActividad>[];
    final historialCrudo = json['historialEventos'];
    if (historialCrudo is Iterable && historialCrudo is! String) {
      for (final item in historialCrudo) {
        if (item is Map) {
          historialEventos.add(
            EventoActividad.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ActividadModel(
      id: documentId,
      proyectoId: _textoSeguro(json['proyectoId']),
      titulo: _textoSeguro(json['titulo']),
      descripcion: _textoSeguro(json['descripcion']),
      asignadoATrabajadorId: _textoSeguro(
        json['asignadoATrabajadorId'],
      ),
      fechaInicio: fechaInicio,
      fechaTermino: fechaTermino,
      fechaAsignada:
          _fechaDesdeFirestore(json['fechaAsignada']) ?? fechaInicio,
      completadoEn: _fechaDesdeFirestore(json['completadoEn']),
      estatus: _normalizarEstatus(json['estatus']),
      observacionesAdmin: _textoSeguro(json['observacionesAdmin']),
      comentariosTrabajador: _textoSeguro(json['comentariosTrabajador']),
      evidenciaFotos: evidenciaFotos,
      historialEventos: historialEventos,
      evidenciasCount: contadorNuevo > 0 ? contadorNuevo : contadorAnterior,
      ultimoAvance: _fechaDesdeFirestore(json['ultimoAvance']),
      requiereEvidencia: json['requiereEvidencia'] is bool
          ? json['requiereEvidencia'] as bool
          : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proyectoId': proyectoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'asignadoATrabajadorId': asignadoATrabajadorId,
      'fechaInicio': fechaInicio,
      'fechaTermino': fechaTermino,
      'fechaAsignada': fechaAsignada,
      'completadoEn': completadoEn,
      'estatus': estatus,
      'observacionesAdmin': observacionesAdmin,
      'comentariosTrabajador': comentariosTrabajador,
      'evidenciaFotos': List<String>.from(evidenciaFotos),
      'historialEventos': historialEventos.map((e) => e.toJson()).toList(),
      'evidenciasCount': evidenciasCount,
      'cantidadEvidencias': evidenciasCount,
      'ultimoAvance': ultimoAvance,
      'requiereEvidencia': requiereEvidencia,
    };
  }
}

// Sub-modelo para el historial de eventos.
class EventoActividad {
  String accion;
  DateTime fecha;
  String usuarioId;

  EventoActividad({
    required this.accion,
    required this.fecha,
    required this.usuarioId,
  });

  factory EventoActividad.fromJson(Map<String, dynamic> json) {
    return EventoActividad(
      accion: _textoSeguro(json['accion']),
      fecha: _fechaDesdeFirestore(json['fecha']) ?? DateTime.now(),
      usuarioId: _textoSeguro(json['usuarioId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'accion': accion, 'fecha': fecha, 'usuarioId': usuarioId};
  }
}
