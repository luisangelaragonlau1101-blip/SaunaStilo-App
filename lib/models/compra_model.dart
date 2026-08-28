import 'package:cloud_firestore/cloud_firestore.dart';

class CompraModel {
  final String id;
  final String idCliente;
  final List<Map<String, dynamic>> productosExtra;
  final double montoTotal;
  final DateTime fechaCompra;

  CompraModel({
    required this.id,
    required this.idCliente,
    required this.productosExtra,
    required this.montoTotal,
    required this.fechaCompra,
  });

  factory CompraModel.fromJson(String id, Map<String, dynamic> json) {
    List<Map<String, dynamic>> productos = [];
    var rawData = json['productos_extra'];
    
    if (rawData is List) {
      productos = List<Map<String, dynamic>>.from(rawData);
    } else if (rawData is Map) {
      productos = [Map<String, dynamic>.from(rawData)];
    }

    return CompraModel(
      id: id,
      idCliente: json['id_cliente'] ?? '',
      productosExtra: productos,
      montoTotal: (json['monto_total'] as num).toDouble(),
      fechaCompra: (json['fecha_compra'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'productos_extra': productosExtra,
      'monto_total': montoTotal,
      'fecha_compra': Timestamp.fromDate(fechaCompra),
    };
  }
}