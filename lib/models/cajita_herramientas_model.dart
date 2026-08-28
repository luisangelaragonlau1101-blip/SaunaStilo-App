import 'package:cloud_firestore/cloud_firestore.dart';

class CajitaHerramientaModel {
  final String id;
  final String herramientaBaseId;
  final String nombre;
  final String categoria;
  
  // Términos genéricos para que funcione con maestros y trabajadores
  final String responsableId; 
  final String? responsableNombre; 
  
  final String estado; 
  final DateTime? fechaEntrega;
  final String? propietarioOriginalId;
  final String? propietarioOriginalNombre; 

  // Getters para no romper tus otras pantallas. 
  // Nota: Ya tiene el String? corregido para evitar el error del compilador.
  String get trabajadorActualId => responsableId;
  String? get trabajadorActualNombre => responsableNombre;

  CajitaHerramientaModel({
    required this.id,
    required this.herramientaBaseId,
    required this.nombre,
    required this.categoria,
    required this.responsableId, 
    this.responsableNombre,      
    required this.estado,
    this.fechaEntrega,
    this.propietarioOriginalId,
    this.propietarioOriginalNombre,
  });

  factory CajitaHerramientaModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CajitaHerramientaModel(
      id: documentId,
      herramientaBaseId: data['herramienta_base_id'] ?? '',
      nombre: data['nombre'] ?? '',
      categoria: data['categoria'] ?? '',
      // Mapeamos las llaves viejas de Firebase a las variables genéricas
      responsableId: data['trabajador_actual_id'] ?? '',
      responsableNombre: data['trabajador_actual_nombre'], 
      estado: data['estado'] ?? 'asignado',
      fechaEntrega: data['fecha_entrega'] != null 
          ? (data['fecha_entrega'] as Timestamp).toDate() 
          : null,
      propietarioOriginalId: data['propietario_original_id'],
      propietarioOriginalNombre: data['propietario_original_nombre'], 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'herramienta_base_id': herramientaBaseId,
      'nombre': nombre,
      'categoria': categoria,
      // Guardamos con las llaves viejas para no afectar la base de datos
      'trabajador_actual_id': responsableId,
      'trabajador_actual_nombre': responsableNombre, 
      'estado': estado,
      'fecha_entrega': fechaEntrega != null ? Timestamp.fromDate(fechaEntrega!) : null,
      'propietario_original_id': propietarioOriginalId,
      'propietario_original_nombre': propietarioOriginalNombre, 
    };
  }

  CajitaHerramientaModel copyWith({
    String? id,
    String? herramientaBaseId,
    String? nombre,
    String? categoria,
    String? responsableId, 
    String? responsableNombre, 
    String? estado,
    DateTime? fechaEntrega,
    String? propietarioOriginalId,
    String? propietarioOriginalNombre,
  }) {
    return CajitaHerramientaModel(
      id: id ?? this.id,
      herramientaBaseId: herramientaBaseId ?? this.herramientaBaseId,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      responsableId: responsableId ?? this.responsableId,
      responsableNombre: responsableNombre ?? this.responsableNombre,
      estado: estado ?? this.estado,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      propietarioOriginalId: propietarioOriginalId ?? this.propietarioOriginalId,
      propietarioOriginalNombre: propietarioOriginalNombre ?? this.propietarioOriginalNombre,
    );
  }
}