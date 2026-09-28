import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import '../widgets/warehouse_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventario_service.dart';
import '../models/insumo_model.dart';
import 'admin_categorias_screen.dart';
import 'recepcion_inventario_screen.dart';
import 'insumo_form_screen.dart';
import 'insumo_detalle_screen.dart';
// --- IMPORTS PARA PDF Y EXPORTACIÓN ---
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// --- IMPORT PARA LAS IMÁGENES ---
import '../widgets/inventory_photo.dart';

// --- IMPORT PARA LA REPARACIÓN ---
import 'admin_reparaciones_screen.dart';

// --- IMPORT PARA EL ESCÁNER ---
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

// --- 1. NUEVOS IMPORTS PARA SONIDO Y VIBRACIÓN ---
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';


class InventarioAdminScreen extends StatefulWidget {
  const InventarioAdminScreen({super.key});

  @override
  State<InventarioAdminScreen> createState() => _InventarioAdminScreenState();
}

class _InventarioAdminScreenState extends State<InventarioAdminScreen> {
  final InventarioService _inventarioService = InventarioService();

  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  bool _estaBuscando = false;
  String _filtroStock = "Todos";

  Color get colorFondo => StiloColors.background;
  Color get colorTarjeta => StiloColors.surface;
  Color get colorTextoPrimario => StiloColors.text;
  Color get colorAcento => StiloColors.accent;
  Color get colorRosa => StiloColors.accent;
  Color get colorAzul => StiloColors.accent;
  Color get colorMorado => StiloColors.accent;
  Color get colorRojoCoral => Color(0xFFFF5252);
  Color get colorRosaVibrante => Color(0xFFFF729C);
  Color get colorBlanco => StiloColors.text;
  Color get colorVerde1 => Color(0xFF7CE3BD);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _escanearCodigo() async {
    try {
      // Abre la pantalla del escáner moderno
      String? res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleBarcodeScannerPage(),
        ),
      );

      // Si el usuario escaneó algo (y no canceló)
      if (res != null && res != '-1') {

        // --- 2. AQUÍ AGREGAMOS EL SONIDO Y LA VIBRACIÓN ---
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/beep.ogg'));
        HapticFeedback.heavyImpact();
        // --------------------------------------------------

        setState(() {
          _estaBuscando = true;
          _searchController.text = res;
        });
      }
    } catch (e) {
      _mostrarSnackBar('Error al escanear: $e', Colors.redAccent);
    }
  }

  Color _obtenerColorBarra(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'material':
      case 'materiales':
        return colorRosaVibrante;
      case 'herramienta':
      case 'herramientas':
        return colorRojoCoral;
      case 'máquinas':
      case 'maquinas':
        return colorMorado;
      case 'accesorios':
      case 'accesorio':
        return colorAcento;
      case 'ferretería':
        return colorVerde1;
      case 'eléctrico':
        return colorAzul;
      default:
        return colorBlanco;
    }
  }

  Color _obtenerColorStock(int cantidad, int minimo) {
    if (cantidad == 0) {
      return Color(0xFF757575);
    } else if (cantidad <= minimo) {
      return colorAcento;
    } else {
      return Color(0xFF66BB6A);
    }
  }

  // --- LÓGICA DE GENERACIÓN DE REPORTE PDF DE FALTANTES Y STOCK BAJO ---
  Future<void> _generarDescargarReporteFaltantes() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: colorRosaVibrante))
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('insumos_inventario')
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        _mostrarSnackBar('No hay artículos registrados en el inventario.', Colors.orange);
        return;
      }

      final listaFaltantes = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'nombre': (data['nombre'] ?? 'N/A').toString().toUpperCase(),
          'categoria': (data['categoria'] ?? 'N/A').toString().toUpperCase(),
          'subcategoria': (data['subcategoria'] ?? 'N/A').toString().toUpperCase(),
          'unidad': (data['unidad_medida'] ?? '').toString(),
          'actual': int.tryParse(data['cantidad_disponible']?.toString() ?? '0') ?? 0,
          'minimo': int.tryParse(data['stock_minimo']?.toString() ?? '0') ?? 0,
        };
      }).where((insumo) {
        final int actual = insumo['actual'] as int;
        final int minimo = insumo['minimo'] as int;
        return actual <= minimo;
      }).toList();

      listaFaltantes.sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));

      if (listaFaltantes.isEmpty) {
        if (mounted) Navigator.pop(context);
        _mostrarSnackBar('¡Todo bien! No hay artículos agotados ni con stock bajo.', Colors.green);
        return;
      }

      String fechaStr = DateFormat('dd_MM_yyyy_HHmm').format(DateTime.now());
      String fechaDisplay = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final output = await getTemporaryDirectory();
      String pdfPath = "${output.path}/SaunaStilo_Faltantes_$fechaStr.pdf";

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SAUNASTILO - INVENTARIO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#090909"))),
                  pw.Text(fechaDisplay, style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(color: PdfColor.fromHex("#E040FB")),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('REPORTE DE REABASTECIMIENTO (STOCK BAJO Y CRÍTICO)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#FF3399"))),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['ARTÍCULO', 'CATEGORÍA', 'ST. ACTUAL', 'MÍNIMO', 'COMPRAR'].map((h) =>
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: (h == 'ARTÍCULO' || h == 'CATEGORÍA') ? pw.TextAlign.left : pw.TextAlign.center)
                      )
                    ).toList(),
                  ),
                  ...listaFaltantes.map((insumo) {
                    final int actual = insumo['actual'] as int;
                    final int minimo = insumo['minimo'] as int;
                    final int faltante = minimo - actual;
                    final String unidad = insumo['unidad'].toString();

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(insumo['nombre'].toString(), style: pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(insumo['categoria'].toString(), style: pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('$actual $unidad', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('$minimo $unidad', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${faltante <= 0 ? 1 : faltante} $unidad',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: actual == 0 ? PdfColors.red900 : PdfColors.amber900),
                            textAlign: pw.TextAlign.center
                          )
                        ),
                      ]
                    );
                  }).toList(),
                ],
              ),
            ];
          }
        )
      );

      await File(pdfPath).writeAsBytes(await pdf.save());

      if (mounted) Navigator.pop(context);
      ExternalTransfer.block(context);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error generando reporte: $e");
      _mostrarSnackBar('Error al generar PDF: $e', Colors.redAccent);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: color)
      );
    }
  }

  Widget _buildFilterChip(String label, Color color) {
    final bool seleccionado = _filtroStock == label;
    return ChoiceChip(
      label: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: seleccionado ? colorFondo : colorTextoPrimario.withOpacity(0.8),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      selected: seleccionado,
      selectedColor: color,
      backgroundColor: colorTarjeta,
      checkmarkColor: colorFondo,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: seleccionado ? color : StiloColors.text.withValues(alpha: .10),
          width: 1,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filtroStock = label;
          });
        }
      },
    );
  }

  void _mostrarImagenExpandida(BuildContext context, String imageUrl, String heroTag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: heroTag,
                child: InventoryPhoto(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(child: CircularProgressIndicator(color: colorRosaVibrante)),
                  errorWidget: (context, url, error) => Icon(Icons.broken_image, color: StiloColors.text.withValues(alpha: .54), size: 50),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: IconThemeData(color: colorTextoPrimario),
        title: !_estaBuscando
          ? Text(
              'INVENTARIO',
              style: GoogleFonts.inter(
                color: colorTextoPrimario,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            )
        : TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: StiloColors.text, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar nombre, código...', // Texto actualizado
                hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 15),
                border: InputBorder.none,
                // --- 3a. NUEVO: BOTONES DENTRO DEL BUSCADOR ---
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner, color: colorAcento),
                      onPressed: _escanearCodigo,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: StiloColors.text.withValues(alpha: .54)),
                      onPressed: () {
                        setState(() {
                          _estaBuscando = false;
                          _searchController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
      actions: [
          if (!_estaBuscando) ...[
            // --- 3b. NUEVO: BOTÓN DE ESCÁNER FUERA DEL BUSCADOR ---
            IconButton(
              icon: Icon(Icons.qr_code_scanner, color: colorAcento),
              tooltip: 'Escanear Código',
              onPressed: _escanearCodigo,
            ),
            IconButton(
              icon: Icon(Icons.search, color: colorTextoPrimario),
              tooltip: 'Buscar Insumo',
              onPressed: () {
                setState(() {
                  _estaBuscando = true;
                });
              },
            ),


        IconButton(
              icon: Icon(Icons.move_to_inbox, color: colorVerde1),
              tooltip: 'Recepción de Inventario',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RecepcionInventarioScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.picture_as_pdf, color: colorRosaVibrante),
              tooltip: 'Reporte Faltantes',
              onPressed: _generarDescargarReporteFaltantes, // Usualmente aquí pasas () => _generarDescargarReporteFaltantes()
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('insumos_inventario')
                  .where('en_reparacion', isGreaterThan: 0)
                  .snapshots(),
              builder: (context, snapshot) {
                int reparacionesPendientes = 0;
                if (snapshot.hasData) {
                  reparacionesPendientes = snapshot.data!.docs.length;
                }
                return IconButton(
                  icon: Badge(
                    isLabelVisible: reparacionesPendientes > 0,
                    label: Text(
                      reparacionesPendientes.toString(),
                      style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: colorRojoCoral,
                    child: Icon(Icons.handyman_outlined, color: Colors.orangeAccent),
                  ),
                  tooltip: 'Mantenimiento y Reparaciones',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminReparacionesScreen()),
                    );
                  },
                );
              },
            ),


          IconButton(
              icon: Icon(Icons.bookmarks_outlined, color: colorAcento),
              tooltip: 'Gestionar Categorías',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminCategoriasScreen()),
                );
              },
            ),
          ],
       ],
      ),


  body: StreamBuilder<List<InsumoModel>>(
        stream: _inventarioService.getInsumosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorTextoPrimario));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No hay insumos registrados.',
                style: TextStyle(color: colorAcento),
              ),
            );
          }


       final todosLosInsumos = snapshot.data!;

          var insumosFiltrados = todosLosInsumos.where((insumo) {
            final matchNombre = insumo.nombre.toLowerCase().contains(_searchText);
            final matchCategoria = insumo.categoria.toLowerCase().contains(_searchText);
            final matchSubcategoria = insumo.subcategoria.toLowerCase().contains(_searchText);

            // --- 4. NUEVO: AGREGAR EL CÓDIGO DE BARRAS AL FILTRO LOCAL ---
            final matchCodigo = (insumo.codigoBarras ?? '').toLowerCase().contains(_searchText);

            return matchNombre || matchCategoria || matchSubcategoria || matchCodigo;
          }).toList();

          if (_filtroStock == "Agotados") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible == 0).toList();
          } else if (_filtroStock == "Bajo") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible > 0 && i.cantidadDisponible <= i.stockMinimo).toList();
          } else if (_filtroStock == "Al Día") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible > i.stockMinimo).toList();
          }

          insumosFiltrados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));


          return Column(
            children: [
              if (MediaQuery.sizeOf(context).height > 650 && MediaQuery.textScalerOf(context).scale(1) < 1.5) Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8), child: WarehouseHeader(title: 'Todo en su lugar.', subtitle: 'Existencias · Herramientas · Insumos', compact: true)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildFilterChip("Todos", Colors.grey),
                    SizedBox(width: 8),
                    _buildFilterChip("Agotados", Color(0xFF757575)),
                    SizedBox(width: 8),
                    _buildFilterChip("Bajo", colorAcento),
                    SizedBox(width: 8),
                    _buildFilterChip("Al Día", Color(0xFF66BB6A)),
                  ],
                ),
              ),

              // --- LISTA DE INSUMOS ---
           Expanded(
                child: insumosFiltrados.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No hay insumos que coincidan con esta búsqueda.',
                          style: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )


                  : ListView.builder(
                      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                      itemCount: insumosFiltrados.length,
                      itemBuilder: (context, index) {
                        final insumo = insumosFiltrados[index];

                       return GestureDetector(
                          onTap: () {
                            // --- NUEVA NAVEGACIÓN A LA PANTALLA DE DETALLES ---
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InsumoDetalleScreen(insumo: insumo),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: StiloColors.background.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Barra de color lateral
                                  Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      color: _obtenerColorBarra(insumo.categoria),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                  ),

                                  // --- MINIATURA DE LA IMAGEN EN LA LISTA ---
                                  if (insumo.imagenUrl != null && insumo.imagenUrl!.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                      child: GestureDetector(
                                        onTap: () => _mostrarImagenExpandida(context, insumo.imagenUrl!, insumo.id),
                                        child: Hero(
                                          tag: insumo.id, // Vinculamos la animación con el ID único del insumo
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: InventoryPhoto(
                                              imageUrl: insumo.imagenUrl!,
                                              width: 65,
                                              height: 65,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 65, height: 65,
                                                color: StiloColors.text.withValues(alpha: .10),
                                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorRosaVibrante))
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: 65, height: 65,
                                                color: StiloColors.text.withValues(alpha: .10),
                                                child: Icon(Icons.broken_image, color: StiloColors.text.withValues(alpha: .54))
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                      child: Container(
                                        width: 65, height: 65,
                                        decoration: BoxDecoration(
                                          color: StiloColors.text.withValues(alpha: .10),
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Icon(Icons.inventory_2_outlined, color: StiloColors.text.withValues(alpha: .54), size: 28),
                                      ),
                                    ),

                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  insumo.nombre,
                                                  style: GoogleFonts.inter(
                                                    color: colorTextoPrimario,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              if (insumo.esProductoTienda)
                                                Icon(Icons.verified_outlined, color: Colors.amber, size: 22),
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            '${insumo.categoria.toUpperCase()} > ${insumo.subcategoria.toUpperCase()}',
                                            style: TextStyle(
                                              color: colorTextoPrimario.withOpacity(0.6),
                                              fontSize: 12,
                                              fontFamily: GoogleFonts.inter().fontFamily,
                                            ),
                                          ),
                                          SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _obtenerColorStock(insumo.cantidadDisponible, insumo.stockMinimo).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'STOCK: ${insumo.cantidadDisponible} ${insumo.unidadMedida}',
                                                    style: GoogleFonts.inter(
                                                      color: _obtenerColorStock(insumo.cantidadDisponible, insumo.stockMinimo),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11,
                                                      letterSpacing: 0.5,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),

                                              SizedBox(width: 8),

                                              // 2. AGRUPAMOS BOTONES DE EDITAR Y ELIMINAR
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: BoxConstraints(),
                                                    icon: Icon(Icons.edit_outlined, color: colorAzul, size: 22),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => InsumoFormScreen(
                                                            inventarioService: _inventarioService,
                                                            insumo: insumo,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  SizedBox(width: 12),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: BoxConstraints(),
                                                    icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                                    onPressed: () async {
                                                      final insumoRespaldado = insumo;
                                                      await _inventarioService.eliminarInsumo(insumo.id, imagenUrl: insumo.imagenUrl);

                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).clearSnackBars();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            backgroundColor: colorTarjeta,
                                                            duration: Duration(seconds: 4),
                                                            content: Text(
                                                              'Se eliminó "${insumoRespaldado.nombre}"',
                                                              style: GoogleFonts.inter(color: StiloColors.text),
                                                            ),
                                                            action: SnackBarAction(
                                                              label: 'DESHACER',
                                                              textColor: colorRosaVibrante,
                                                              onPressed: () async {
                                                                await _inventarioService.crearInsumo(insumoRespaldado);
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorBlanco,
        foregroundColor: colorFondo,
        elevation: 6,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InsumoFormScreen(
                inventarioService: _inventarioService,
              ),
            ),
          );
        },
        child: Icon(Icons.add, size: 28),
      ),
    );
  }
}
