import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/insumo_model.dart';

class InsumoDetalleScreen extends StatefulWidget {
  final InsumoModel insumo;

  const InsumoDetalleScreen({Key? key, required this.insumo}) : super(key: key);

  @override
  State<InsumoDetalleScreen> createState() => _InsumoDetalleScreenState();
}

class _InsumoDetalleScreenState extends State<InsumoDetalleScreen> {
  static const Color colorFondo = Color(0xFF121212);
  static const Color colorTarjeta = Color(0xFF1E1E1E);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Colors.white54;
  static const Color colorAcento = Color(0xFFFFDE21);
  
  List<Map<String, dynamic>> _historial = [];
  bool _cargandoHistorial = true;

  // --- MAPAS PARA CACHÉ (Evitar consultas repetidas a Firebase) ---
  final Map<String, String> _nombresProyectos = {};
  final Map<String, String> _nombresClientes = {};

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

// --- FUNCIÓN PARA OBTENER CLIENTE Y PROYECTO ---
  Future<String> _obtenerInfoProyecto(String proyectoId) async {
    if (proyectoId.isEmpty || proyectoId == 'general') return '';
    
    // Si ya lo buscamos antes, lo devolvemos rápido de la memoria
    if (_nombresProyectos.containsKey(proyectoId)) {
      return _nombresProyectos[proyectoId]!;
    }

    try {
      var docProy = await FirebaseFirestore.instance.collection('proyectos').doc(proyectoId).get();
      if (docProy.exists) {
        var dataProy = docProy.data() as Map<String, dynamic>;
        String nombreProy = dataProy['titulo'] ?? 'Proyecto Sin Nombre';
        
        // AQUÍ ESTÁ LA CORRECCIÓN: usamos 'id_cliente' tal como está en tu base de datos
        String idCliente = dataProy['id_cliente'] ?? ''; 
        
        String nombreCliente = 'Cliente Desconocido';
        if (idCliente.isNotEmpty) {
          // Buscamos el cliente (también usando caché por si acaso)
          if (_nombresClientes.containsKey(idCliente)) {
            nombreCliente = _nombresClientes[idCliente]!;
          } else {
            var docCli = await FirebaseFirestore.instance.collection('clientes').doc(idCliente).get();
            if (docCli.exists) {
              nombreCliente = (docCli.data() as Map<String, dynamic>)['nombre'] ?? 'Sin Nombre';
            }
            _nombresClientes[idCliente] = nombreCliente;
          }
        }
        
        // Formato: "Nombre del Cliente - Nombre del Proyecto"
        String infoFinal = "$nombreCliente | $nombreProy"; 
        _nombresProyectos[proyectoId] = infoFinal;
        return infoFinal;
      }
    } catch (e) {
      debugPrint("Error obteniendo info de proyecto: $e");
    }
    return '';
  }

  Future<void> _cargarHistorial() async {
    try {
      List<Map<String, dynamic>> tempHistorial = [];
      String insumoId = widget.insumo.id;

      // 1. Consultar Uso en Taller y Solicitudes Generales
      var solHerramientasSnap = await FirebaseFirestore.instance
          .collection('solicitudes_herramientas')
          .where('insumoId', isEqualTo: insumoId)
          .get();

      for (var doc in solHerramientasSnap.docs) {
        var data = doc.data();
        bool esGeneral = data['proyectoId'] == 'general';
        
        String infoProyecto = '';
        if (!esGeneral) {
          infoProyecto = await _obtenerInfoProyecto(data['proyectoId'] ?? '');
        }

        tempHistorial.add({
          'tipo': esGeneral ? 'Solicitud General' : 'Uso en Taller (Fabricación)',
          'fecha': (data['fechaSolicitud'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'descripcion': 'Solicitado por ${data['trabajadorNombre']} (${data['cantidad']} ${widget.insumo.unidadMedida})',
          'proyectoInfo': infoProyecto, // Guardamos la info extra
          'estatus': data['estatus'] ?? 'pendiente',
          'icono': esGeneral ? Icons.handyman_outlined : Icons.construction_rounded,
          'color': esGeneral ? Colors.blueAccent : Colors.cyanAccent,
        });
      }

      // 2. Consultar Reparaciones en Taller
      var reparacionesSnap = await FirebaseFirestore.instance
          .collection('reparaciones_taller')
          .where('insumoId', isEqualTo: insumoId)
          .get();

      for (var doc in reparacionesSnap.docs) {
        var data = doc.data();
        
        // Las reparaciones a veces traen el proyectoId desde donde se reportaron
        String infoProyecto = await _obtenerInfoProyecto(data['proyectoId'] ?? '');

        tempHistorial.add({
          'tipo': 'Reparación en Taller',
          'fecha': (data['fechaIngreso'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'descripcion': 'Reportado por ${data['reportadoPor']} (${data['cantidad']} ${widget.insumo.unidadMedida})',
          'proyectoInfo': infoProyecto,
          'estatus': data['estatus'] ?? 'en_reparacion',
          'icono': Icons.build_circle,
          'color': Colors.redAccent,
        });
      }

      // 3. Consultar Salidas a Instalación (Kits)
      var salidasSnap = await FirebaseFirestore.instance
          .collection('solicitudes_salida')
          .orderBy('fechaSolicitud', descending: true)
          .limit(50) 
          .get();

      for (var doc in salidasSnap.docs) {
        var data = doc.data();
        List articulos = data['articulos'] ?? [];
        
        var articuloEncontrado = articulos.where((a) => (a['insumoId'] == insumoId || a['id'] == insumoId)).firstOrNull;

        if (articuloEncontrado != null) {
          String infoProyecto = await _obtenerInfoProyecto(data['proyectoId'] ?? '');

          tempHistorial.add({
            'tipo': 'Salida a Instalación (Kit)',
            'fecha': (data['fechaSolicitud'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'descripcion': 'Enviado a obra (${articuloEncontrado['cantidad']} ${widget.insumo.unidadMedida})',
            'proyectoInfo': infoProyecto,
            'estatus': data['estatus'] ?? 'en_obra',
            'icono': Icons.local_shipping,
            'color': Colors.orangeAccent,
          });
        }
      }

      // Ordenar todo el historial de más reciente a más antiguo
      tempHistorial.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

      if (mounted) {
        setState(() {
          _historial = tempHistorial;
          _cargandoHistorial = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando historial: $e");
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  void _mostrarImagenExpandida(BuildContext context, String imageUrl, String heroTag) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: colorAcento)),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 50),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextoPrimario),
        title: Text(
          "DETALLE E HISTORIAL",
          style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 32),
            Text(
              "HISTORIAL DE MOVIMIENTOS",
              style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 16),
            _buildHistorialList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.insumo.imagenUrl != null && widget.insumo.imagenUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () => _mostrarImagenExpandida(context, widget.insumo.imagenUrl!, widget.insumo.id),
                  child: Hero(
                    tag: widget.insumo.id,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.insumo.imagenUrl!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 36),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.insumo.nombre,
                      style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.insumo.categoria.toUpperCase()} > ${widget.insumo.subcategoria.toUpperCase()}',
                      style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'STOCK DISPONIBLE: ${widget.insumo.cantidadDisponible} ${widget.insumo.unidadMedida}',
                        style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.qr_code, "Código de Barras", widget.insumo.codigoBarras ?? "Sin código"),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.storefront, "Producto de Tienda", widget.insumo.esProductoTienda ? "Sí" : "No"),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.warning_amber_rounded, "Stock Mínimo", "${widget.insumo.stockMinimo} ${widget.insumo.unidadMedida}"),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: colorAcento, size: 20),
        const SizedBox(width: 12),
        Text("$label: ", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
        Expanded(
          child: Text(value, style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildHistorialList() {
    if (_cargandoHistorial) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: colorAcento)));
    }

    if (_historial.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: colorTarjeta, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            const Icon(Icons.history_toggle_off, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text("No hay movimientos registrados", style: GoogleFonts.inter(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historial.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _historial[index];
        final Color iconColor = item['color'];
        final String fechaStr = DateFormat('dd MMM yyyy - HH:mm').format(item['fecha']);
        final String proyectoInfo = item['proyectoInfo'] ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorTarjeta,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item['icono'], color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['tipo'], style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(item['descripcion'], style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13, height: 1.3)),
                    
                    // --- NUEVA SECCIÓN VISUAL PARA EL CLIENTE Y PROYECTO ---
                    if (proyectoInfo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.business_center_outlined, size: 14, color: Colors.cyanAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              proyectoInfo,
                              style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // --------------------------------------------------------

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fechaStr, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)
                          ),
                          child: Text(
                            item['estatus'].toString().toUpperCase(), 
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}