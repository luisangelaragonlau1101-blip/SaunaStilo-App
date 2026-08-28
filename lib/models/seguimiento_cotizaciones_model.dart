import 'package:cloud_firestore/cloud_firestore.dart';

class SeguimientoCotizacionModel {
  final String id;
  final String adminEncargado;
  final bool clienteEsNuevo;
  final String idCliente;
  final String estatusCotizacion;
  final DateTime fechaCotizacion;
  final double montoCotizado;
  final DatosCliente datosCliente;
  final DatosProyecto datosProyecto;
  final List<NotaSeguimiento> notasSeguimiento;

  SeguimientoCotizacionModel({
    required this.id,
    required this.adminEncargado,
    required this.clienteEsNuevo,
    required this.idCliente,
    required this.estatusCotizacion,
    required this.fechaCotizacion,
    required this.montoCotizado,
    required this.datosCliente,
    required this.datosProyecto,
    required this.notasSeguimiento,
  });

  // Mapeo de Firestore a Dart
  factory SeguimientoCotizacionModel.fromJson(Map<String, dynamic> json, String docId) {
    List<NotaSeguimiento> notasProcesadas = [];
    if (json['notas_seguimiento'] != null) {
      for (var item in json['notas_seguimiento']) {
        if (item is String) {
          notasProcesadas.add(NotaSeguimiento(
            fecha: DateTime.now(), 
            comentario: item,
            completada: false, 
            creadaPor: 'Sin asignar', // 👈 Nuevo campo en notas viejas
          ));
        } else if (item is Map) {
          notasProcesadas.add(NotaSeguimiento.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SeguimientoCotizacionModel(
      id: docId,
      adminEncargado: (json['admin_encargado'] as String? ?? '').trim(),
      clienteEsNuevo: json['cliente_es_nuevo'] as bool? ?? true,
      idCliente: json['id_cliente'] as String? ?? '',
      estatusCotizacion: json['estatus_cotizacion'] as String? ?? 'PENDIENTE',
      fechaCotizacion: (json['fecha_cotizacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      montoCotizado: (json['monto_cotizado'] as num?)?.toDouble() ?? 0.0,
      datosCliente: DatosCliente.fromJson(
        Map<String, dynamic>.from(json['datos_cliente'] as Map? ?? {})
      ),
      datosProyecto: DatosProyecto.fromJson(
        Map<String, dynamic>.from(json['datos_proyecto'] as Map? ?? {})
      ),
      notasSeguimiento: notasProcesadas,
    );
  }

  // Mapeo de Dart a Firestore
  Map<String, dynamic> toJson() {
    return {
      'admin_encargado': adminEncargado.trim(),
      'cliente_es_nuevo': clienteEsNuevo,
      'id_cliente': idCliente,
      'estatus_cotizacion': estatusCotizacion,
      'fecha_cotizacion': Timestamp.fromDate(fechaCotizacion),
      'monto_cotizado': montoCotizado,
      'datos_cliente': datosCliente.toJson(),
      'datos_proyecto': datosProyecto.toJson(),
      'notas_seguimiento': notasSeguimiento.map((item) => item.toJson()).toList(),
    };
  }
}

class DatosCliente {
  final String nombre;
  final String telefono;
  final String direccion;

  DatosCliente({required this.nombre, required this.telefono, required this.direccion});

  factory DatosCliente.fromJson(Map<String, dynamic> json) {
    return DatosCliente(
      nombre: json['nombre'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      direccion: json['direccion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'telefono': telefono, 'direccion': direccion};
  }
}

class DatosProyecto {
  final String titulo;
  final String descripcion;
  final String idSauna;
  final String medidas;

  DatosProyecto({required this.titulo, required this.descripcion, required this.idSauna, required this.medidas});

  factory DatosProyecto.fromJson(Map<String, dynamic> json) {
    return DatosProyecto(
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      idSauna: (json['id_sauna'] as String? ?? '').trim(),
      medidas: json['medidas'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'titulo': titulo, 'descripcion': descripcion, 'id_sauna': idSauna.trim(), 'medidas': medidas};
  }
}

class NotaSeguimiento {
  final DateTime fecha;
  final String comentario;
  final bool completada; 
  final String creadaPor; // 👈 NUEVA PROPIEDAD

  NotaSeguimiento({
    required this.fecha,
    required this.comentario,
    this.completada = false, 
    this.creadaPor = 'Sin asignar', // 👈 VALOR POR DEFECTO
  });

  factory NotaSeguimiento.fromJson(Map<String, dynamic> json) {
    return NotaSeguimiento(
      fecha: (json['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      comentario: json['comentario'] as String? ?? '',
      completada: json['completada'] as bool? ?? false, 
      creadaPor: json['creada_por'] as String? ?? 'Sin asignar', // 👈 SE LEE DESDE FIREBASE
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': Timestamp.fromDate(fecha),
      'comentario': comentario,
      'completada': completada, 
      'creada_por': creadaPor, // 👈 SE GUARDA EN FIREBASE
    };
  }
}