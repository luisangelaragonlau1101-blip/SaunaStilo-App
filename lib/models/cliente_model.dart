import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteModel {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final DateTime fechaRegistro;

  ClienteModel({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.fechaRegistro,
  });

 factory ClienteModel.fromJson(String id, Map<String, dynamic> json) {
  return ClienteModel(
    id: id,
    nombre: json['nombre'] ?? '', 
    telefono: json['telefono'] ?? '',
    direccion: json['direccion'] ?? '',
    fechaRegistro: (json['fecha_registro'] as Timestamp).toDate(),
  );
}

  // Convertir de Objeto Dart a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
    };
  }
}