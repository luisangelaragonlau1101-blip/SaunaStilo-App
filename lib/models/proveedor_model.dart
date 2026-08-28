import 'package:cloud_firestore/cloud_firestore.dart';

class Proveedor {
  final String id;
  final String nombreEmpresa;
  final String encargadoNegocio;
  final String telefonoEmpresa;
  final String telefonoPersonal;
  final String ubicacion;

  Proveedor({
    required this.id,
    required this.nombreEmpresa,
    required this.encargadoNegocio,
    required this.telefonoEmpresa,
    required this.telefonoPersonal,
    required this.ubicacion,
  });

  factory Proveedor.fromMap(Map<String, dynamic> data, String documentId) {
    return Proveedor(
      id: documentId,
      nombreEmpresa: data['nombre_empresa'] ?? '',
      encargadoNegocio: data['encargado_negocio'] ?? '',
      telefonoEmpresa: data['telefono_empresa'] ?? '',
      telefonoPersonal: data['telefono_personal'] ?? '',
      ubicacion: data['ubicacion'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre_empresa': nombreEmpresa,
      'encargado_negocio': encargadoNegocio,
      'telefono_empresa': telefonoEmpresa,
      'telefono_personal': telefonoPersonal,
      'ubicacion': ubicacion,
    };
  }
}