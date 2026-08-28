import 'package:cloud_firestore/cloud_firestore.dart';

class Sauna {
  final String id;
  final String nombre;
  final String descripcion;
  final String imagenUrl;

  Sauna({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.imagenUrl,
  });

  factory Sauna.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Sauna(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      imagenUrl: data['imagen_url'] ?? '',
    );
  }
}