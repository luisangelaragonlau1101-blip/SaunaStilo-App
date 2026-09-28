import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 IMPORTANTE PARA SABER QUIÉN ESTÁ LOGUEADO

import '../models/seguimiento_cotizaciones_model.dart';
import '../models/sauna_model.dart';
import '../providers/seguimiento_cotizaciones_provider.dart';

class NuevaCotizacionScreen extends StatefulWidget {
  final SeguimientoCotizacionModel? cotizacionAEditar;

  const NuevaCotizacionScreen({Key? key, this.cotizacionAEditar}) : super(key: key);

  @override
  State<NuevaCotizacionScreen> createState() => _NuevaCotizacionScreenState();
}

class _NuevaCotizacionScreenState extends State<NuevaCotizacionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  late TextEditingController _tituloController;
  late TextEditingController _descController;
  late TextEditingController _medidasController;
  late TextEditingController _montoController;

  // Controladores para cliente nuevo
  late TextEditingController _nombreClienteController;
  late TextEditingController _telefonoClienteController;
  late TextEditingController _direccionClienteController;

  // Controlador para la nota
  late TextEditingController _notaInicialController;

  bool _clienteEsNuevo = true;
  String? _idSaunaSeleccionado;
  String? _idClienteSeleccionado;

  bool _isLoadingCatalogos = true;
  bool _isGuardando = false;

  List<Sauna> _saunasCatalogo = [];
  List<DocumentSnapshot> _clientesExistentes = [];

  // 👈 VARIABLE PARA GUARDAR EL NOMBRE DEL ADMIN ACTUAL
  String _nombreAdminActual = 'Sin asignar';

  @override
  void initState() {
    super.initState();

    final editar = widget.cotizacionAEditar;

    _tituloController = TextEditingController(text: editar?.datosProyecto.titulo ?? '');
    _descController = TextEditingController(text: editar?.datosProyecto.descripcion ?? '');
    _medidasController = TextEditingController(text: editar?.datosProyecto.medidas ?? '');
    _montoController = TextEditingController(text: editar?.montoCotizado.toString() ?? '0.0');

    _nombreClienteController = TextEditingController(text: editar?.datosCliente.nombre ?? '');
    _telefonoClienteController = TextEditingController(text: editar?.datosCliente.telefono ?? '');
    _direccionClienteController = TextEditingController(text: editar?.datosCliente.direccion ?? '');

    _notaInicialController = TextEditingController();

    if (editar != null) {
      _clienteEsNuevo = editar.clienteEsNuevo;
      _idClienteSeleccionado = editar.idCliente.isNotEmpty ? editar.idCliente : null;
      _idSaunaSeleccionado = editar.datosProyecto.idSauna.isNotEmpty ? editar.datosProyecto.idSauna : null;
    }

    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _isLoadingCatalogos = true);
    try {
      // 1. CARGAMOS SAUNAS Y CLIENTES
      final saunasSnap = await FirebaseFirestore.instance.collection('cat_saunas').get();
      _saunasCatalogo = saunasSnap.docs.map((doc) => Sauna.fromFirestore(doc)).toList();

      final clientesSnap = await FirebaseFirestore.instance.collection('clientes').get();
      _clientesExistentes = clientesSnap.docs;

      // 2. 👇 IDENTIFICAMOS AL USUARIO ACTUAL
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Buscamos su documento en la colección de usuarios
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          _nombreAdminActual = userData['nombre'] ?? 'Admin';
        }
      }

      // Validación para edición
      if (widget.cotizacionAEditar != null) {
        bool saunaExiste = _saunasCatalogo.any((s) => s.id == _idSaunaSeleccionado);
        if (!saunaExiste) _idSaunaSeleccionado = null;

        if (!_clienteEsNuevo) {
          bool clienteExiste = _clientesExistentes.any((c) => c.id == _idClienteSeleccionado);
          if (!clienteExiste) _idClienteSeleccionado = null;
        }
      }

    } catch (e) {
      debugPrint("Error al cargar catálogos: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCatalogos = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descController.dispose();
    _medidasController.dispose();
    _montoController.dispose();
    _nombreClienteController.dispose();
    _telefonoClienteController.dispose();
    _direccionClienteController.dispose();
    _notaInicialController.dispose();
    super.dispose();
  }

  void _mostrarDialogoNuevoSauna() {
    final TextEditingController nuevoSaunaController = TextEditingController();
    bool guardandoNuevo = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: StiloColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Añadir Tipo de Madera", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              content: TextField(contextMenuBuilder: privacyTextMenu,
                controller: nuevoSaunaController,
                style: TextStyle(color: StiloColors.text),
                decoration: InputDecoration(
                  hintText: "Ej. Madera de Cedro...",
                  hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                  filled: true,
                  fillColor: StiloColors.surface,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: StiloColors.accent)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar", style: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StiloColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: guardandoNuevo ? null : () async {
                    String nombreNuevo = nuevoSaunaController.text.trim();
                    if (nombreNuevo.isEmpty) return;

                    setStateDialog(() => guardandoNuevo = true);

                    try {
                      DocumentReference docRef = await FirebaseFirestore.instance.collection('cat_saunas').add({
                        'nombre': nombreNuevo,
                        'descripcion': '',
                        'imagen_url': '',
                      });

                      Sauna nuevoSauna = Sauna(id: docRef.id, nombre: nombreNuevo, descripcion: '', imagenUrl: '');

                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          _saunasCatalogo.add(nuevoSauna);
                          _idSaunaSeleccionado = docRef.id;
                        });
                      }
                    } catch (e) {
                      setStateDialog(() => guardandoNuevo = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al crear: $e'), backgroundColor: Colors.redAccent)
                      );
                    }
                  },
                  child: guardandoNuevo
                    ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: StiloColors.text, strokeWidth: 2))
                    : Text("Guardar", style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _guardarCotizacion() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    if (_idSaunaSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un tipo de madera/sauna.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    if (!_clienteEsNuevo && _idClienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un cliente existente.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isGuardando = true);

    try {
      String idClienteFinal = '';
      String nombreClienteFinal = '';
      String telefonoClienteFinal = '';
      String direccionClienteFinal = '';

      if (_clienteEsNuevo) {
        nombreClienteFinal = _nombreClienteController.text.trim();
        telefonoClienteFinal = _telefonoClienteController.text.trim();
        direccionClienteFinal = _direccionClienteController.text.trim();
      } else {
        final docCliente = _clientesExistentes.firstWhere((doc) => doc.id == _idClienteSeleccionado);
        final datosClienteDb = docCliente.data() as Map<String, dynamic>;

        idClienteFinal = docCliente.id;
        nombreClienteFinal = datosClienteDb['nombre'] ?? 'Sin nombre';
        telefonoClienteFinal = datosClienteDb['telefono'] ?? '';
        direccionClienteFinal = datosClienteDb['direccion'] ?? '';
      }

      List<NotaSeguimiento> arregloNotas = widget.cotizacionAEditar != null
          ? List.from(widget.cotizacionAEditar!.notasSeguimiento)
          : [];

      if (_notaInicialController.text.trim().isNotEmpty) {
        arregloNotas.add(
          NotaSeguimiento(
            fecha: DateTime.now(),
            comentario: _notaInicialController.text.trim(),
            completada: false, // Nueva nota = tarea pendiente
          )
        );
      }

      final cotizacionFinal = SeguimientoCotizacionModel(
        id: widget.cotizacionAEditar?.id ?? '',
        // 👇 AQUÍ ASIGNAMOS AL ADMIN. Si estamos editando, conservamos al original. Si es nueva, ponemos al actual.
        adminEncargado: widget.cotizacionAEditar?.adminEncargado ?? _nombreAdminActual,
        clienteEsNuevo: _clienteEsNuevo,
        idCliente: idClienteFinal,
        estatusCotizacion: widget.cotizacionAEditar?.estatusCotizacion ?? 'PENDIENTE',
        fechaCotizacion: widget.cotizacionAEditar?.fechaCotizacion ?? DateTime.now(),
        montoCotizado: double.tryParse(_montoController.text.trim()) ?? 0.0,
        datosCliente: DatosCliente(
          nombre: nombreClienteFinal,
          telefono: telefonoClienteFinal,
          direccion: direccionClienteFinal,
        ),
        datosProyecto: DatosProyecto(
          titulo: _tituloController.text.trim(),
          descripcion: _descController.text.trim(),
          idSauna: _idSaunaSeleccionado!,
          medidas: _medidasController.text.trim(),
        ),
        notasSeguimiento: arregloNotas,
      );

      if (widget.cotizacionAEditar == null) {
        await FirebaseFirestore.instance.collection('seguimiento_cotizaciones').add(cotizacionFinal.toJson());
      } else {
        await FirebaseFirestore.instance.collection('seguimiento_cotizaciones').doc(cotizacionFinal.id).update(cotizacionFinal.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cotizacionAEditar == null ? 'Cotización creada con éxito' : 'Cotización actualizada con éxito'),
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    List<DropdownMenuItem<String>> itemsSaunas = _saunasCatalogo.map((sauna) {
      return DropdownMenuItem<String>(
        value: sauna.id,
        child: Text(sauna.nombre, style: TextStyle(color: StiloColors.text)),
      );
    }).toList();

    itemsSaunas.add(
      DropdownMenuItem<String>(
        value: 'ADD_NEW',
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: StiloColors.accent, size: 20),
            SizedBox(width: 8),
            Text("Añadir nuevo...", style: TextStyle(color: StiloColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    List<DropdownMenuItem<String>> itemsClientes = _clientesExistentes.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final nombre = data['nombre'] ?? 'Sin nombre';
      return DropdownMenuItem<String>(
        value: doc.id,
        child: Text(nombre, style: TextStyle(color: StiloColors.text)),
      );
    }).toList();

    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        title: Text(
          widget.cotizacionAEditar == null ? "NUEVA COTIZACIÓN" : "EDITAR COTIZACIÓN",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold)
        ),
        centerTitle: true
      ),
      body: _isLoadingCatalogos
        ? Center(child: CircularProgressIndicator(color: StiloColors.accent))
        : Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              _buildSectionTitle("DATOS DEL CLIENTE", Color(0xFF06B6D4)),
              Container(
                decoration: BoxDecoration(
                  color: StiloColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text('¿Es cliente nuevo?', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _clienteEsNuevo ? 'Se pedirá capturar sus datos.' : 'Se seleccionará de la base de datos.',
                    style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)
                  ),
                  value: _clienteEsNuevo,
                  activeColor: Color(0xFF06B6D4),
                  onChanged: (val) => setState(() => _clienteEsNuevo = val),
                ),
              ),
              SizedBox(height: 16),

              if (_clienteEsNuevo) ...[
                _buildTextField(_nombreClienteController, "Nombre Completo", Icons.person, Color(0xFF06B6D4)),
                SizedBox(height: 12),
                _buildTextField(_telefonoClienteController, "Teléfono", Icons.phone, Color(0xFF06B6D4), keyboardType: TextInputType.phone),
                SizedBox(height: 12),
                _buildTextField(_direccionClienteController, "Dirección Completa", Icons.location_on, Color(0xFF06B6D4), maxLines: 2),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _idClienteSeleccionado,
                  dropdownColor: StiloColors.surface,
                  decoration: _inputDecoration("Selecciona un Cliente", Icons.people_alt, Color(0xFF06B6D4)),
                  items: itemsClientes.isEmpty
                      ? [DropdownMenuItem(value: null, child: Text('No hay clientes', style: TextStyle(color: StiloColors.text.withValues(alpha: .54))))]
                      : itemsClientes,
                  onChanged: (val) => setState(() => _idClienteSeleccionado = val),
                  validator: (val) => val == null ? 'Selecciona un cliente de la lista' : null,
                ),
              ],

              SizedBox(height: 32),

              _buildSectionTitle("DATOS DEL PROYECTO", StiloColors.accent),
              _buildTextField(_tituloController, "Título (Ej. PRUEBA 1)", Icons.title, StiloColors.accent),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _idSaunaSeleccionado,
                dropdownColor: StiloColors.surface,
                decoration: _inputDecoration("Tipo de Madera / Sauna", Icons.hot_tub, StiloColors.accent),
                items: itemsSaunas,
                onChanged: (val) {
                  if (val == 'ADD_NEW') {
                    _mostrarDialogoNuevoSauna();
                  } else {
                    setState(() => _idSaunaSeleccionado = val);
                  }
                },
              ),
              SizedBox(height: 12),
              _buildTextField(_medidasController, "Medidas (Ej. 1.10 x 1.10)", Icons.straighten, StiloColors.accent),
              SizedBox(height: 12),
              _buildTextField(_descController, "Descripción Adicional", Icons.description, StiloColors.accent, maxLines: 3, esObligatorio: false),
              SizedBox(height: 32),

              _buildSectionTitle("COTIZACIÓN", Color(0xFFFFDE21)),
              _buildFinanzasField(_montoController, "Monto Total Cotizado", Icons.request_quote),
              SizedBox(height: 32),

              _buildSectionTitle("NUEVA TAREA O NOTA", Color(0xFFF59E0B)),
              _buildTextField(
                _notaInicialController,
                widget.cotizacionAEditar == null ? "Tarea inicial (Opcional)" : "Agrega una nueva tarea aquí",
                Icons.task_alt,
                Color(0xFFF59E0B),
                maxLines: 3,
                esObligatorio: false
              ),
              SizedBox(height: 40),

              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [StiloColors.accent, Color(0xFF6D28D9)])
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  onPressed: _isGuardando ? null : _guardarCotizacion,
                  child: _isGuardando
                    ? CircularProgressIndicator(color: StiloColors.text)
                    : Text(
                        widget.cotizacionAEditar == null ? "CREAR COTIZACIÓN" : "GUARDAR CAMBIOS",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StiloColors.text)
                      ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
    );
  }

  // --- Widgets Auxiliares ---
  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: 4),
      child: Row(children: [
        Icon(Icons.label_important, color: color, size: 16),
        SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5))
      ])
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color iconColor) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
      prefixIcon: Icon(icon, color: iconColor),
      filled: true,
      fillColor: StiloColors.surface,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: iconColor, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent, width: 2)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color iconColor, {int maxLines = 1, bool esObligatorio = true, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: StiloColors.text),
      decoration: _inputDecoration(label, icon, iconColor),
      validator: esObligatorio ? (v) => v == null || v.trim().isEmpty ? "Este campo es obligatorio" : null : null
    );
  }

  Widget _buildFinanzasField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: Color(0xFFFFDE21), fontWeight: FontWeight.bold),
      decoration: _inputDecoration(label, icon, Color(0xFFFFDE21)),
      onTap: () {
        if (controller.text == '0.0' || controller.text == '0') {
          controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
        }
      },
      validator: (v) => (v == null || double.tryParse(v) == null) ? "Ingresa un número válido" : null,
    );
  }
}
