import 'package:cloud_firestore/cloud_firestore.dart';

class SolicitudHerramientaModel {
  String id;
  String proyectoId;
  String? proyectoNombre; 
  String trabajadorId;
  String trabajadorNombre;
  String insumoId;
  String nombreInsumo;
  int cantidad;
  bool esRetornable;
  String estatus; 
  bool marcadoDevueltoTrabajador;
  bool devueltoConfirmadoAdmin;
  DateTime fechaSolicitud;
  DateTime? fechaAprobacion;
  DateTime? fechaLimiteDevolucion;
  
  // Nuevos campos para el reporte de devolución
  bool tieneReporteFalla;
  String? observacionesDevolucion;
  String? fotoDevolucionUrl;
  DateTime? fechaMarcadoDevuelto;

  SolicitudHerramientaModel({
    required this.id,
    required this.proyectoId,
    this.proyectoNombre, 
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.insumoId,
    required this.nombreInsumo,
    required this.cantidad,
    required this.esRetornable,
    this.estatus = 'pendiente',
    this.marcadoDevueltoTrabajador = false,
    this.devueltoConfirmadoAdmin = false,
    required this.fechaSolicitud,
    this.fechaAprobacion,
    this.fechaLimiteDevolucion,
    this.tieneReporteFalla = false,
    this.observacionesDevolucion,
    this.fotoDevolucionUrl,
    this.fechaMarcadoDevuelto,
  });

  factory SolicitudHerramientaModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // FIX: Manejamos ambas posibilidades (con mayúscula y minúscula) para evitar crashes
    Timestamp? timestampSolicitud = data['fechaSolicitud'] ?? data['FechaSolicitud'];

    return SolicitudHerramientaModel(
      id: doc.id,
      proyectoId: data['proyectoId'] ?? '',
      proyectoNombre: data['proyectoNombre'] ?? 'General', // <--- NUEVO CAMPO (Lectura desde Firebase)
      trabajadorId: data['trabajadorId'] ?? '',
      trabajadorNombre: data['trabajadorNombre'] ?? '',
      insumoId: data['insumoId'] ?? '',
      nombreInsumo: data['nombreInsumo'] ?? '',
      cantidad: data['cantidad'] ?? 1,
      esRetornable: data['esRetornable'] ?? false,
      estatus: data['estatus'] ?? 'pendiente',
      marcadoDevueltoTrabajador: data['marcadoDevueltoTrabajador'] ?? false,
      devueltoConfirmadoAdmin: data['devueltoConfirmadoAdmin'] ?? false,
      
      fechaSolicitud: timestampSolicitud != null ? timestampSolicitud.toDate() : DateTime.now(),
      
      fechaAprobacion: data['fechaAprobacion'] != null ? (data['fechaAprobacion'] as Timestamp).toDate() : null,
      fechaLimiteDevolucion: data['fechaLimiteDevolucion'] != null ? (data['fechaLimiteDevolucion'] as Timestamp).toDate() : null,
      
      tieneReporteFalla: data['tieneReporteFalla'] ?? false,
      observacionesDevolucion: data['observacionesDevolucion'],
      fotoDevolucionUrl: data['fotoDevolucionUrl'],
      fechaMarcadoDevuelto: data['fechaMarcadoDevuelto'] != null ? (data['fechaMarcadoDevuelto'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'proyectoId': proyectoId,
      'proyectoNombre': proyectoNombre, // <--- NUEVO CAMPO (Escritura a Firebase)
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'insumoId': insumoId,
      'nombreInsumo': nombreInsumo,
      'cantidad': cantidad,
      'esRetornable': esRetornable,
      'estatus': estatus,
      'marcadoDevueltoTrabajador': marcadoDevueltoTrabajador,
      'devueltoConfirmadoAdmin': devueltoConfirmadoAdmin,
      'fechaSolicitud': Timestamp.fromDate(fechaSolicitud),
      'fechaAprobacion': fechaAprobacion != null ? Timestamp.fromDate(fechaAprobacion!) : null,
      'fechaLimiteDevolucion': fechaLimiteDevolucion != null ? Timestamp.fromDate(fechaLimiteDevolucion!) : null,
      
      'tieneReporteFalla': tieneReporteFalla,
      'observacionesDevolucion': observacionesDevolucion,
      'fotoDevolucionUrl': fotoDevolucionUrl,
      'fechaMarcadoDevuelto': fechaMarcadoDevuelto != null ? Timestamp.fromDate(fechaMarcadoDevuelto!) : null,
    };
  }
}