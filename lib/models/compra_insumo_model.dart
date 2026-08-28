import 'package:cloud_firestore/cloud_firestore.dart';

class CompraInsumoModel {
  final String id;
  final String proveedorId;
  final String insumoId;
  final double cantidadSolicitada;
  final double cotizacion;
  final double costoFlete;
  final double totalCompra;
  final String statusPedido;
  final String folioFactura;
  final String observaciones;
  final DateTime fechaSolicitud;
  final DateTime? fechaEntregaPrevista;
  final DateTime? fechaEntregaFinal;

  CompraInsumoModel({
    required this.id,
    required this.proveedorId,
    required this.insumoId,
    required this.cantidadSolicitada,
    required this.cotizacion,
    required this.costoFlete,
    required this.totalCompra,
    required this.statusPedido,
    required this.folioFactura,
    required this.observaciones,
    required this.fechaSolicitud,
    this.fechaEntregaPrevista,
    this.fechaEntregaFinal,
  });

  factory CompraInsumoModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return CompraInsumoModel(
      id: doc.id,
      proveedorId: data['proveedor_id'] ?? '',
      insumoId: data['insumo_id'] ?? '',
      cantidadSolicitada: data['cantidad_solicitada'] ?? '',
      cotizacion: (data['cotizacion'] ?? 0).toDouble(),
      costoFlete: (data['costo_flete'] ?? 0).toDouble(),
      totalCompra: (data['total_compra'] ?? 0).toDouble(),
      statusPedido: data['status_pedido'] ?? 'pendiente',
      folioFactura: data['folio_factura'] ?? '',
      observaciones: data['observaciones'] ?? '',
      // Manejo seguro de fechas (Timestamp a DateTime)
      fechaSolicitud: data['fecha_solicitud'] != null 
          ? (data['fecha_solicitud'] as Timestamp).toDate() 
          : DateTime.now(),
      fechaEntregaPrevista: data['fecha_entrega_prevista'] != null 
          ? (data['fecha_entrega_prevista'] as Timestamp).toDate() 
          : null,
      fechaEntregaFinal: data['fecha_entrega_final'] != null 
          ? (data['fecha_entrega_final'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'proveedor_id': proveedorId,
      'insumo_id': insumoId,
      'cantidad_solicitada': cantidadSolicitada,
      'cotizacion': cotizacion,
      'costo_flete': costoFlete,
      'total_compra': totalCompra,
      'status_pedido': statusPedido,
      'folio_factura': folioFactura,
      'observaciones': observaciones,
      // Conversión de DateTime a Timestamp para Firestore
      'fecha_solicitud': Timestamp.fromDate(fechaSolicitud),
      'fecha_entrega_prevista': fechaEntregaPrevista != null 
          ? Timestamp.fromDate(fechaEntregaPrevista!) 
          : null,
      'fecha_entrega_final': fechaEntregaFinal != null 
          ? Timestamp.fromDate(fechaEntregaFinal!) 
          : null,
    };
  }
}