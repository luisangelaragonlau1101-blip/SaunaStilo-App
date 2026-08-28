import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventario_service.dart';
import '../models/insumo_model.dart';

// --- IMPORTS PARA PDF Y EXPORTACIÓN ---
import 'dart:io'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// --- 1. NUEVO: IMPORTS PARA EL ESCÁNER, SONIDO Y VIBRACIÓN ---
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

// Clase auxiliar para manejar el estado de cada fila en la "mesa de trabajo"
class ItemRecepcion {
  final InsumoModel insumo;
  final TextEditingController cantidadController;

  ItemRecepcion({required this.insumo}) 
      : cantidadController = TextEditingController(text: '1'); // Por defecto llega 1
}

class RecepcionInventarioScreen extends StatefulWidget {
  const RecepcionInventarioScreen({super.key});

  @override
  State<RecepcionInventarioScreen> createState() => _RecepcionInventarioScreenState();
}

class _RecepcionInventarioScreenState extends State<RecepcionInventarioScreen> {
  final InventarioService _inventarioService = InventarioService();
  
  // Colores de tu UI
  static const Color colorFondo = Color(0xFF121212); 
  static const Color colorTarjeta = Color(0xFF1E1E1E); 
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorAzul = Color(0xFF00B0FF);      
  static const Color colorRosaVibrante = Color(0xFFFF3399);
  static const Color colorAcento = Color(0xFFFFDE21); // Agregado para el ícono del escáner

  List<InsumoModel> _catalogoInsumos = [];
  final List<ItemRecepcion> _listaCarga = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    for (var item in _listaCarga) {
      item.cantidadController.dispose();
    }
    super.dispose();
  }

  // Cargamos todos los insumos una sola vez para que el buscador sea instantáneo
  Future<void> _cargarCatalogo() async {
    _inventarioService.getInsumosStream().listen((insumos) {
      if (mounted) {
        setState(() {
          _catalogoInsumos = insumos;
          _cargando = false;
        });
      }
    });
  }

  void _agregarAListaCarga(InsumoModel insumoSeleccionado) {
    // Evitar que lo agreguen dos veces a la lista temporal
    if (_listaCarga.any((item) => item.insumo.id == insumoSeleccionado.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${insumoSeleccionado.nombre} ya está en la lista. Si deseas agregar más, edita su cantidad.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        )
      );
      return;
    }

    setState(() {
      _listaCarga.insert(0, ItemRecepcion(insumo: insumoSeleccionado));
    });
  }

  // --- 2. NUEVO: FUNCIÓN PARA ESCANEAR Y AGREGAR DIRECTO A LA LISTA ---
  Future<void> _escanearYAgregarCodigo() async {
    try {
      String? res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (res != null && res != '-1') {
        // Reproducir sonido y vibrar
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/beep.ogg'));
        HapticFeedback.heavyImpact();

        // Buscar el producto en el catálogo por su código de barras
        try {
          final insumoEncontrado = _catalogoInsumos.firstWhere(
            (insumo) => insumo.codigoBarras == res,
          );
          
          // Si lo encuentra, lo agrega a la mesa de trabajo
          _agregarAListaCarga(insumoEncontrado);

        } catch (e) {
          // Si firstWhere da error, es porque no existe ningún producto con ese código
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Código no reconocido. El artículo no existe en el inventario.'),
                backgroundColor: Colors.redAccent,
              )
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al escanear: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _removerDeLista(int index) {
    setState(() {
      _listaCarga[index].cantidadController.dispose();
      _listaCarga.removeAt(index);
    });
  }

  Future<void> _confirmarEntradaMasiva() async {
    if (_listaCarga.isEmpty) return;

    Map<String, int> insumosAActualizar = {};
    for (var item in _listaCarga) {
      int cant = int.tryParse(item.cantidadController.text) ?? 0;
      if (cant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revisa la cantidad de: ${item.insumo.nombre}'),
            backgroundColor: Colors.redAccent,
          )
        );
        return; 
      }
      insumosAActualizar[item.insumo.id] = cant;
    }

    setState(() => _guardando = true);

    try {
      // 1. Actualizas el inventario en Firebase
      await _inventarioService.recepcionMasivaInsumos(insumosAActualizar);

      // 2. Respaldamos la lista y la fecha actual para el PDF local
      final listaRespaldada = List<ItemRecepcion>.from(_listaCarga);
      final fechaActual = DateTime.now();

      if (mounted) {
        setState(() {
          _guardando = false;
          _listaCarga.clear(); // Vaciamos la mesa de trabajo
        });

        // 3. Mostramos el diálogo de éxito con la opción del PDF
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: colorTarjeta,
            title: Text('¡Entrada Exitosa!', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold)),
            content: const Text('El material se ha sumado al inventario correctamente.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  Navigator.pop(context); // Regresa a la pantalla principal
                },
                child: const Text('SALIR', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: colorAzul),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                label: const Text('GENERAR COMPROBANTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo para mostrar el cargando del PDF
                  _generarDescargarComprobante(listaRespaldada, fechaActual);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent)
        );
        setState(() => _guardando = false);
      }
    }
  }

  // --- LÓGICA DE GENERACIÓN DE COMPROBANTE DE ENTRADA ---
  Future<void> _generarDescargarComprobante(List<ItemRecepcion> itemsRegistrados, DateTime fecha) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: colorAzul))
    );

    try {
      String fechaStr = DateFormat('dd_MM_yyyy_HHmm').format(fecha);
      String fechaDisplay = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
      
      final output = await getTemporaryDirectory();
      String pdfPath = "${output.path}/SaunaStilo_Entrada_$fechaStr.pdf";

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SAUNASTILO - INVENTARIO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#090909"))),
                  pw.Text(fechaDisplay, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(color: PdfColor.fromHex("#00B0FF")), // Usamos tu color azul
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('COMPROBANTE DE RECEPCIÓN DE MATERIAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#00B0FF"))),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),   
                  1: pw.FlexColumnWidth(2),   
                  2: pw.FlexColumnWidth(1.5), 
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['ARTÍCULO', 'CATEGORÍA', 'CANT. INGRESADA'].map((h) => 
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5), 
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: h == 'CANT. INGRESADA' ? pw.TextAlign.center : pw.TextAlign.left)
                      )
                    ).toList(),
                  ),
                  ...itemsRegistrados.map((item) {
                    final String unidad = item.insumo.unidadMedida;
                    final String cant = item.cantidadController.text;

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.insumo.nombre, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.insumo.categoria.toUpperCase(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5), 
                          child: pw.Text(
                            '+$cant $unidad', 
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#33CC33")), // Verde
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
      
      if (mounted) Navigator.pop(context); // Quita el loader
      
      // Compartir o abrir el archivo
      await Share.shareXFiles([XFile(pdfPath, mimeType: 'application/pdf')], text: 'Comprobante de Recepción - $fechaDisplay');
      
      // Regresamos a la pantalla principal de inventario después de compartir
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error generando comprobante: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.redAccent)
      );
    }
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
          'RECEPCIÓN DE INVENTARIO',
          style: GoogleFonts.inter(
            color: colorTextoPrimario,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator(color: colorRosaVibrante))
        : Column(
            children: [
              // --- BUSCADOR INTELIGENTE ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  border: const Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Autocomplete<InsumoModel>(
                  displayStringForOption: (InsumoModel option) => option.nombre,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<InsumoModel>.empty();
                    }
                    return _catalogoInsumos.where((insumo) {
                      return insumo.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                             insumo.categoria.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (InsumoModel seleccion) {
                    _agregarAListaCarga(seleccion);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar (Ej. Filtro, Martillo...)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: colorAzul),
                        
                        // --- 3. NUEVO: BOTÓN DE ESCÁNER EN EL BUSCADOR ---
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: colorAcento),
                          tooltip: 'Escanear herramienta',
                          onPressed: _escanearYAgregarCodigo,
                        ),
                        // -------------------------------------------------
                        
                        filled: true,
                        fillColor: colorFondo,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 32,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: colorTarjeta,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorAzul.withOpacity(0.5)),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final InsumoModel option = options.elementAt(index);
                              return ListTile(
                                title: Text(option.nombre, style: const TextStyle(color: Colors.white)),
                                subtitle: Text('Stock actual: ${option.cantidadDisponible}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                onTap: () {
                                  onSelected(option);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- MESA DE TRABAJO (LISTA TEMPORAL) ---
              Expanded(
                child: _listaCarga.isEmpty
                    ? const Center(
                        child: Text(
                          'Busca o escanea los\nartículos que acaban de llegar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _listaCarga.length,
                        itemBuilder: (context, index) {
                          final item = _listaCarga[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.insumo.nombre,
                                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Stock actual: ${item.insumo.cantidadDisponible}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Input de cantidad a sumar
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: item.cantidadController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: colorRosaVibrante, fontWeight: FontWeight.bold, fontSize: 18),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      filled: true,
                                      fillColor: colorFondo,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    onTap: () {
                                      // Selecciona todo el texto al hacer clic para editar rápido
                                      item.cantidadController.selection = TextSelection(baseOffset: 0, extentOffset: item.cantidadController.text.length);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _removerDeLista(index),
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // --- BOTÓN MAESTRO DE GUARDADO ---
              if (_listaCarga.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorTarjeta,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorAzul,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _guardando ? null : _confirmarEntradaMasiva,
                    child: _guardando 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'CONFIRMAR ENTRADA (${_listaCarga.length} items)',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          ),
                  ),
                )
            ],
          ),
    );
  }
}