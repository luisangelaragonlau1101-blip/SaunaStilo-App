import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seguimiento_cotizaciones_model.dart';
import 'nueva_cotizacion_screen.dart'; 
import 'detalle_cotizacion_screen.dart';

// --- IMPORTS PARA LA EXPORTACIÓN ---
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SeguimientoCotizacionesScreen extends StatefulWidget {
  const SeguimientoCotizacionesScreen({Key? key}) : super(key: key);

  @override
  State<SeguimientoCotizacionesScreen> createState() => _SeguimientoCotizacionesScreenState();
}

class _SeguimientoCotizacionesScreenState extends State<SeguimientoCotizacionesScreen> {
  // CONTROLADORES PARA EL BUSCADOR
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // <-- Forzamos el redibujado de la pantalla al cambiar el foco
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

  void _confirmarEliminacion(SeguimientoCotizacionModel cotizacion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('¿Eliminar cotización?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se borrará la cotización de ${cotizacion.datosCliente.nombre}. Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context); 
              try {
                await FirebaseFirestore.instance
                    .collection('seguimiento_cotizaciones')
                    .doc(cotizacion.id)
                    .delete();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cotización eliminada'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS PARA EL REPORTE ---
  void _mostrarModalReporte() {
    final List<String> opcionesEstatus = ['PENDIENTE', 'ACEPTADA', 'RECHAZADA'];
    String estatusSeleccionado = opcionesEstatus.first;

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
                const Text('Generar Reporte', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                _buildDropdownContainer(
                  child: DropdownButtonFormField<String>(
                    value: estatusSeleccionado,
                    dropdownColor: const Color(0xFF2D2D2D),
                    decoration: const InputDecoration(border: InputBorder.none, labelText: 'Estatus', labelStyle: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    items: opcionesEstatus.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setStateModal(() => estatusSeleccionado = val!),
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () { 
                      Navigator.pop(context); 
                      _generarDescargarReporte(estatusSeleccionado); 
                    },
                    child: const Text('EXPORTAR DOCUMENTOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
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

  Future<void> _generarDescargarReporte(String estatus) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));

    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('seguimiento_cotizaciones').get();
      
      final datosReporte = querySnapshot.docs
          .map((doc) => SeguimientoCotizacionModel.fromJson(doc.data(), doc.id))
          .where((cotizacion) => cotizacion.estatusCotizacion.toLowerCase() == estatus.toLowerCase())
          .toList();

      if (datosReporte.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sin cotizaciones en estado: $estatus.')));
        return;
      }

      final output = await getTemporaryDirectory();
      String prefix = 'SaunaStylo_Cotizaciones_$estatus';
      String pdfPath = "${output.path}/$prefix.pdf";
      String csvPath = "${output.path}/$prefix.csv";

      final pdf = pw.Document();
      
      double totalRecaudado = datosReporte.fold(0.0, (sum, cotizacion) => sum + cotizacion.montoCotizado);
      int totalCotizaciones = datosReporte.length;

      // 👇 NUEVO DISEÑO PDF
      pdf.addPage(pw.MultiPage(
        // Usamos formato horizontal para tener más espacio para las tablas
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SAUNASTYLO', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#090909"))),
                    pw.SizedBox(height: 4),
                    pw.Text('Reporte Operativo de Cotizaciones', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ]
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _getPdfStatusColor(estatus),
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    'ESTATUS: ${estatus.toUpperCase()}', 
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromHex("#8B5CF6"), thickness: 1.5),
            pw.SizedBox(height: 20),

            pw.Row(
              children: [
                _buildDashboardCard(pdf, 'TOTAL EN LISTA', '$totalCotizaciones Registros', PdfColor.fromHex("#34D399")),
                pw.SizedBox(width: 20),
                _buildDashboardCard(pdf, 'VOLUMEN COTIZADO', '\$${totalRecaudado.toStringAsFixed(2)} MXN', PdfColor.fromHex("#8B5CF6")),
                pw.SizedBox(width: 20),
                _buildDashboardCard(pdf, 'FECHA DE EMISIÓN', DateFormat('dd/MM/yyyy').format(DateTime.now()), PdfColors.grey600),
              ]
            ),
            pw.SizedBox(height: 30),

            pw.Text(
              'DESGLOSE DETALLADO', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#040404"))
            ),
            pw.SizedBox(height: 12),

            // NUEVA TABLA PRO
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),   // ID
                1: pw.FlexColumnWidth(2),   // Proyecto / Admin
                2: pw.FlexColumnWidth(2),   // Cliente / Contacto
                3: pw.FlexColumnWidth(3),   // Notas (última nota)
                4: pw.FlexColumnWidth(1.5), // Fecha
                5: pw.FlexColumnWidth(1.5), // Monto
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: ['ID', 'PROYECTO & ENCARGADO', 'CLIENTE & CONTACTO', 'ESTADO DE TAREAS', 'FECHA', 'MONTO'].map((h) => 
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6), 
                      child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey800))
                    )
                  ).toList(),
                ),
                ...datosReporte.map((cotizacion) {
                  final idAbreviado = cotizacion.id.length > 8 ? cotizacion.id.substring(0, 8).toUpperCase() : cotizacion.id.toUpperCase();
                  final titulo = cotizacion.datosProyecto.titulo.isNotEmpty ? cotizacion.datosProyecto.titulo : 'Sin título';
                  final admin = cotizacion.adminEncargado.isNotEmpty ? cotizacion.adminEncargado : 'Sin asignar';
                  final clienteNombre = cotizacion.datosCliente.nombre.isNotEmpty ? cotizacion.datosCliente.nombre : 'Sin cliente';
                  final clienteTel = cotizacion.datosCliente.telefono.isNotEmpty ? cotizacion.datosCliente.telefono : 'Sin tel';
                  
                  // Calculamos estado de tareas
                  int tareasTotales = cotizacion.notasSeguimiento.length;
                  int tareasCompletadas = cotizacion.notasSeguimiento.where((n) => n.completada).length;
                  String infoTareas = tareasTotales == 0 ? "Sin tareas" : "$tareasCompletadas de $tareasTotales tareas completadas.";
                  
                  // Sacamos la última nota si existe
                  String ultimaNota = "";
                  if (tareasTotales > 0) {
                    final nota = cotizacion.notasSeguimiento.last;
                    ultimaNota = "Última: ${nota.comentario}";
                  }

                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      // ID
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Text(idAbreviado, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))
                      ),
                      // Proyecto
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(titulo, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text("Resp: $admin", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ]
                        )
                      ),
                      // Cliente
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text(clienteTel, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ]
                        )
                      ),
                      // Tareas
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(infoTareas, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#8B5CF6"))),
                            pw.SizedBox(height: 2),
                            if (ultimaNota.isNotEmpty) 
                              pw.Text(ultimaNota, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700), maxLines: 2),
                          ]
                        )
                      ),
                      // Fecha
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Text(DateFormat('dd/MM/yyyy').format(cotizacion.fechaCotizacion), style: const pw.TextStyle(fontSize: 8))
                      ),
                      // Monto
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Text('\$${cotizacion.montoCotizado.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#059669")))
                      ),
                  ]);
                }).toList(),
              ],
            ),
          ];
        },
      ));

      await File(pdfPath).writeAsBytes(await pdf.save());

      List<List<dynamic>> csvData = [['ID', 'PROYECTO', 'ENCARGADO', 'CLIENTE', 'TELEFONO', 'FECHA', 'MONTO', 'TAREAS_TOTALES', 'TAREAS_COMPLETADAS']];
      for (var cotizacion in datosReporte) {
        csvData.add([
          cotizacion.id.substring(0, 8),
          cotizacion.datosProyecto.titulo.isNotEmpty ? cotizacion.datosProyecto.titulo : 'Sin título', 
          cotizacion.adminEncargado.isNotEmpty ? cotizacion.adminEncargado : 'Sin asignar',
          cotizacion.datosCliente.nombre.isNotEmpty ? cotizacion.datosCliente.nombre : 'Sin cliente', 
          cotizacion.datosCliente.telefono,
          DateFormat('dd/MM/yyyy').format(cotizacion.fechaCotizacion),
          cotizacion.montoCotizado.toStringAsFixed(2),
          cotizacion.notasSeguimiento.length,
          cotizacion.notasSeguimiento.where((n) => n.completada).length
        ]);
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
                  Share.shareXFiles([XFile(pdfPath, mimeType: 'application/pdf')], text: 'Reporte Cotizaciones PDF: $estatus');             
                },
                child: const Text('Compartir PDF', style: TextStyle(color: Colors.purpleAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(csvPath, mimeType: 'text/csv')], text: 'Reporte Cotizaciones CSV: $estatus');             
                },
                child: const Text('Compartir CSV', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error generando reporte: $e");
    }
  }

  pw.Widget _buildDashboardCard(pw.Document pdf, String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 1.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ]
        ),
      ),
    );
  }

  // 👇 Helper para colores en el PDF
  PdfColor _getPdfStatusColor(String estatus) {
    switch (estatus.toUpperCase()) {
      case 'ACEPTADA':
        return PdfColor.fromHex("#10B981"); // Verde
      case 'RECHAZADA':
        return PdfColor.fromHex("#EF4444"); // Rojo
      case 'PENDIENTE':
      default:
        return PdfColor.fromHex("#F59E0B"); // Amarillo
    }
  }

  Color _getEstatusColor(String estatus) {
    switch (estatus.toUpperCase()) {
      case 'ACEPTADA':
        return Colors.greenAccent;
      case 'RECHAZADA':
        return Colors.redAccent;
      case 'PENDIENTE':
      default:
        return Colors.amberAccent; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Seguimiento de Cotizaciones', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF8B5CF6)),
            onPressed: _mostrarModalReporte,
          )
        ],
      ),
      body: Column(
        children: [
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
                // <-- AQUÍ APLICAMOS LA MAGIA (hasFocus y SizedBox.shrink())
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
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('seguimiento_cotizaciones')
                  .orderBy('fecha_cotizacion', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'No hay cotizaciones registradas',
                          style: TextStyle(fontSize: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                var cotizaciones = snapshot.data!.docs.map((doc) {
                  return SeguimientoCotizacionModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
                }).toList();

                if (_searchQuery.isNotEmpty) {
                  cotizaciones = cotizaciones.where((p) {
                    final tituloMatch = p.datosProyecto.titulo.toLowerCase().contains(_searchQuery);
                    final estatusMatch = p.estatusCotizacion.toLowerCase().contains(_searchQuery);
                    final clienteMatch = p.datosCliente.nombre.toLowerCase().contains(_searchQuery);

                    return tituloMatch || estatusMatch || clienteMatch;
                  }).toList();
                }

                if (cotizaciones.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron resultados.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: cotizaciones.length,
                  itemBuilder: (context, index) {
                    final cotizacion = cotizaciones[index];
                    final Color colorEstatus = _getEstatusColor(cotizacion.estatusCotizacion);

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white12, width: 1), 
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            onTap: () {
                              _searchFocusNode.unfocus(); 
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetalleCotizacionScreen(cotizacion: cotizacion),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              cotizacion.datosProyecto.titulo.isEmpty 
                                  ? 'Proyecto sin título' 
                                  : cotizacion.datosProyecto.titulo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Colors.white54),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          cotizacion.datosCliente.nombre,
                                          style: const TextStyle(color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white54),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatoFecha.format(cotizacion.fechaCotizacion),
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.assignment_ind_outlined, size: 16, color: Color(0xFF8B5CF6)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          cotizacion.adminEncargado.isEmpty ? 'Sin asignar' : cotizacion.adminEncargado,
                                          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatoMoneda.format(cotizacion.montoCotizado),
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorEstatus.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cotizacion.estatusCotizacion,
                                    style: TextStyle(
                                      color: colorEstatus,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_note, color: Color(0xFF8B5CF6)),
                                  label: const Text('Editar / Notas', style: TextStyle(color: Color(0xFF8B5CF6))),
                                  onPressed: () {
                                    _searchFocusNode.unfocus(); 
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NuevaCotizacionScreen(cotizacionAEditar: cotizacion),
                                      ),
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                  onPressed: () => _confirmarEliminacion(cotizacion), 
                                ),
                              ],
                            ),
                          ),
                        ],
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: () {
          _searchFocusNode.unfocus(); 
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NuevaCotizacionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cotización', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}