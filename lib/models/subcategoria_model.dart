import 'package:cloud_firestore/cloud_firestore.dart';

class SubcategoriaInventario {
  final String id;
  final String nombre;

  SubcategoriaInventario({required this.id, required this.nombre});

  factory SubcategoriaInventario.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SubcategoriaInventario(id: doc.id, nombre: data['nombre'] ?? '');
  }

  Map<String, dynamic> toFirestore() => {'nombre': nombre};
}