import 'package:cloud_firestore/cloud_firestore.dart';

// --- CONSTANTES DE ROLES (¡NUEVO!) ---
// Úsalas en toda tu app en lugar de escribir los textos a mano.
class AppRoles {
  static const String admin = 'admin';
  static const String maestro = 'maestro';
  static const String trabajador = 'trabajador';
  static const String almacenista = 'almacenista';
}

class UserModel {
  final String id;
  final String nombre;
  final DateTime? cumpleanos;
  final String correo;
  final String rol; 
  final DateTime fechaRegistro;
  final String? fotoUrl;
  
  // --- CAMPOS DE HORARIO ---
  final String? horaEntrada;
  final String? horaSalida;
  final int? toleranciaMinutos;

  // --- NUEVOS CAMPOS PARA CÁLCULO DE SUELDO ---
  final double? sueldoBaseSemanal; 
  final bool? trabajaSabados; 

  UserModel({
    required this.id,
    required this.nombre,
    this.cumpleanos,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
    this.fotoUrl,
    this.horaEntrada,
    this.horaSalida,
    this.toleranciaMinutos,
    this.sueldoBaseSemanal,
    this.trabajaSabados = false, 
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      cumpleanos: data['cumpleanos'] != null ? (data['cumpleanos'] as Timestamp).toDate() : null,
      correo: data['correo'] ?? '',
      // Usamos la constante como valor por defecto
      rol: data['rol'] ?? AppRoles.trabajador, 
      fechaRegistro: data['fecha_registro'] != null 
          ? (data['fecha_registro'] as Timestamp).toDate() 
          : DateTime.now(),
      fotoUrl: data['fotoUrl'],
      
      horaEntrada: data['horaEntrada'],
      horaSalida: data['horaSalida'],
      toleranciaMinutos: data['toleranciaMinutos'] != null ? data['toleranciaMinutos'] as int : 11, 
      sueldoBaseSemanal: data['sueldoBaseSemanal'] != null ? (data['sueldoBaseSemanal'] as num).toDouble() : 0.0,
      trabajaSabados: data['trabajaSabados'] ?? false,
    ); 
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'cumpleanos': cumpleanos != null ? Timestamp.fromDate(cumpleanos!) : null,
      'correo': correo,
      'rol': rol,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
      'fotoUrl': fotoUrl,
      if (horaEntrada != null) 'horaEntrada': horaEntrada,
      if (horaSalida != null) 'horaSalida': horaSalida,
      if (toleranciaMinutos != null) 'toleranciaMinutos': toleranciaMinutos,
      if (sueldoBaseSemanal != null) 'sueldoBaseSemanal': sueldoBaseSemanal,
      if (trabajaSabados != null) 'trabajaSabados': trabajaSabados,
    };
  }
}