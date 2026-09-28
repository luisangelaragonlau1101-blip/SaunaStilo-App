import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
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
      default: return StiloColors.text.withValues(alpha: .54);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text('PROYECTOS', style: GoogleFonts.inter(fontSize: 16, color: StiloColors.text, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: StiloColors.accent),
            onPressed: _mostrarModalReporte,
          )
        ],
      ),
      body: _isLoadingClientes
      ? Center(child: CircularProgressIndicator(color: StiloColors.accent))
      : Column(
          children: [
            // --- BARRA DE BÚSQUEDA ---
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(contextMenuBuilder: privacyTextMenu,
                controller: _searchController,
                focusNode: _searchFocusNode,
                onTap: () {
                  setState(() {});
                },
                onTapOutside: (event) {
                  _searchFocusNode.unfocus();
                },
                style: TextStyle(color: StiloColors.text),
                decoration: InputDecoration(
                  hintText: 'Buscar por título, cliente o estatus...',
                  hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                  prefixIcon: Icon(Icons.search, color: StiloColors.accent),
                  suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                    ? IconButton(
                        icon: Icon(Icons.clear, color: StiloColors.text.withValues(alpha: .54)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchFocusNode.unfocus();
                        },
                      )
                    : SizedBox.shrink(),
                  filled: true,
                  fillColor: StiloColors.surface,
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: StiloColors.accent, width: 1.5)),
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
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFiltroChip('Todos', 'todos'),
                  SizedBox(width: 8),
                  _buildFiltroChip('Pendientes', 'pendiente'),
                  SizedBox(width: 8),
                  _buildFiltroChip('En Proceso', 'en_proceso'),
                  SizedBox(width: 8),
                  _buildFiltroChip('Finalizados', 'finalizado'),
                ],
              ),
            ),
            SizedBox(height: 12),

            // --- LISTA DE PROYECTOS ---
            Expanded(
              child: StreamBuilder<List<Proyecto>>(
                stream: _proyectoService.getProyectos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: StiloColors.accent));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No hay proyectos creados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))));
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
                     return Center(child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: proyectos.length,
                    itemBuilder: (context, index) {
                      final proyecto = proyectos[index];
                      Color statusColor = _getStatusColor(proyecto.estatus);
                      String nombreClienteReal = _clientesDict[proyecto.idCliente] ?? 'Cliente desconocido';

                      return Card(
                        color: StiloColors.surface,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: StiloColors.text.withValues(alpha: .12))),
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
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                      child: Icon(Icons.construction, color: statusColor, size: 24),
                                    ),
                                    SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(proyecto.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: StiloColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ),
                                              // --- INDICADOR DE CAMPANITA DE ALERTA ---
                                              if (notificaciones > 0)
                                                Container(
                                                  margin: EdgeInsets.only(left: 8),
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: Colors.amber.withOpacity(0.5))
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.notifications_active, color: Colors.amber, size: 14),
                                                      SizedBox(width: 4),
                                                      Text(notificaciones.toString(), style: GoogleFonts.inter(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                )
                                            ],
                                          ),
                                          SizedBox(height: 6),

                                          Row(
                                            children: [
                                              Icon(Icons.person, color: StiloColors.text.withValues(alpha: .54), size: 14),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  nombreClienteReal,
                                                  style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .54)),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),

                                          Wrap(
                                            spacing: 8.0,
                                            runSpacing: 4.0,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                      return SizedBox();
                                                    }

                                                    final data = finanzasSnapshot.data!.data() as Map<String, dynamic>?;
                                                    if (data == null) return SizedBox();

                                                    double cotizacion = (data['cotizacion'] ?? 0.0).toDouble();
                                                    double montoPagado = (data['monto_pagado'] ?? 0.0).toDouble();
                                                    double restante = cotizacion - montoPagado;

                                                    if (restante <= 0) return SizedBox();

                                                    return Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                          icon: Icon(Icons.edit_outlined, color: StiloColors.text.withValues(alpha: .54), size: 22),
                                          onPressed: () {
                                            _searchFocusNode.unfocus();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => EditarProyectoAdminScreen(proyecto: proyecto)),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
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
        backgroundColor: StiloColors.accent,
        onPressed: () {
          _searchFocusNode.unfocus();
          Navigator.push(context, MaterialPageRoute(builder: (context) => CrearProyectoAdminScreen()));
        },
        label: Text('Nuevo Proyecto', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: StiloColors.text)),
        icon: Icon(Icons.add, color: StiloColors.text),
      ),
    );
  }

  void _confirmarEliminacion(Proyecto proyecto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StiloColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar Proyecto?', style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold)),
        content: Text(
          'Esta acción borrará el proyecto "${proyecto.titulo}" permanentemente de la base de datos.',
          style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _proyectoService.eliminarProyecto(proyecto.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Proyecto eliminado correctamente'), backgroundColor: Colors.green)
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
            child: Text('Eliminar', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
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
          insetPadding: EdgeInsets.all(20),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, color: StiloColors.accent, size: 48),
                SizedBox(height: 16),
                Text('Generar Reporte', style: GoogleFonts.inter(fontSize: 20, color: StiloColors.text, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                _buildDropdownContainer(child: DropdownButtonFormField<int>(
                  value: mesSeleccionado,
                  dropdownColor: StiloColors.surface,
                  decoration: InputDecoration(border: InputBorder.none, labelText: 'Mes', labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
                  style: TextStyle(color: StiloColors.text, fontSize: 16),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM', 'es').format(DateTime(0, i + 1)).toUpperCase()))),
                  onChanged: (val) => setStateModal(() => mesSeleccionado = val!),
                )),
                SizedBox(height: 12),
                _buildDropdownContainer(child: DropdownButtonFormField<int>(
                  value: anioSeleccionado,
                  dropdownColor: StiloColors.surface,
                  decoration: InputDecoration(border: InputBorder.none, labelText: 'Año', labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
                  style: TextStyle(color: StiloColors.text, fontSize: 16),
                  items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text((DateTime.now().year - i).toString()))),
                  onChanged: (val) => setStateModal(() => anioSeleccionado = val!),
                )),
                SizedBox(height: 32),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: StiloColors.accent, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(context); _generarDescargarReporte(mesSeleccionado, anioSeleccionado); },
                  child: Text('EXPORTAR DOCUMENTOS', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
                ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(12)),
    child: child,
  );

  Future<void> _generarDescargarReporte(int mes, int anio) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: StiloColors.accent)));

    try {
      final datosReporte = await _proyectoService.obtenerReporteProyectos(anio, mes);
      if (datosReporte.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sin proyectos finalizados en ese periodo.')));
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
                pw.Text('$nombreMes $anio', style: pw.TextStyle(fontSize: 14)),
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
              columnWidths: {
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
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))
                  ).toList(),
                ),
                ...datosReporte.map((r) {
                  Proyecto p = r['proyecto'] as Proyecto;
                  return pw.TableRow(children: [
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(p.id.substring(0, 8).toUpperCase(), style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(p.titulo, style: pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(_clientesDict[p.idCliente] ?? 'N/A', style: pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(DateFormat('dd/MM/yyyy').format(p.fechaEntrega), style: pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('\$${(r['monto'] as double).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9))),
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
      await File(csvPath).writeAsString(ListToCsvConverter().convert(csvData));

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: StiloColors.surface,
            title: Text('Reporte generado', style: TextStyle(color: StiloColors.text)),
            content: Text('¿Qué archivo deseas compartir?', style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ExternalTransfer.block(context);
                },
                child: Text('Compartir PDF', style: TextStyle(color: Colors.purpleAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ExternalTransfer.block(context);
                },
                child: Text('Compartir CSV', style: TextStyle(color: Colors.blueAccent)),
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
        padding: pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 2), borderRadius: pw.BorderRadius.all(pw.Radius.circular(5))),
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
    Color statusColor = value == 'todos' ? StiloColors.text : _getStatusColor(value);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? StiloColors.surface : StiloColors.text.withValues(alpha: .70),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: statusColor,
      backgroundColor: StiloColors.surface,
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
