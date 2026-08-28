import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/compra_model.dart';
import '../models/proyecto_model.dart';
import '../services/ventas_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_ventas_screen.dart';
import 'proyecto_detalle_admin_screen.dart';

class ClienteDetalleScreen extends StatefulWidget {
  final ClienteModel cliente;
  const ClienteDetalleScreen({Key? key, required this.cliente}) : super(key: key);

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  final VentasService _ventasService = VentasService();

  // Función para obtener TODO el historial unificado (Compras + Proyectos)
  Future<List<Map<String, dynamic>>> _obtenerHistorialCompleto() async {
    final db = FirebaseFirestore.instance;
    List<Map<String, dynamic>> historial = [];

    // 1. Obtener Compras
    final comprasSnap = await db.collection('compras').where('id_cliente', isEqualTo: widget.cliente.id).get();
    for (var doc in comprasSnap.docs) {
      historial.add({
        'id_documento': doc.id,
        'tipo': 'compra',
        'fecha': (doc.data()['fecha_compra'] as Timestamp).toDate(),
        'monto': (doc.data()['monto_total'] as num).toDouble(),
        'data': CompraModel.fromJson(doc.id, doc.data())
      });
    }

    // 2. Obtener Proyectos Finalizados
    final proySnap = await db.collection('proyectos')
        .where('id_cliente', isEqualTo: widget.cliente.id)
        .where('estatus', isEqualTo: 'finalizado')
        .get();

    for (var doc in proySnap.docs) {
      var finanzas = await doc.reference.collection('finanzas').doc('datos_pago').get();
      double montoPagado = finanzas.exists ? (finanzas.data()?['monto_pagado'] ?? 0.0).toDouble() : 0.0;
      
      historial.add({
        'tipo': 'proyecto',
        'fecha': (doc.data()['fecha_entrega'] as Timestamp).toDate(),
        'monto': montoPagado,
        'data': Proyecto.fromFirestore(doc)
      });
    }

    // Ordenar todo por fecha descendente
    historial.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));
    return historial;
  }

  // --- OPERACIONES DEL CRUD PARA COMPRAS ---

  // Eliminar compra devolviendo el stock de vuelta al inventario de insumos
  Future<void> _eliminarCompra(CompraModel compra) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Regresar las cantidades al inventario original de manera atómica
    for (var prod in compra.productosExtra) {
      final String? idProd = prod['id_producto'];
      final int cant = prod['cantidad'] ?? 0;

      if (idProd != null && idProd.isNotEmpty) {
        final refInsumo = db.collection('insumos_inventario').doc(idProd);
        batch.update(refInsumo, {'cantidad_disponible': FieldValue.increment(cant)});
      }
    }

    // 2. Eliminar el registro de la compra
    batch.delete(db.collection('compras').doc(compra.id));

    await batch.commit();
    setState(() {}); // Refrescar UI inmediatamente
  }

  // Cuadro de diálogo rápido para editar campos básicos de la compra (Monto/Precio)
  void _mostrarEditarCompraModal(CompraModel compra) {
    final controllerMonto = TextEditingController(text: compra.montoTotal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("EDITAR TOTAL VENTA", style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controllerMonto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Monto Total (\$)",
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFFDE21)), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              double nuevoMonto = double.tryParse(controllerMonto.text) ?? compra.montoTotal;
              await FirebaseFirestore.instance.collection('compras').doc(compra.id).update({
                'monto_total': nuevoMonto,
              });
              Navigator.pop(context);
              setState(() {}); // Forzar recarga del FutureBuilder
            },
            child: const Text("ACTUALIZAR", style: TextStyle(color: Color(0xFFFFDE21), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text("DETALLE CLIENTE", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFDE21),
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => AdminVentasScreen(cliente: widget.cliente))
        ).then((_) => setState(() {})),
        child: const Icon(Icons.add_shopping_cart, color: Colors.black),
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(alignment: Alignment.centerLeft, child: Text("HISTORIAL GENERAL", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _obtenerHistorialCompleto(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                if (snapshot.data!.isEmpty) return Center(child: Text("Sin registros", style: GoogleFonts.inter(color: Colors.white24)));
                
                final historial = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: historial.length,
                  itemBuilder: (context, index) => _buildItemCard(historial[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    bool esCompra = item['tipo'] == 'compra';
    var data = item['data'];

    if (esCompra) {
      return _buildCompraCard(data as CompraModel);
    } else {
      return _buildProyectoCard(data as Proyecto, item['monto']);
    }
  }

  Widget _buildProyectoCard(Proyecto proyecto, double monto) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProyectoDetalleAdminScreen(proyecto: proyecto)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Proyecto: ${proyecto.titulo}", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Row(
                  children: [
                    Text("\$${monto.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy').format(proyecto.fechaEntrega), style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompraCard(CompraModel compra) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Compra Extra", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yyyy').format(compra.fechaCompra), style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ]),
              Row(
                children: [
                  Text("\$${compra.montoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: const Color(0xFFFFDE21), fontWeight: FontWeight.bold, fontSize: 16)),
                  
                  // MENÚ DESPLEGABLE CON OPERACIONES CRUD CORREGIDO A POPUPMENUITEM
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                    color: const Color(0xFF262626),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _mostrarEditarCompraModal(compra);
                      } else if (action == 'delete') {
                        _confirmarEliminarCompraDialog(compra);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit', 
                        child: Row(children: [Icon(Icons.edit_outlined, color: Colors.cyan, size: 18), SizedBox(width: 8), Text("Editar total", style: TextStyle(color: Colors.white))])
                      ),
                      const PopupMenuItem(
                        value: 'delete', 
                        child: Row(children: [Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text("Eliminar venta", style: TextStyle(color: Colors.white))])
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
          if (compra.productosExtra.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            ...compra.productosExtra.map((prod) => Text("${prod['nombre_producto']} (x${prod['cantidad']})", style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ],
        ],
      ),
    );
  }

  void _confirmarEliminarCompraDialog(CompraModel compra) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("¿ELIMINAR ESTA COMPRA?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Esta acción es permanente e incrementará automáticamente las cantidades de vuelta al stock de insumos.", style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarCompra(compra);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFF8B5CF6), child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(child: Text(widget.cliente.nombre, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 20),
          _infoRow(Icons.phone_outlined, widget.cliente.telefono, onTap: () => _hacerLlamada(widget.cliente.telefono)),
          const SizedBox(height: 8),
          _infoRow(Icons.location_on_outlined, widget.cliente.direccion),
        ],
      ),
    );
  }

  Future<void> _hacerLlamada(String telefono) async {
    final Uri url = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: onTap != null ? const Color(0xFF64B5F6) : Colors.white38),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: onTap != null ? const Color(0xFF64B5F6) : Colors.white70, fontSize: 14))),
        ]),
      ),
    );
  }
}