import 'package:cloud_firestore/cloud_firestore.dart';

class Proyecto {
  final String id;
  final String titulo;
  final String idSauna;
  final String idCliente;
  final String estatus; // pendiente, en_proceso, finalizado
  final DateTime fechaInicio;
  final DateTime fechaEntrega;
  final DateTime? fechaSalidaInstalacion; 
  final String medidas;
  final String descripcion;
  final List<dynamic> encargados; 

  Proyecto({
    required this.id,
    required this.titulo,   
    required this.idSauna,
    required this.idCliente,
    required this.estatus,
    required this.fechaInicio,
    required this.fechaEntrega,
    this.fechaSalidaInstalacion, 
    required this.medidas,
    required this.descripcion,
    required this.encargados,
  });

  factory Proyecto.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    var encargadosRaw = data['encargados'];
    List<dynamic> listaEncargados = [];
    
    if (encargadosRaw is List) {
      listaEncargados = encargadosRaw;
    } else if (encargadosRaw is String) {
      listaEncargados = [encargadosRaw];
    }

    return Proyecto(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      idSauna: data['id_sauna'] ?? '',
      idCliente: data['id_cliente'] ?? '',
      estatus: data['estatus'] ?? 'pendiente',
      fechaInicio: (data['fecha_inicio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaEntrega: (data['fecha_entrega'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaSalidaInstalacion: data['fecha_salida_instalacion'] != null 
          ? (data['fecha_salida_instalacion'] as Timestamp).toDate() 
          : null,
      medidas: data['medidas'] ?? '',
      descripcion: data['descripcion'] ?? '',
      encargados: listaEncargados,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'id_sauna': idSauna,
      'id_cliente': idCliente,
      'estatus': estatus,
      'fecha_inicio': Timestamp.fromDate(fechaInicio),
      'fecha_entrega': Timestamp.fromDate(fechaEntrega),
      'fecha_salida_instalacion': fechaSalidaInstalacion != null 
          ? Timestamp.fromDate(fechaSalidaInstalacion!) 
          : null,
      'medidas': medidas,
      'descripcion': descripcion,
      'encargados': encargados,
    };
  }
}