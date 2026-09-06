import '../widgets/warehouse_header.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/inventario_service.dart';
import '../models/insumo_model.dart';

// --- IMPORT PARA EL ESCÁNER ---
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

// --- NUEVOS IMPORTS PARA SONIDO Y VIBRACIÓN ---
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class InsumoFormScreen extends StatefulWidget {
  final InventarioService inventarioService;
  final InsumoModel? insumo; 
  
  const InsumoFormScreen({super.key, required this.inventarioService, this.insumo});

  @override
  State<InsumoFormScreen> createState() => _InsumoFormScreenState();
}

class _InsumoFormScreenState extends State<InsumoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreController = TextEditingController();
  final _descController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _unidadController = TextEditingController();
  final _minController = TextEditingController();
  final _precioController = TextEditingController(text: '0.0');
  
  // --- 2a. NUEVO: CONTROLADOR DEL CÓDIGO DE BARRAS ---
  final _codigoBarrasController = TextEditingController();

  String? _categoriaSeleccionada;
  String? _subcategoriaSeleccionada;
  bool _esProductoTienda = false;

  // --- VARIABLES PARA IMAGEN Y CARGA ---
  Uint8List? _imagenBytes;
  String? _urlImagenActual;
  bool _isSaving = false; 

  late Future<List<String>> _categoriasFuture;

  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF111012);
  static const Color colorRosa = Color(0xFFC798FF);
  static const Color colorAzul = Color(0xFFC798FF);
  static const Color colorRosaVibrante = Color(0xFFFF729C);
  static const Color colorAcento = Color(0xFFB7FF2A); // Agregado para el botón del escáner

  @override
  void initState() {
    super.initState();
    _cargarListas();

    if (widget.insumo != null) {
      _nombreController.text = widget.insumo!.nombre;
      _descController.text = widget.insumo!.descripcion;
      _cantidadController.text = widget.insumo!.cantidadDisponible.toString();
      _unidadController.text = widget.insumo!.unidadMedida;
      _minController.text = widget.insumo!.stockMinimo.toString();
      _categoriaSeleccionada = widget.insumo!.categoria.toLowerCase();
      _subcategoriaSeleccionada = widget.insumo!.subcategoria;
      _esProductoTienda = widget.insumo!.esProductoTienda;
      _precioController.text = (widget.insumo!.precio ?? 0.0).toStringAsFixed(2);
      _urlImagenActual = widget.insumo!.imagenUrl;
      
      // --- 2b. NUEVO: INICIALIZAR EL CONTROLADOR SI ESTAMOS EDITANDO ---
      _codigoBarrasController.text = widget.insumo!.codigoBarras ?? '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descController.dispose();
    _cantidadController.dispose();
    _unidadController.dispose();
    _minController.dispose();
    _precioController.dispose(); 
    _codigoBarrasController.dispose(); // --- 2c. NUEVO: LIMPIAR MEMORIA ---
    super.dispose();
  }

  void _cargarListas() {
    _categoriasFuture = widget.inventarioService.getCategoriasList();
  }

Future<void> _escanearCodigoFormulario() async {
    try {
      String? res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (res != null && res != '-1') {
        
        // --- 1. AQUÍ AGREGAMOS EL SONIDO Y LA VIBRACIÓN ---
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/beep.ogg'));
        HapticFeedback.heavyImpact(); 
        // --------------------------------------------------

        setState(() {
          _codigoBarrasController.text = res;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al escanear: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _crearNuevaOpcionDialog(bool esCategoria) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        backgroundColor: colorTarjeta,
        title: Text(
          esCategoria ? 'NUEVA CATEGORÍA' : 'NUEVA SUBCATEGORÍA',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre',
            labelStyle: TextStyle(color: Colors.white70),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorRosaVibrante)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus(); 
              Navigator.pop(context);
            },
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              String nombreNuevo = textController.text.trim();
              FocusScope.of(context).unfocus(); 

              if (nombreNuevo.isNotEmpty) {
                if (esCategoria) {
                  await widget.inventarioService.crearCategoria(nombreNuevo);
                  setState(() {
                    _categoriasFuture = widget.inventarioService.getCategoriasList(); 
                    _categoriaSeleccionada = nombreNuevo.toLowerCase(); 
                    _subcategoriaSeleccionada = null; 
                  });
                } else {
                  await widget.inventarioService.crearSubcategoria(nombreNuevo, _categoriaSeleccionada ?? 'general');
                  setState(() {
                    _subcategoriaSeleccionada = nombreNuevo; 
                  });
                }
              }
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) Navigator.pop(context);
              });
            },
            child: const Text('GUARDAR', style: TextStyle(color: colorRosaVibrante, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.insumo != null;

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          esEdicion ? 'EDITAR INSUMO' : 'NUEVO INSUMO', 
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Oculta el teclado al tocar fuera
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WarehouseHeader(title: esEdicion ? 'Actualiza tu inventario' : 'Registra una herramienta', subtitle: 'Foto, identificación y existencias en un solo lugar.'),
                const SizedBox(height: 22),
                Center(child: _buildImageSelector()),
                const SizedBox(height: 30),

                // --- 4. NUEVO: CAMPO DE CÓDIGO DE BARRAS EN LA UI ---
                TextFormField(
                  controller: _codigoBarrasController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Código de Barras (Opcional)',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: colorRosaVibrante), borderRadius: BorderRadius.circular(20)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: colorAcento),
                      tooltip: 'Escanear Código',
                      onPressed: _escanearCodigoFormulario,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                _buildTextField(_nombreController, 'Nombre del Insumo'),
                const SizedBox(height: 15),

                FutureBuilder<List<String>>(
                  future: _categoriasFuture,
                  builder: (context, snapshot) {
                    List<DropdownMenuItem<String>> menuItems = [];
                    List<String> opcionesFirestore = snapshot.data ?? [];

                    if (snapshot.hasData) {
                      menuItems = opcionesFirestore.map((e) => DropdownMenuItem(
                        value: e.toLowerCase(), 
                        child: Text(
                          e.toUpperCase(), 
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis, 
                        )
                      )).toList();
                    }
                    menuItems.add(const DropdownMenuItem(
                      value: 'NUEVA_CAT',
                      child: Text('+ CREAR NUEVA...', style: TextStyle(color: colorRosaVibrante, fontWeight: FontWeight.bold)),
                    ));

                    String? valorActual = _categoriaSeleccionada;
                    if (valorActual != null && valorActual != 'NUEVA_CAT' && !opcionesFirestore.map((e) => e.toLowerCase()).contains(valorActual)) {
                      valorActual = null;
                    }
                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: colorTarjeta,
                      menuMaxHeight: 250, 
                      value: valorActual, 
                      decoration: _inputDecoration('Categoría'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                      items: menuItems,
                      onChanged: (val) {
                        if (val == 'NUEVA_CAT') {
                          _crearNuevaOpcionDialog(true);
                        } else {
                          setState(() {
                            _categoriaSeleccionada = val;
                            _subcategoriaSeleccionada = null; 
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),

                FutureBuilder<List<String>>(
                  future: _categoriaSeleccionada == null 
                      ? Future.value(<String>[]) 
                      : widget.inventarioService.getSubcategoriasListFiltradas(_categoriaSeleccionada!),
                  builder: (context, snapshot) {
                    List<DropdownMenuItem<String>> menuItems = [];
                    List<String> opcionesFiltradas = snapshot.data ?? [];

                    if (snapshot.hasData && _categoriaSeleccionada != null) {
                      menuItems = opcionesFiltradas
                          .map((e) => DropdownMenuItem(
                            value: e, 
                            child: Text(
                              e, 
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            )
                          ))
                          .toList();
                    }

                    if (_categoriaSeleccionada != null) {
                      menuItems.add(const DropdownMenuItem(
                        value: 'NUEVA_SUB',
                        child: Text('+ CREAR NUEVA...', style: TextStyle(color: colorRosaVibrante, fontWeight: FontWeight.bold)),
                      ));
                    }

                    String? valorActual = _subcategoriaSeleccionada;
                    if (valorActual != null && valorActual != 'NUEVA_SUB' && !opcionesFiltradas.contains(valorActual)) {
                      valorActual = null;
                    }

                  return DropdownButtonFormField<String>(
                      isExpanded: true, 
                      dropdownColor: colorTarjeta,
                      menuMaxHeight: 250, 
                      value: valorActual, 
                      disabledHint: const Text(
                        'Selecciona una categoría primero', 
                        style: TextStyle(color: Colors.white38),
                        overflow: TextOverflow.ellipsis,
                      ),
                      decoration: _inputDecoration('Subcategoría'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                      items: _categoriaSeleccionada == null ? null : menuItems,
                      onChanged: _categoriaSeleccionada == null ? null : (val) {
                        if (val == 'NUEVA_SUB') {
                          _crearNuevaOpcionDialog(false);
                        } else {
                          setState(() => _subcategoriaSeleccionada = val);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),

                _buildTextField(_descController, 'Descripción', isObligatorio: false),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(child: _buildTextField(_cantidadController, 'Cantidad', isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_unidadController, 'Unidad (m, kg, pz)')),
                  ],
                ),
                const SizedBox(height: 15),

                _buildTextField(_minController, 'Stock Mínimo', isNumber: true),
                const SizedBox(height: 10),
                
                CheckboxListTile(
                  title: const Text("¿Es producto de la tienda online?", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _esProductoTienda,
                  activeColor: colorRosa,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _esProductoTienda = val!),
                ),

                if (_esProductoTienda) ...[
                  const SizedBox(height: 10),
                  _buildPrecioField(_precioController, 'Precio del Producto en Tienda (\$)', isNumber: true),
                ],

                const SizedBox(height: 40),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorAzul,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _isSaving ? null : _guardarInsumo, // Se desactiva si está guardando
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        esEdicion ? 'ACTUALIZAR INSUMO' : 'GUARDAR EN INVENTARIO', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                      ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: colorRosaVibrante), borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, bool isObligatorio = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: isObligatorio 
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Este campo es obligatorio';
              }
              return null;
            }
          : null,
    );
  }
  
  Widget _buildPrecioField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Color(0xFFB7FF2A), fontWeight: FontWeight.bold),
      decoration: _inputDecoration(label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Este campo es obligatorio';
        if (double.tryParse(value) == null) return 'Ingresa una cantidad válida';
        return null;
      },
      onTap: () {
        if (controller.text == '0.0' || controller.text == '0') {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      },
    );
  }

  void _guardarInsumo() async {
    FocusScope.of(context).unfocus(); 

    bool esFormularioValido = _formKey.currentState!.validate();

    if (esFormularioValido) {
      String nombreIngresado = _nombreController.text.trim();

      if (nombreIngresado.isEmpty) return;

      // --- VALIDACIÓN DE NOMBRE ÚNICO ---
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: colorRosaVibrante)),
      );

      bool duplicado = await widget.inventarioService.existeNombreInsumo(
        nombreIngresado,
        excluirId: widget.insumo?.id, 
      );

      if (mounted) Navigator.pop(context); 

      if (duplicado) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: colorTarjeta,
              title: Text(
                '¡ELEMENTO DUPLICADO!',
                style: GoogleFonts.inter(color: const Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            content: Text(
              'Ya existe un insumo o herramienta con el nombre "$nombreIngresado" en el inventario.\n\nPor favor, usa un nombre diferente o edita el stock del elemento existente.',
              style: const TextStyle(color: Colors.white70, fontSize: 14), 
            ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ENTENDIDO', style: TextStyle(color: colorRosaVibrante, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return; 
      }
      // --- FIN DE LA VALIDACIÓN ---

      double precioValue = double.tryParse(_precioController.text.trim()) ?? 0.0;
      
      // --- 5a. NUEVO: OBTENER EL VALOR DEL CÓDIGO DE BARRAS ---
      String? codigoFinal = _codigoBarrasController.text.trim();
      if (codigoFinal.isEmpty) codigoFinal = null;

      // --- INICIA GUARDADO (AQUÍ SUBIMOS LA IMAGEN) ---
      setState(() => _isSaving = true); // Bloqueamos el botón

      try {
        String? urlFinal = _urlImagenActual; // Por defecto se queda la que tenía

        // Si el usuario seleccionó una NUEVA imagen
        if (_imagenBytes != null) {
          // Preserve the previous photo until the new record is saved.
          urlFinal = await widget.inventarioService.subirImagenInsumoBytes(_imagenBytes!, nombreIngresado);
        }

        if (widget.insumo != null) {
          Map<String, dynamic> datosActualizados = {
            'categoria': _categoriaSeleccionada!,
            'subcategoria': _subcategoriaSeleccionada ?? 'General',
            'nombre': nombreIngresado,
            'descripcion': _descController.text,
            'cantidad_disponible': int.tryParse(_cantidadController.text) ?? 0,
            'unidad_medida': _unidadController.text,
            'stock_minimo': int.tryParse(_minController.text) ?? 0,
            'es_producto_tienda': _esProductoTienda,
            'precio': _esProductoTienda ? precioValue : 0.0, 
            'imagen_url': urlFinal, 
            'codigo_barras': codigoFinal, // --- 5b. NUEVO: GUARDAR EN ACTUALIZACIÓN ---
          };

          await widget.inventarioService.editarInsumo(widget.insumo!.id, datosActualizados); 
        } else {
          InsumoModel nuevo = InsumoModel(
            id: '', 
            categoria: _categoriaSeleccionada!,
            subcategoria: _subcategoriaSeleccionada ?? 'General',
            nombre: nombreIngresado,
            descripcion: _descController.text,
            cantidadDisponible: int.tryParse(_cantidadController.text) ?? 0,
            unidadMedida: _unidadController.text,
            stockMinimo: int.tryParse(_minController.text) ?? 0,
            ultimaActualizacion: DateTime.now(),
            esProductoTienda: _esProductoTienda,
            precio: _esProductoTienda ? precioValue : 0.0,
            imagenUrl: urlFinal, 
            codigoBarras: codigoFinal, // --- 5c. NUEVO: GUARDAR EN CREACIÓN ---
          );

          await widget.inventarioService.crearInsumo(nuevo);
        }

        if (mounted) Navigator.pop(context); // Regresa a la pantalla anterior al terminar con éxito
      } catch (e) {
        print("Error al guardar: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickInventoryPhoto(ImageSource source) async {
    if (_isSaving) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) throw StateError('Usa una foto de menos de 8 MB.');
      if (mounted) setState(() => _imagenBytes = bytes);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer la foto. Revisa el permiso y elige una imagen de menos de 8 MB.')));
    }
  }
  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorTarjeta,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: colorRosaVibrante),
                title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickInventoryPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: colorAzul),
                title: const Text('Elegir de Galería', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickInventoryPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: _mostrarOpcionesImagen,
      child: Container(
        height: 140, // Ligeramente más grande para que luzca mejor en pantalla completa
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorRosaVibrante.withOpacity(0.5), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: _imagenBytes != null
              ? Image.memory(_imagenBytes!, fit: BoxFit.cover)
              : (_urlImagenActual != null && _urlImagenActual!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: _urlImagenActual!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: colorRosaVibrante)),
                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white54),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white54, size: 35),
                        SizedBox(height: 8),
                        Text('Agregar foto', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
        ),
      ),
    );
  }
}