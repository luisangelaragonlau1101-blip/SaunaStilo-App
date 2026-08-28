import 'package:cloud_firestore/cloud_firestore.dart';

class ActividadModel {
  String id;
  String proyectoId;
  String titulo;
  String descripcion;
  String asignadoATrabajadorId; 
  DateTime fechaInicio;
  DateTime fechaTermino;
  String estatus; 
  String observacionesAdmin; 
  String comentariosTrabajador;
  List<String> evidenciaFotos;
  List<EventoActividad> historialEventos; 

  ActividadModel({
    required this.id,
    required this.proyectoId,
    required this.titulo,
    required this.descripcion,
    required this.asignadoATrabajadorId,
    required this.fechaInicio,
    required this.fechaTermino,
    this.estatus = 'pendiente',
    this.observacionesAdmin = '',
    this.comentariosTrabajador = '',
    this.evidenciaFotos = const [], 
    this.historialEventos = const [], 
  });

  factory ActividadModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ActividadModel(
      id: documentId,
      proyectoId: json['proyectoId'] ?? '',
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      asignadoATrabajadorId: json['asignadoATrabajadorId'] ?? '',
      fechaInicio: (json['fechaInicio'] as Timestamp).toDate(), 
      fechaTermino: (json['fechaTermino'] as Timestamp).toDate(),
      estatus: json['estatus'] ?? 'pendiente',
      observacionesAdmin: json['observacionesAdmin'] ?? '',
      comentariosTrabajador: json['comentariosTrabajador'] ?? '',
      evidenciaFotos: json['evidenciaFotos'] != null 
          ? List<String>.from(json['evidenciaFotos']) 
          : [],
      historialEventos: json['historialEventos'] != null 
          ? (json['historialEventos'] as List).map((item) => EventoActividad.fromJson(item)).toList()
          : [],
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
      'estatus': estatus,
      'observacionesAdmin': observacionesAdmin,
      'comentariosTrabajador': comentariosTrabajador,
      'evidenciaFotos': evidenciaFotos,
      'historialEventos': historialEventos.map((e) => e.toJson()).toList(), 
    };
  }
}

// Sub-modelo para el historial de eventos
class EventoActividad {
  String accion; // Ej: 'Estatus cambiado a En Progreso'
  DateTime fecha;
  String usuarioId;

  EventoActividad({
    required this.accion,
    required this.fecha,
    required this.usuarioId,
  });

  factory EventoActividad.fromJson(Map<String, dynamic> json) {
    return EventoActividad(
      accion: json['accion'] ?? '',
      fecha: json['fecha'] != null ? (json['fecha'] as Timestamp).toDate() : DateTime.now(),
      usuarioId: json['usuarioId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accion': accion,
      'fecha': fecha,
      'usuarioId': usuarioId,
    };
  }
}