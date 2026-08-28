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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("¿ELIMINAR ESTE PEDIDO?", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text("Esta acción es permanente y eliminará el registro de la base de datos.", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCELAR", style: GoogleFonts.inter(color: Colors.white54))),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("¿MARCAR COMO RECIBIDO?", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          "El pedido cambiará a 'completado' y se sumarán automáticamente ${item['cantidad']} al inventario del insumo.", 
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("CANCELAR", style: GoogleFonts.inter(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81C784)), 
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
                    const SnackBar(content: Text('Inventario actualizado con éxito'), backgroundColor: Colors.green),
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
            child: Text("CONFIRMAR", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "DETALLE PROVEEDOR", 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6), 
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
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildInfoCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft, 
              child: Text(
                "HISTORIAL DE PEDIDOS", 
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)
              )
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _obtenerHistorialCompras(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("Sin registros de compras", style: GoogleFonts.inter(color: Colors.white24)));
                }
                
                final historial = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.white12)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF3B82F6), 
                child: Icon(Icons.business, color: Colors.white)
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.proveedor.nombreEmpresa, 
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)
                    ),
                    Text(
                      "Contacto: ${widget.proveedor.encargadoNegocio}", 
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(Icons.phone_outlined, widget.proveedor.telefonoEmpresa, onTap: () => _hacerLlamada(widget.proveedor.telefonoEmpresa)),
          if (widget.proveedor.telefonoPersonal.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.smartphone_outlined, widget.proveedor.telefonoPersonal, onTap: () => _hacerLlamada(widget.proveedor.telefonoPersonal)),
          ],
          const SizedBox(height: 8),
          _infoRow(Icons.location_on_outlined, widget.proveedor.ubicacion),
        ],
      ),
    );
  }

  Widget _buildCompraCard(Map<String, dynamic> item) {
    Color statusColor;
    String statusStr = item['status'].toString().toLowerCase();
    
    if (statusStr == 'pendiente') {
      statusColor = const Color(0xFFFFB74D); 
    } else if (statusStr == 'entregado' || statusStr == 'completado') {
      statusColor = const Color(0xFF81C784); 
    } else if (statusStr == 'cancelado') {
      statusColor = const Color(0xFFE57373); 
    } else {
      statusColor = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white12)
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // 2. AHORA AL TOCAR SE ABREN LOS DETALLES
          onTap: () => _abrirDetallePedido(item), 
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(item['fecha']), 
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Cant: ${item['cantidad']}", 
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)
                    ),
                    
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                      color: const Color(0xFF262626),
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
                        const PopupMenuItem(
                          value: 'edit', 
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: Colors.white, size: 18), 
                              SizedBox(width: 8), 
                              Text("Editar pedido", style: TextStyle(color: Colors.white))
                            ]
                          )
                        ),
                        if (statusStr == 'pendiente')
                          PopupMenuItem(
                            value: 'complete', 
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF81C784), size: 18), 
                                const SizedBox(width: 8), 
                                Text("Marcar recibido", style: GoogleFonts.inter(color: Colors.white))
                              ]
                            )
                          ),
                        const PopupMenuItem(
                          value: 'delete', 
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18), 
                              SizedBox(width: 8), 
                              Text("Eliminar registro", style: TextStyle(color: Colors.white))
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