import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compra_insumo_model.dart';

class DetallePedidoScreen extends StatelessWidget {
  final CompraInsumoModel pedido;

  const DetallePedidoScreen({Key? key, required this.pedido}) : super(key: key);

  Future<String> _obtenerNombreInsumo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('insumos_inventario')
          .doc(pedido.insumoId)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['nombre'] ?? 'Insumo desconocido';
      }
      return 'Insumo no encontrado';
    } catch (e) {
      return 'Error al cargar insumo';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusStr = pedido.statusPedido.toLowerCase();
    
    if (statusStr == 'pendiente') {
      statusColor = const Color(0xFFFFB74D); 
    } else if (statusStr == 'entregado' || statusStr == 'completado') {
      statusColor = const Color(0xFF81C784); 
    } else if (statusStr == 'cancelado') {
      statusColor = const Color(0xFFE57373); 
    } else {
      statusColor = Colors.white54;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "RESUMEN DEL PEDIDO", 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ENCABEZADO DE ESTATUS ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5))
                    ),
                    child: Text(
                      pedido.statusPedido.toUpperCase(), 
                      style: GoogleFonts.inter(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "\$${pedido.totalCompra.toStringAsFixed(2)}", 
                    style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontSize: 32, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 4),
                  Text("Total del Pedido", style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- DETALLES DEL INSUMO ---
            Text("DETALLES DEL INSUMO", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  FutureBuilder<String>(
                    future: _obtenerNombreInsumo(),
                    builder: (context, snapshot) {
                      String nombre = "Cargando...";
                      if (snapshot.connectionState == ConnectionState.done) {
                        nombre = snapshot.data ?? "Insumo desconocido";
                      }
                      return _buildInfoRow("Insumo", nombre, isHighlight: true);
                    }
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow("Cantidad Solicitada", "${pedido.cantidadSolicitada}"),
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow("Cotización", "\$${pedido.cotizacion.toStringAsFixed(2)}"),
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow("Costo de Flete", "\$${pedido.costoFlete.toStringAsFixed(2)}"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- FECHAS Y FACTURA ---
            Text("LOGÍSTICA Y DOCUMENTACIÓN", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildInfoRow("Fecha de Solicitud", DateFormat('dd/MM/yyyy HH:mm').format(pedido.fechaSolicitud)),
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow(
                    "Entrega Prevista", 
                    pedido.fechaEntregaPrevista != null 
                        ? DateFormat('dd/MM/yyyy').format(pedido.fechaEntregaPrevista!) 
                        : "Sin fecha asignada"
                  ),
                  
                  // MODIFICADO: Bloque dinámico para mostrar la fecha de recepción real
                  if (statusStr == 'completado' && pedido.fechaEntregaFinal != null) ...[
                    const Divider(color: Colors.white12, height: 24),
                    _buildInfoRow(
                      "Fecha de Recepción", 
                      DateFormat('dd/MM/yyyy HH:mm').format(pedido.fechaEntregaFinal!),
                      isHighlight: true,
                    ),
                  ],
                  
                  const Divider(color: Colors.white12, height: 24),
                  _buildInfoRow("Folio Factura", pedido.folioFactura.isEmpty ? "No registrado" : pedido.folioFactura),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- OBSERVACIONES ---
            if (pedido.observaciones.isNotEmpty) ...[
              Text("OBSERVACIONES", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  pedido.observaciones,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 40),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: isHighlight ? const Color(0xFF81C784) : Colors.white70, 
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal
            )
          ),
        ),
      ],
    );
  }
}