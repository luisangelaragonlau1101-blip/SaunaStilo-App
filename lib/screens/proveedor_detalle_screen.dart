import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/proveedor_model.dart';
import '../models/compra_insumo_model.dart';
import '../services/inventario_service.dart';
import 'form_pedido_insumo_screen.dart';
import 'editar_pedido_insumos_screen.dart';
import 'detalle_pedido_screen.dart';

class ProveedorDetalleScreen extends StatefulWidget {
  final Proveedor proveedor;
  const ProveedorDetalleScreen({Key? key, required this.proveedor}) : super(key: key);

  @override
  State<ProveedorDetalleScreen> createState() => _ProveedorDetalleScreenState();
}

class _ProveedorDetalleScreenState extends State<ProveedorDetalleScreen> {

  Future<List<Map<String, dynamic>>> _obtenerHistorialCompras() async {
    final db = FirebaseFirestore.instance;
    List<Map<String, dynamic>> historial = [];

    final comprasSnap = await db
        .collection('compras_insumos')
        .where('proveedor_id', isEqualTo: widget.proveedor.id)
        .get();

    for (var doc in comprasSnap.docs) {
      final data = doc.data();
      historial.add({
        'id_documento': doc.id,
        'fecha': (data['fecha_solicitud'] as Timestamp).toDate(),
        'total': (data['total_compra'] as num?)?.toDouble() ?? 0.0,
        'status': data['status_pedido'] ?? 'desconocido',
        'cantidad': data['cantidad_solicitada'] ?? 'N/A',
        'data': data,
      });
    }

    historial.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));
    return historial;
  }

  // --- FUNCIÓN AUXILIAR PARA MAPEAR EL MODELO ---
 CompraInsumoModel _obtenerModeloDesdeItem(Map<String, dynamic> item) {
    final data = item['data'];
    return CompraInsumoModel(
      id: item['id_documento'],
      proveedorId: data['proveedor_id'] ?? '',
      insumoId: data['insumo_id'] ?? '',
      cantidadSolicitada: (data['cantidad_solicitada'] ?? 0).toDouble(),
      cotizacion: (data['cotizacion'] ?? 0).toDouble(),
      costoFlete: (data['costo_flete'] ?? 0).toDouble(),
      totalCompra: (data['total_compra'] ?? 0).toDouble(),
      statusPedido: data['status_pedido'] ?? 'pendiente',
      folioFactura: data['folio_factura'] ?? '',
      observaciones: data['observaciones'] ?? '',
      fechaSolicitud: (data['fecha_solicitud'] as Timestamp).toDate(),
      fechaEntregaPrevista: data['fecha_entrega_prevista'] != null
          ? (data['fecha_entrega_prevista'] as Timestamp).toDate()
          : null,
      // AÑADIDO: Mapeo de la fecha de entrega final
      fechaEntregaFinal: data['fecha_entrega_final'] != null
          ? (data['fecha_entrega_final'] as Timestamp).toDate()
          : null,
    );
  }

  // --- NAVEGACIÓN A EDICIÓN ---
  void _abrirEdicionPedido(Map<String, dynamic> item) {
    final pedidoSeleccionado = _obtenerModeloDesdeItem(item);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditarPedidoScreen(pedido: pedidoSeleccionado)),
    ).then((_) {
      setState(() {});
    });
  }


  void _abrirDetallePedido(Map<String, dynamic> item) {
    final pedidoSeleccionado = _obtenerModeloDesdeItem(item);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetallePedidoScreen(pedido: pedidoSeleccionado)),
    );
  }

  void _confirmarEliminarCompraDialog(String idDocumento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Text("¿ELIMINAR ESTE PEDIDO?", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text("Esta acción es permanente y eliminará el registro de la base de datos.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCELAR", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('compras_insumos').doc(idDocumento).delete();
              setState(() {});
            },
            child: Text("ELIMINAR", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _confirmarCompletarPedido(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Text("¿MARCAR COMO RECIBIDO?", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          "El pedido cambiará a 'completado' y se sumarán automáticamente ${item['cantidad']} al inventario del insumo.",
          style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 14)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF81C784)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await InventarioService().completarPedidoInsumo(
                  item['id_documento'],
                  item['data']['insumo_id'],
                  (item['data']['cantidad_solicitada'] ?? 0).toDouble()
                );
                setState(() {});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Inventario actualizado con éxito'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text("CONFIRMAR", style: GoogleFonts.inter(color: StiloColors.background, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: StiloColors.text),
        title: Text(
          "DETALLE PROVEEDOR",
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: StiloColors.text)
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF3B82F6),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormPedidoInsumoScreen(proveedor: widget.proveedor)
            )
          ).then((_) {
            setState(() {});
          });
        },
        child: Icon(Icons.add_shopping_cart, color: StiloColors.text),
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "HISTORIAL DE PEDIDOS",
                style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)
              )
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _obtenerHistorialCompras(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("Sin registros de compras", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .24))));
                }

                final historial = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: historial.length,
                  itemBuilder: (context, index) => _buildCompraCard(historial[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StiloColors.text.withValues(alpha: .12))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF3B82F6),
                child: Icon(Icons.business, color: StiloColors.text)
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.proveedor.nombreEmpresa,
                      style: GoogleFonts.inter(color: StiloColors.text, fontSize: 18, fontWeight: FontWeight.w600)
                    ),
                    Text(
                      "Contacto: ${widget.proveedor.encargadoNegocio}",
                      style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13)
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _infoRow(Icons.phone_outlined, widget.proveedor.telefonoEmpresa, onTap: () => _hacerLlamada(widget.proveedor.telefonoEmpresa)),
          if (widget.proveedor.telefonoPersonal.isNotEmpty) ...[
            SizedBox(height: 8),
            _infoRow(Icons.smartphone_outlined, widget.proveedor.telefonoPersonal, onTap: () => _hacerLlamada(widget.proveedor.telefonoPersonal)),
          ],
          SizedBox(height: 8),
          _infoRow(Icons.location_on_outlined, widget.proveedor.ubicacion),
        ],
      ),
    );
  }

  Widget _buildCompraCard(Map<String, dynamic> item) {
    Color statusColor;
    String statusStr = item['status'].toString().toLowerCase();

    if (statusStr == 'pendiente') {
      statusColor = Color(0xFFFFB74D);
    } else if (statusStr == 'entregado' || statusStr == 'completado') {
      statusColor = Color(0xFF81C784);
    } else if (statusStr == 'cancelado') {
      statusColor = Color(0xFFE57373);
    } else {
      statusColor = StiloColors.text.withValues(alpha: .54);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StiloColors.text.withValues(alpha: .12))
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // 2. AHORA AL TOCAR SE ABREN LOS DETALLES
          onTap: () => _abrirDetallePedido(item),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pedido de Insumo",
                        style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold)
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(item['fecha']),
                        style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11)
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.5))
                        ),
                        child: Text(
                          item['status'].toString().toUpperCase(),
                          style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ]
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "\$${item['total'].toStringAsFixed(2)}",
                      style: GoogleFonts.inter(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Cant: ${item['cantidad']}",
                      style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)
                    ),

                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: StiloColors.text.withValues(alpha: .54), size: 20),
                      color: StiloColors.surface,
                      onSelected: (action) {
                        if (action == 'edit') {
                          _abrirEdicionPedido(item); // AQUÍ SIGUE LA EDICIÓN
                        } else if (action == 'delete') {
                          _confirmarEliminarCompraDialog(item['id_documento']);
                        } else if (action == 'complete') {
                          _confirmarCompletarPedido(item);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: StiloColors.text, size: 18),
                              SizedBox(width: 8),
                              Text("Editar pedido", style: TextStyle(color: StiloColors.text))
                            ]
                          )
                        ),
                        if (statusStr == 'pendiente')
                          PopupMenuItem(
                            value: 'complete',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF81C784), size: 18),
                                SizedBox(width: 8),
                                Text("Marcar recibido", style: GoogleFonts.inter(color: StiloColors.text))
                              ]
                            )
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text("Eliminar registro", style: TextStyle(color: StiloColors.text))
                            ]
                          )
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _hacerLlamada(String telefono) async {
    final limpio = telefono.replaceAll(' ', '');
    final Uri url = Uri(scheme: 'tel', path: limpio);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
