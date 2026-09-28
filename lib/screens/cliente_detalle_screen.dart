import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
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
        backgroundColor: StiloColors.surface,
        title: Text("EDITAR TOTAL VENTA", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(contextMenuBuilder: privacyTextMenu,
          controller: controllerMonto,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: StiloColors.text),
          decoration: InputDecoration(
            labelText: "Monto Total (\$)",
            labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24)), borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFDE21)), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR", style: TextStyle(color: StiloColors.text.withValues(alpha: .54)))),
          TextButton(
            onPressed: () async {
              double nuevoMonto = double.tryParse(controllerMonto.text) ?? compra.montoTotal;
              await FirebaseFirestore.instance.collection('compras').doc(compra.id).update({
                'monto_total': nuevoMonto,
              });
              Navigator.pop(context);
              setState(() {}); // Forzar recarga del FutureBuilder
            },
            child: Text("ACTUALIZAR", style: TextStyle(color: Color(0xFFFFDE21), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text("DETALLE CLIENTE", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: StiloColors.text)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFFFDE21),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminVentasScreen(cliente: widget.cliente))
        ).then((_) => setState(() {})),
        child: Icon(Icons.add_shopping_cart, color: StiloColors.background),
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(alignment: Alignment.centerLeft, child: Text("HISTORIAL GENERAL", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _obtenerHistorialCompleto(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: StiloColors.accent));
                if (snapshot.data!.isEmpty) return Center(child: Text("Sin registros", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .24))));

                final historial = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
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
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Proyecto: ${proyecto.titulo}", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                Row(
                  children: [
                    Text("\$${monto.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, color: StiloColors.text.withValues(alpha: .30), size: 14),
                  ],
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy').format(proyecto.fechaEntrega), style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompraCard(CompraModel compra) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: StiloColors.text.withValues(alpha: .12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Compra Extra", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yyyy').format(compra.fechaCompra), style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11)),
              ]),
              Row(
                children: [
                  Text("\$${compra.montoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Color(0xFFFFDE21), fontWeight: FontWeight.bold, fontSize: 16)),

                  // MENÚ DESPLEGABLE CON OPERACIONES CRUD CORREGIDO A POPUPMENUITEM
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: StiloColors.text.withValues(alpha: .54), size: 20),
                    color: StiloColors.surface,
                    onSelected: (action) {
                      if (action == 'edit') {
                        _mostrarEditarCompraModal(compra);
                      } else if (action == 'delete') {
                        _confirmarEliminarCompraDialog(compra);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit_outlined, color: Colors.cyan, size: 18), SizedBox(width: 8), Text("Editar total", style: TextStyle(color: StiloColors.text))])
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text("Eliminar venta", style: TextStyle(color: StiloColors.text))])
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
          if (compra.productosExtra.isNotEmpty) ...[
            Divider(color: StiloColors.text.withValues(alpha: .10)),
            ...compra.productosExtra.map((prod) => Text("${prod['nombre_producto']} (x${prod['cantidad']})", style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 12))),
          ],
        ],
      ),
    );
  }

  void _confirmarEliminarCompraDialog(CompraModel compra) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Text("¿ELIMINAR ESTA COMPRA?", style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text("Esta acción es permanente e incrementará automáticamente las cantidades de vuelta al stock de insumos.", style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCELAR", style: TextStyle(color: StiloColors.text.withValues(alpha: .54)))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarCompra(compra);
            },
            child: Text("ELIMINAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: StiloColors.text.withValues(alpha: .12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(backgroundColor: StiloColors.accent, child: Icon(Icons.person, color: StiloColors.text)),
            SizedBox(width: 15),
            Expanded(child: Text(widget.cliente.nombre, style: GoogleFonts.inter(color: StiloColors.text, fontSize: 18, fontWeight: FontWeight.w600))),
          ]),
          SizedBox(height: 20),
          _infoRow(Icons.phone_outlined, widget.cliente.telefono, onTap: () => _hacerLlamada(widget.cliente.telefono)),
          SizedBox(height: 8),
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
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: onTap != null ? Color(0xFF64B5F6) : StiloColors.text.withValues(alpha: .38)),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: onTap != null ? Color(0xFF64B5F6) : StiloColors.text.withValues(alpha: .70), fontSize: 14))),
        ]),
      ),
    );
  }
}
