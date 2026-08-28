import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriaInventario {
  final String id;
  final String nombre;

  CategoriaInventario({required this.id, required this.nombre});

  factory CategoriaInventario.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CategoriaInventario(id: doc.id, nombre: data['nombre'] ?? '');
  }

  Map<String, dynamic> toFirestore() => {'nombre': nombre};
}