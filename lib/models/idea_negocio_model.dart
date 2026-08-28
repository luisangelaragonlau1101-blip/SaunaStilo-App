import 'package:cloud_firestore/cloud_firestore.dart';

class IdeaNegocioModel {
  final String id;
  final String titulo;
  final String descripcion;
  final String estatus; // 'planeacion', 'desarrollo', 'completado'
  final DateTime fechaCreacion;
  final List<TareaIdeaModel> tareas;

  IdeaNegocioModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estatus,
    required this.fechaCreacion,
    required this.tareas,
  });

  // Convertir de Firestore (Map) a Objeto Dart
  factory IdeaNegocioModel.fromJson(Map<String, dynamic> json, String docId) {
    var listaTareas = json['tareas'] as List? ?? [];
    return IdeaNegocioModel(
      id: docId,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      estatus: json['estatus'] ?? 'planeacion',
      fechaCreacion: (json['fechaCreacion'] as Timestamp).toDate(),
      tareas: listaTareas.map((t) => TareaIdeaModel.fromMap(t)).toList(),
    );
  }

  // Convertir de Objeto Dart a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'estatus': estatus,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'tareas': tareas.map((t) => t.toMap()).toList(),
    };
  }
}

class TareaIdeaModel {
  final String titulo;
  final String asignadoId;
  final String asignadoNombre;
  final DateTime fechaTermino;
  final String estatus;

  TareaIdeaModel({
    required this.titulo,
    required this.asignadoId,
    required this.asignadoNombre,
    required this.fechaTermino,
    required this.estatus,
  });

  factory TareaIdeaModel.fromMap(Map<String, dynamic> map) {
    return TareaIdeaModel(
      titulo: map['titulo'] ?? '',
      asignadoId: map['asignadoId'] ?? '',
      asignadoNombre: map['asignadoNombre'] ?? '',
      fechaTermino: (map['fechaTermino'] as Timestamp).toDate(),
      estatus: map['estatus'] ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'asignadoId': asignadoId,
      'asignadoNombre': asignadoNombre,
      'fechaTermino': Timestamp.fromDate(fechaTermino),
      'estatus': estatus,
    };
  }
}