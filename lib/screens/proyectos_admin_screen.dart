import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/proyecto_service.dart';
import '../models/proyecto_model.dart';
import 'crear_proyecto_admin_screen.dart';
import 'proyecto_detalle_admin_screen.dart';
import 'editar_proyecto_admin_screen.dart'; 

import 'dart:io'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ProyectosAdminScreen extends StatefulWidget {
  final String? filtroInicial;

  const ProyectosAdminScreen({Key? key, this.filtroInicial}) : super(key: key);

  @override
  State<ProyectosAdminScreen> createState() => _ProyectosAdminScreenState();
}

class _ProyectosAdminScreenState extends State<ProyectosAdminScreen> {
  final ProyectoService _proyectoService = ProyectoService();
  
  // Controladores y variables de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); 
  String _searchQuery = ''; 

  // Variable para el filtro de estatus
  late String _filtroEstatus; 

  // Diccionario para cargar los clientes una sola vez y buscar rápido
  Map<String, String> _clientesDict = {};
  bool _isLoadingClientes = true;

  @override
  void initState() {
    super.initState();
    
    _filtroEstatus = widget.filtroInicial ?? 'todos';
    
    _cargarClientesParaBuscador();

    // Forzamos el redibujado de la pantalla al cambiar el foco
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); 
    super.dispose();
  }

  // Descarga los nombres de los clientes para filtrar en tiempo real
  Future<void> _cargarClientesParaBuscador() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('clientes').get();
      final Map<String, String> dict = {};
      for (var doc in snap.docs) {
        dict[doc.id] = (doc.data()['nombre'] ?? 'Sin nombre').toString();
      }
      if (mounted) {
        setState(() {
          _clientesDict = dict;
          _isLoadingClientes = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando clientes: $e");
      if (mounted) setState(() => _isLoadingClientes = false);
    }
  }

  // Función para obtener el color según el estatus
  Color _getStatusColor(String estatus) {
    switch (estatus) {
      case 'finalizado': return Colors.greenAccent;
      case 'en_proceso': return Colors.cyanAccent;
      case 'pendiente': return Colors.orangeAccent;
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text('PROYECTOS', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF8B5CF6)),
            onPressed: _mostrarModalReporte,
          )
        ],
      ),
      body: _isLoadingClientes 
      ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
      : Column(
          children: [
            // --- BARRA DE BÚSQUEDA ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, 
                onTap: () {
                  setState(() {});
                },
                onTapOutside: (event) {
                  _searchFocusNode.unfocus();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por título, cliente o estatus...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6)),
                  suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchFocusNode.unfocus(); 
                        },
                      )
                    : const SizedBox.shrink(),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            // --- FILTROS DE ESTATUS (CHIPS) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFiltroChip('Todos', 'todos'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Pendientes', 'pendiente'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('En Proceso', 'en_proceso'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Finalizados', 'finalizado'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- LISTA DE PROYECTOS ---
            Expanded(
              child: StreamBuilder<List<Proyecto>>(
                stream: _proyectoService.getProyectos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No hay proyectos creados.', style: GoogleFonts.inter(color: Colors.white54)));
                  }

                  final proyectos = snapshot.data!.where((p) {
                    if (_filtroEstatus != 'todos' && p.estatus != _filtroEstatus) {
                      return false;
                    }

                    final tituloMatch = p.titulo.toLowerCase().contains(_searchQuery);
                    final estatusMatch = p.estatus.replaceAll('_', ' ').toLowerCase().contains(_searchQuery);
                    final nombreCliente = (_clientesDict[p.idCliente] ?? '').toLowerCase();
                    final clienteMatch = nombreCliente.contains(_searchQuery);

                    return tituloMatch || estatusMatch || clienteMatch;
                  }).toList();

                  if (proyectos.isEmpty) {
                     return Center(child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: Colors.white54)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: proyectos.length,
                    itemBuilder: (context, index) {
                      final proyecto = proyectos[index];
                      Color statusColor = _getStatusColor(proyecto.estatus);
                      String nombreClienteReal = _clientesDict[proyecto.idCliente] ?? 'Cliente desconocido';

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _searchFocusNode.unfocus(); 
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ProyectoDetalleAdminScreen(proyecto: proyecto)));
                          },
                          // -----------------------------------------------------------
                          // AQUI EMPIEZA LA MODIFICACIÓN: StreamBuilder para notificaciones
                          // -----------------------------------------------------------
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('solicitudes_salida')
                                .where('proyectoId', isEqualTo: proyecto.id)
                                .where('estatus', whereIn: ['pendiente', 'en_devolucion', 'recibida_con_danos'])
                                .snapshots(),
                            builder: (context, notifSnapshot) {
                              int notificaciones = notifSnapshot.hasData ? notifSnapshot.data!.docs.length : 0;
                              
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                      child: Icon(Icons.construction, color: statusColor, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(proyecto.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                              // --- INDICADOR DE CAMPANITA DE ALERTA ---
                                              if (notificaciones > 0)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: Colors.amber.withOpacity(0.5))
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.notifications_active, color: Colors.amber, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(notificaciones.toString(), style: GoogleFonts.inter(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                )
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          
                                          Row(
                                            children: [
                                              const Icon(Icons.person, color: Colors.white54, size: 14),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  nombreClienteReal, 
                                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          Wrap(
                                            spacing: 8.0,    
                                            runSpacing: 4.0, 
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: statusColor.withOpacity(0.3))
                                                ),
                                                child: Text(
                                                  proyecto.estatus.replaceAll('_', ' ').toUpperCase(),
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5),
                                                ),
                                              ),
                                              
                                              if (proyecto.estatus == 'pendiente')
                                                FutureBuilder<DocumentSnapshot>(
                                                  future: FirebaseFirestore.instance
                                                      .collection('proyectos')
                                                      .doc(proyecto.id)
                                                      .collection('finanzas')
                                                      .doc('datos_pago')
                                                      .get(),
                                                  builder: (context, finanzasSnapshot) {
                                                    if (finanzasSnapshot.connectionState == ConnectionState.waiting || !finanzasSnapshot.hasData || !finanzasSnapshot.data!.exists) {
                                                      return const SizedBox();
                                                    }
                                                    
                                                    final data = finanzasSnapshot.data!.data() as Map<String, dynamic>?;
                                                    if (data == null) return const SizedBox();

                                                    double cotizacion = (data['cotizacion'] ?? 0.0).toDouble();
                                                    double montoPagado = (data['monto_pagado'] ?? 0.0).toDouble();
                                                    double restante = cotizacion - montoPagado;

                                                    if (restante <= 0) return const SizedBox();

                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      child: Text(
                                                        "Resta: \$${restante.toStringAsFixed(2)}",
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11, 
                                                          fontWeight: FontWeight.w600, 
                                                          color: Colors.orangeAccent,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 22),
                                          onPressed: () {
                                            _searchFocusNode.unfocus(); 
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => EditarProyectoAdminScreen(proyecto: proyecto)),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
                                          onPressed: () {
                                            _searchFocusNode.unfocus();
                                            _confirmarEliminacion(proyecto);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                          // -----------------------------------------------------------
                          // FIN DE LA MODIFICACIÓN
                          // -----------------------------------------------------------
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6), 
        onPressed: () {
          _searchFocusNode.unfocus(); 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CrearProyectoAdminScreen()));
        },
        label: Text('Nuevo Proyecto', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmarEliminacion(Proyecto proyecto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar Proyecto?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Esta acción borrará el proyecto "${proyecto.titulo}" permanentemente de la base de datos.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _proyectoService.eliminarProyecto(proyecto.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Proyecto eliminado correctamente'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent)
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalReporte() {
    int mesSeleccionado = DateTime.now().month;
    int anioSeleccionado = DateTime.now().year;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf, color: Color(0xFF8B5CF6), size: 48),
                const SizedBox(height: 16),
                Text('Generar Reporte', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildDropdownContainer(child: DropdownButtonFormField<int>(
                  value: mesSeleccionado,
                  dropdownColor: const Color(0xFF2D2D2D),
                  decoration: const InputDecoration(border: InputBorder.none, labelText: 'Mes', labelStyle: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM', 'es').format(DateTime(0, i + 1)).toUpperCase()))),
                  onChanged: (val) => setStateModal(() => mesSeleccionado = val!),
                )),
                const SizedBox(height: 12),
                _buildDropdownContainer(child: DropdownButtonFormField<int>(
                  value: anioSeleccionado,
                  dropdownColor: const Color(0xFF2D2D2D),
                  decoration: const InputDecoration(border: InputBorder.none, labelText: 'Año', labelStyle: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text((DateTime.now().year - i).toString()))),
                  onChanged: (val) => setStateModal(() => anioSeleccionado = val!),
                )),
                const SizedBox(height: 32),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(context); _generarDescargarReporte(mesSeleccionado, anioSeleccionado); },
                  child: const Text('EXPORTAR DOCUMENTOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(12)),
    child: child,
  );

  Future<void> _generarDescargarReporte(int mes, int anio) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));

    try {
      final datosReporte = await _proyectoService.obtenerReporteProyectos(anio, mes);
      if (datosReporte.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin proyectos finalizados en ese periodo.')));
        return;
      }

      String nombreMes = DateFormat('MMMM', 'es').format(DateTime(0, mes)).toUpperCase();
      final output = await getTemporaryDirectory();
      String prefix = 'SaunaStilo_Reporte_${nombreMes}_$anio';
      String pdfPath = "${output.path}/$prefix.pdf";
      String csvPath = "${output.path}/$prefix.csv";

      final pdf = pw.Document();
      
      double totalRecaudado = datosReporte.fold(0.0, (sum, item) => sum + (item['monto'] as double));
      int totalProyectos = datosReporte.length;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SAUNASTILO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#090909"))),
                pw.Text('$nombreMes $anio', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex("#8B5CF6")),
            pw.SizedBox(height: 20),

            pw.Row(
              children: [
                _buildDashboardCard(pdf, 'PROYECTOS CONCLUIDOS', '$totalProyectos Unidades', PdfColor.fromHex("#34D399")),
                pw.SizedBox(width: 20),
                _buildDashboardCard(pdf, 'TOTAL RECAUDADO', '\$${totalRecaudado.toStringAsFixed(2)} MXN', PdfColor.fromHex("#8B5CF6")),
              ]
            ),
            pw.SizedBox(height: 30),

            pw.Center(
              child: pw.Text(
                'DESGLOSE GENERAL DE VENTAS CONCLUIDAS', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#040404"))),
            ),
            pw.SizedBox(height: 13),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2), 
                1: pw.FlexColumnWidth(3), 
                2: pw.FlexColumnWidth(2), 
                3: pw.FlexColumnWidth(1.5), 
                4: pw.FlexColumnWidth(1.5), 
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['ID REGISTRO', 'TÍTULO', 'CLIENTE', 'FECHA', 'MONTO'].map((h) => 
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))
                  ).toList(),
                ),
                ...datosReporte.map((r) {
                  Proyecto p = r['proyecto'] as Proyecto;
                  return pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p.id.substring(0, 8).toUpperCase(), style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p.titulo, style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_clientesDict[p.idCliente] ?? 'N/A', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(DateFormat('dd/MM/yyyy').format(p.fechaEntrega), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('\$${(r['monto'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9))),
                  ]);
                }).toList(),
              ],
            ),
          ]);
        },
      ));

      await File(pdfPath).writeAsBytes(await pdf.save());

      List<List<dynamic>> csvData = [['PROYECTO', 'CLIENTE', 'MONTO']];
      for (var r in datosReporte) {
        csvData.add([(r['proyecto'] as Proyecto).titulo, _clientesDict[(r['proyecto'] as Proyecto).idCliente] ?? 'N/A', (r['monto'] as double).toStringAsFixed(2)]);
      }
      await File(csvPath).writeAsString(const ListToCsvConverter().convert(csvData));

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Reporte generado', style: TextStyle(color: Colors.white)),
            content: const Text('¿Qué archivo deseas compartir?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(pdfPath, mimeType: 'application/pdf')], text: 'Reporte PDF: $nombreMes $anio');             
                },
                child: const Text('Compartir PDF', style: TextStyle(color: Colors.purpleAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(csvPath, mimeType: 'text/csv')], text: 'Reporte CSV: $nombreMes $anio');               
                },
                child: const Text('Compartir CSV', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  pw.Widget _buildDashboardCard(pw.Document pdf, String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 5),
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String value) {
    final isSelected = _filtroEstatus == value;
    Color statusColor = value == 'todos' ? Colors.white : _getStatusColor(value);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF121212) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: statusColor,
      backgroundColor: const Color(0xFF1E1E1E),
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? Colors.transparent : statusColor.withOpacity(0.5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filtroEstatus = value;
          });
          _searchFocusNode.unfocus();
        }
      },
    );
  }
}