import 'package:cloud_firestore/cloud_firestore.dart';

class AsistenciaModel {
  final String id;
  final String trabajadorId;
  final DateTime fecha; 
  final DateTime? horaEntrada;
  final DateTime? horaSalida;
  final String estatus;
  final bool ubicacionValida;
  final double latitudRegistro;
  final double longitudRegistro;

  // --- HORA DE COMIDA ---
  final DateTime? salidaComidaSolicitada;
  final DateTime? salidaComidaReal;
  final DateTime? regresoComidaReal;
  final String estatusComida; 
  final bool ubicacionRegresoComidaValida;

  // --- JUSTIFICACIÓN Y OBSERVACIONES ---
  final String? motivoFalta; 
  final String? evidenciaJustificacionUrl; 
  final String estatusJustificacion; 
  final String observacionesTrabajador; 
  final String observacionesAdmin; 

  // --- LISTAS DE BONOS Y MULTAS (NUEVO FORMATO MÚLTIPLE) ---
  final List<Map<String, dynamic>>? listaBonos;
  final List<Map<String, dynamic>>? listaMultas;
  
  final List<String>? historialModificaciones;

  AsistenciaModel({
    required this.id,
    required this.trabajadorId,
    required this.fecha,
    this.horaEntrada,
    this.horaSalida,
    required this.estatus,
    required this.ubicacionValida,
    required this.latitudRegistro,
    required this.longitudRegistro,
    this.salidaComidaSolicitada,
    this.salidaComidaReal,
    this.regresoComidaReal,
    this.estatusComida = 'ninguna',
    this.ubicacionRegresoComidaValida = false,
    this.motivoFalta,
    this.evidenciaJustificacionUrl,
    this.estatusJustificacion = 'ninguna',
    this.observacionesTrabajador = '',
    this.observacionesAdmin = '',
    this.historialModificaciones,
    this.listaBonos,
    this.listaMultas,
  });

  factory AsistenciaModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Lógica para transformar el antiguo registro único de bono a lista (por si tienes datos viejos)
    List<Map<String, dynamic>> parsedBonos = [];
    if (data['listaBonos'] != null) {
      parsedBonos = List<Map<String, dynamic>>.from(data['listaBonos'].map((x) => Map<String, dynamic>.from(x)));
    } else if (data['bono'] != null && (data['bono'] as num) > 0) {
      parsedBonos.add({'monto': (data['bono'] as num).toDouble(), 'motivo': data['motivoBono'] ?? 'Bono extra'});
    }

    // Lógica para transformar la antigua multa a lista
    List<Map<String, dynamic>> parsedMultas = [];
    if (data['listaMultas'] != null) {
      parsedMultas = List<Map<String, dynamic>>.from(data['listaMultas'].map((x) => Map<String, dynamic>.from(x)));
    } else if (data['multa'] != null && (data['multa'] as num) > 0) {
      parsedMultas.add({'monto': (data['multa'] as num).toDouble(), 'motivo': data['motivoMulta'] ?? 'Penalización'});
    }

    return AsistenciaModel(
      id: doc.id,
      trabajadorId: data['trabajadorId'] ?? '',
      fecha: data['fecha'] is Timestamp
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      horaEntrada: data['horaEntrada'] != null ? (data['horaEntrada'] as Timestamp).toDate() : null,
      horaSalida: data['horaSalida'] != null ? (data['horaSalida'] as Timestamp).toDate() : null,
      estatus: data['estatus'] ?? 'pendiente',
      ubicacionValida: data['ubicacionValida'] ?? false,
      latitudRegistro: (data['latitudRegistro'] ?? 0.0).toDouble(),
      longitudRegistro: (data['longitudRegistro'] ?? 0.0).toDouble(),
      salidaComidaSolicitada: data['salidaComidaSolicitada'] != null ? (data['salidaComidaSolicitada'] as Timestamp).toDate() : null,
      salidaComidaReal: data['salidaComidaReal'] != null ? (data['salidaComidaReal'] as Timestamp).toDate() : null,
      regresoComidaReal: data['regresoComidaReal'] != null ? (data['regresoComidaReal'] as Timestamp).toDate() : null,
      estatusComida: data['estatusComida'] ?? 'ninguna',
      ubicacionRegresoComidaValida: data['ubicacionRegresoComidaValida'] ?? false,
      motivoFalta: data['motivoFalta'],
      evidenciaJustificacionUrl: data['evidenciaJustificacionUrl'],
      estatusJustificacion:
          (data['estatusJustificacion'] == null ||
              data['estatusJustificacion'] == 'sin_enviar')
          ? 'ninguna'
          : data['estatusJustificacion'].toString(),
      observacionesTrabajador: data['observacionesTrabajador'] ?? '',
      observacionesAdmin: data['observacionesAdmin'] ?? '',

      historialModificaciones: data['historialModificaciones'] != null 
        ? List<String>.from(data['historialModificaciones']) 
        : [],

      listaBonos: parsedBonos,
      listaMultas: parsedMultas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trabajadorId': trabajadorId,
      'fecha': Timestamp.fromDate(fecha),
      'horaEntrada': horaEntrada != null ? Timestamp.fromDate(horaEntrada!) : null,
      'horaSalida': horaSalida != null ? Timestamp.fromDate(horaSalida!) : null,
      'estatus': estatus,
      'ubicacionValida': ubicacionValida,
      'latitudRegistro': latitudRegistro,
      'longitudRegistro': longitudRegistro,
      'salidaComidaSolicitada': salidaComidaSolicitada != null ? Timestamp.fromDate(salidaComidaSolicitada!) : null,
      'salidaComidaReal': salidaComidaReal != null ? Timestamp.fromDate(salidaComidaReal!) : null,
      'regresoComidaReal': regresoComidaReal != null ? Timestamp.fromDate(regresoComidaReal!) : null,
      'estatusComida': estatusComida,
      'ubicacionRegresoComidaValida': ubicacionRegresoComidaValida,
      'motivoFalta': motivoFalta,
      'evidenciaJustificacionUrl': evidenciaJustificacionUrl,
      'estatusJustificacion': estatusJustificacion,
      'observacionesTrabajador': observacionesTrabajador,
      'observacionesAdmin': observacionesAdmin,
      'historialModificaciones': historialModificaciones ?? [], 
      'listaBonos': listaBonos ?? [],
      'listaMultas': listaMultas ?? [],
    };
  }
}
