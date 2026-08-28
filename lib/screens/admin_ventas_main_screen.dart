import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compra_model.dart';
import '../models/proyecto_model.dart';
import 'proyecto_detalle_admin_screen.dart';

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({Key? key}) : super(key: key);

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  // Controladores y variables de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Variable para almacenar el Future y no re-consultar Firebase al buscar
  late Future<List<Map<String, dynamic>>> _ventasFuture;

  @override
  void initState() {
    super.initState();
    _cargarDatos();

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

  void _cargarDatos() {
    _ventasFuture = _obtenerVentasGenerales();
  }

  void _refreshScreen() {
    setState(() {
      _cargarDatos();
    });
  }

  // Obtener TODO el historial general de ventas
  Future<List<Map<String, dynamic>>> _obtenerVentasGenerales() async {
    final db = FirebaseFirestore.instance;
    List<Map<String, dynamic>> historial = [];

    // 1. Obtener TODAS las Compras
    final comprasSnap = await db.collection('compras').get();
    for (var doc in comprasSnap.docs) {
      String idCliente = doc.data()['id_cliente'] ?? '';
      String nombreCliente = 'Cliente Desconocido';
      
      if (idCliente.isNotEmpty) {
        final clienteDoc = await db.collection('clientes').doc(idCliente).get();
        if (clienteDoc.exists) nombreCliente = clienteDoc.data()?['nombre'] ?? 'Cliente Desconocido';
      }

      historial.add({
        'id_documento': doc.id,
        'tipo': 'compra',
        'fecha': (doc.data()['fecha_compra'] as Timestamp).toDate(),
        'monto': (doc.data()['monto_total'] as num).toDouble(),
        'nombre_cliente': nombreCliente,
        'data': CompraModel.fromJson(doc.id, doc.data())
      });
    }

    // 2. Obtener TODOS los Proyectos Finalizados
    final proySnap = await db.collection('proyectos')
        .where('estatus', isEqualTo: 'finalizado')
        .get();

    for (var doc in proySnap.docs) {
      var finanzas = await doc.reference.collection('finanzas').doc('datos_pago').get();
      double montoPagado = finanzas.exists ? (finanzas.data()?['monto_pagado'] ?? 0.0).toDouble() : 0.0;
      
      String idCliente = doc.data()['id_cliente'] ?? '';
      String nombreCliente = 'Cliente Desconocido';
      
      if (idCliente.isNotEmpty) {
        final clienteDoc = await db.collection('clientes').doc(idCliente).get();
        if (clienteDoc.exists) nombreCliente = clienteDoc.data()?['nombre'] ?? 'Cliente Desconocido';
      }

      historial.add({
        'tipo': 'proyecto',
        'fecha': (doc.data()['fecha_entrega'] as Timestamp).toDate(),
        'monto': montoPagado,
        'nombre_cliente': nombreCliente,
        'data': Proyecto.fromFirestore(doc)
      });
    }

    // Ordenar todo por fecha descendente
    historial.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));
    return historial;
  }

  // --- OPERACIONES CRUD DE COMPRAS ---

  Future<void> _eliminarCompra(CompraModel compra) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (var prod in compra.productosExtra) {
      final String? idProd = prod['id_producto'];
      final int cant = prod['cantidad'] ?? 0;

      if (idProd != null && idProd.isNotEmpty) {
        final refInsumo = db.collection('insumos_inventario').doc(idProd);
        batch.update(refInsumo, {'cantidad_disponible': FieldValue.increment(cant)});
      }
    }

    batch.delete(db.collection('compras').doc(compra.id));
    await batch.commit();
    _refreshScreen(); 
  }

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
              _refreshScreen(); 
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
        title: Text("REGISTRO DE VENTAS", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFFB7A33)),
            onPressed: _mostrarModalReporte,
          )
        ],
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTapOutside: (event) {
                _searchFocusNode.unfocus();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por título, cliente o tipo...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF3399)),
                // <-- AQUÍ ESTÁ LA MAGIA: usamos hasFocus y SizedBox.shrink()
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _searchFocusNode.unfocus(); // Cierra el teclado
                      },
                    )
                  : const SizedBox.shrink(), // Widget invisible en lugar de null
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFFDE21), width: 1.5)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Align(
              alignment: Alignment.center, 
              child: Text("PROYECTOS FINALIZADOS Y COMPRAS", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ventasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No hay ventas registradas", style: GoogleFonts.inter(color: Colors.white24)));
                }
                
                final historial = snapshot.data!;

                // --- APLICAR FILTRO DE BÚSQUEDA ---
                final filtradas = historial.where((item) {
                  bool esCompra = item['tipo'] == 'compra';
                  String nombreCliente = (item['nombre_cliente'] as String).toLowerCase();
                  String tipo = esCompra ? 'compra extra' : 'proyecto';
                  String tituloProyecto = esCompra ? '' : (item['data'] as Proyecto).titulo.toLowerCase();

                  return nombreCliente.contains(_searchQuery) || 
                         tipo.contains(_searchQuery) || 
                         tituloProyecto.contains(_searchQuery);
                }).toList();

                if (filtradas.isEmpty) {
                  return Center(child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: filtradas.length,
                  itemBuilder: (context, index) => _buildItemCard(filtradas[index]),
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
    String nombreCliente = item['nombre_cliente'];

    if (esCompra) {
      return _buildCompraCard(data as CompraModel, nombreCliente);
    } else {
      return _buildProyectoCard(data as Proyecto, item['monto'], nombreCliente);
    }
  }

  Widget _buildProyectoCard(Proyecto proyecto, double monto, String nombreCliente) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
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
            Text("Cliente: $nombreCliente", style: GoogleFonts.inter(color: const Color(0xFF6699FF), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text("Entregado: ${DateFormat('dd/MM/yyyy').format(proyecto.fechaEntrega)}", style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompraCard(CompraModel compra, String nombreCliente) {
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
                const SizedBox(height: 2),
                Text("Cliente: $nombreCliente", style: GoogleFonts.inter(color: const Color(0xFFFB975F), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(DateFormat('dd/MM/yyyy').format(compra.fechaCompra), style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ]),
              Row(
                children: [
                  Text("\$${compra.montoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: const Color(0xFFFFDE21), fontWeight: FontWeight.bold, fontSize: 16)),
                  
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                    color: const Color(0xFF262626),
                    onSelected: (action) {
                      _searchFocusNode.unfocus();
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
            ...compra.productosExtra.map((prod) => Text("• ${prod['nombre_producto']} (x${prod['cantidad']})", style: const TextStyle(color: Colors.white54, fontSize: 12))),
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

  // --- LÓGICA DE REPORTES ---

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
                const Icon(Icons.point_of_sale, color: Color(0xFFFFDE21), size: 48),
                const SizedBox(height: 16),
                Text('Reporte de Ventas', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                // Mes
                _buildDropdownContainer(child: DropdownButtonFormField<int>(
                  value: mesSeleccionado,
                  dropdownColor: const Color(0xFF2D2D2D),
                  decoration: const InputDecoration(border: InputBorder.none, labelText: 'Mes', labelStyle: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM', 'es').format(DateTime(0, i + 1)).toUpperCase()))),
                  onChanged: (val) => setStateModal(() => mesSeleccionado = val!),
                )),
                const SizedBox(height: 12),
                // Año
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFB975F), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(context); _generarDescargarReporte(mesSeleccionado, anioSeleccionado); },
                  child: const Text('EXPORTAR DOCUMENTOS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21))));

    try {
      List<Map<String, dynamic>> todoElHistorial = await _obtenerVentasGenerales();
      
      List<Map<String, dynamic>> datosReporte = todoElHistorial.where((item) {
        DateTime fecha = item['fecha'] as DateTime;
        return fecha.month == mes && fecha.year == anio;
      }).toList();

      if (datosReporte.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin ventas en ese periodo.')));
        return;
      }

      String nombreMes = DateFormat('MMMM', 'es').format(DateTime(0, mes)).toUpperCase();
      final output = await getTemporaryDirectory();
      String prefix = 'Ventas_Generales_${nombreMes}_$anio';
      String pdfPath = "${output.path}/$prefix.pdf";
      String csvPath = "${output.path}/$prefix.csv";

      final pdf = pw.Document();
      
      double totalRecaudado = datosReporte.fold(0.0, (sum, item) => sum + (item['monto'] as double));
      int totalVentas = datosReporte.length;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SAUNASTILO - VENTAS MENSUALES', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#040404"))),
                pw.Text('$nombreMes $anio', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex("#ff2197")),
            pw.SizedBox(height: 20),

            pw.Row(
              children: [
                _buildDashboardCard(pdf, 'TRANSACCIONES', '$totalVentas Registros', PdfColor.fromHex("#34D399")),
                pw.SizedBox(width: 20),
                _buildDashboardCard(pdf, 'TOTAL INGRESOS', '\$${totalRecaudado.toStringAsFixed(2)} MXN', PdfColor.fromHex("#7a21ff")),
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
                0: pw.FlexColumnWidth(1.5), // TIPO
                1: pw.FlexColumnWidth(3),   // Título/Concepto
                2: pw.FlexColumnWidth(2),   // Cliente
                3: pw.FlexColumnWidth(1.5), // Fecha
                4: pw.FlexColumnWidth(1.5), // Monto
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['TIPO', 'CONCEPTO', 'CLIENTE', 'FECHA', 'MONTO'].map((h) => 
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))
                  ).toList(),
                ),
                ...datosReporte.map((r) {
                  bool esCompra = r['tipo'] == 'compra';
                  String concepto = esCompra ? 'Compra de accesorios' : (r['data'] as Proyecto).titulo;
                  
                  return pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(esCompra ? 'COMPRA' : 'PROYECTO', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(concepto, style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(r['nombre_cliente'], style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(DateFormat('dd/MM/yyyy').format(r['fecha']), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('\$${(r['monto'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9))),
                  ]);
                }).toList(),
              ],
            ),
          ]);
        },
      ));

      await File(pdfPath).writeAsBytes(await pdf.save());

      List<List<dynamic>> csvData = [['TIPO', 'CONCEPTO', 'CLIENTE', 'FECHA', 'MONTO']];
      for (var r in datosReporte) {
        bool esCompra = r['tipo'] == 'compra';
        String concepto = esCompra ? 'Compra de accesorios' : (r['data'] as Proyecto).titulo;
        csvData.add([
          esCompra ? 'COMPRA' : 'PROYECTO', 
          concepto, 
          r['nombre_cliente'], 
          DateFormat('dd/MM/yyyy').format(r['fecha']), 
          (r['monto'] as double).toStringAsFixed(2)
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
          ]
        ),
      ),
    );
  }
}