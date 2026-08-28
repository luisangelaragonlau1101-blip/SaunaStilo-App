import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/proyecto_model.dart';
import '../models/cliente_model.dart';
import '../models/sauna_model.dart';
import '../models/user_model.dart';
import '../services/proyecto_service.dart';

class CrearProyectoAdminScreen extends StatefulWidget {
  const CrearProyectoAdminScreen({Key? key}) : super(key: key);

  @override
  _CrearProyectoAdminScreenState createState() => _CrearProyectoAdminScreenState();
}

class _CrearProyectoAdminScreenState extends State<CrearProyectoAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proyectoService = ProyectoService();
  
  late TextEditingController _tituloController;
  late TextEditingController _medidasController;
  late TextEditingController _descController;
  late TextEditingController _lugarEntregaController; 
  
  // CONTROLADORES FINANCIEROS
  late TextEditingController _cotizacionController; 
  late TextEditingController _pagoInicialController; 

  String _estatusSeleccionado = 'pendiente'; 
  late DateTime _fechaInicio;
  late DateTime _fechaEntrega;
  DateTime? _fechaSalidaInstalacion; // <-- NUEVO: Fecha opcional para logística
  
  String? _idClienteSeleccionado;
  String? _idSaunaSeleccionado;
  List<String> _encargadosSeleccionados = [];

  bool _isLoadingCatalogos = true;
  bool _isGuardando = false; 
  
  List<ClienteModel> _clientesCatalogo = [];
  List<Sauna> _saunasCatalogo = [];
  List<UserModel> _trabajadoresCatalogo = [];

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController();
    _medidasController = TextEditingController();
    _descController = TextEditingController();
    _lugarEntregaController = TextEditingController(); 
    _cotizacionController = TextEditingController(text: '0.0');
    _pagoInicialController = TextEditingController(text: '0.0');
    
    _fechaInicio = DateTime.now();
    _fechaEntrega = DateTime.now().add(const Duration(days: 7));
    // _fechaSalidaInstalacion se inicializa como nulo automáticamente

    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _isLoadingCatalogos = true);
    try {
      final clientesSnap = await FirebaseFirestore.instance.collection('clientes').get();
      _clientesCatalogo = clientesSnap.docs.map((doc) => ClienteModel.fromJson(doc.id, doc.data())).toList();

      final saunasSnap = await FirebaseFirestore.instance.collection('cat_saunas').get();
      _saunasCatalogo = saunasSnap.docs.map((doc) => Sauna.fromFirestore(doc)).toList();

      final usuariosSnap = await FirebaseFirestore.instance.collection('usuarios').get();
      _trabajadoresCatalogo = usuariosSnap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Error al cargar catálogos: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCatalogos = false);
    }
  }

  void _actualizarLugarEntrega(String idCliente) {
    try {
      final cliente = _clientesCatalogo.firstWhere((c) => c.id == idCliente);
      _lugarEntregaController.text = cliente.direccion; 
    } catch (e) {
      _lugarEntregaController.text = ''; 
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _medidasController.dispose();
    _descController.dispose();
    _lugarEntregaController.dispose();
    _cotizacionController.dispose();
    _pagoInicialController.dispose();
    super.dispose();
  }

 Future<void> _pickDateTime(String tipoFecha) async {
    // 👇 NUEVO: Cerramos cualquier teclado abierto antes de lanzar el modal
    FocusScope.of(context).unfocus();

    DateTime fechaInicial = DateTime.now();
    if (tipoFecha == 'inicio') fechaInicial = _fechaInicio;
    else if (tipoFecha == 'entrega') fechaInicial = _fechaEntrega;
    else if (tipoFecha == 'salida') fechaInicial = _fechaSalidaInstalacion ?? DateTime.now();

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: tipoFecha == 'salida' ? Colors.orangeAccent : const Color(0xFF10B981), 
            surface: const Color(0xFF1E1E1E)
          )
        ),
        child: child!,
      ),
    );
    
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.fromDateTime(fechaInicial),
        // 👇 NUEVO: Le aplicamos el mismo diseño visual al reloj para evitar parpadeos blancos
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: tipoFecha == 'salida' ? Colors.orangeAccent : const Color(0xFF10B981), 
              surface: const Color(0xFF1E1E1E)
            )
          ),
          child: child!,
        ),
      );
      if (pickedTime != null) {
        setState(() {
          DateTime finalDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (tipoFecha == 'inicio') _fechaInicio = finalDateTime; 
          else if (tipoFecha == 'entrega') _fechaEntrega = finalDateTime;
          else if (tipoFecha == 'salida') _fechaSalidaInstalacion = finalDateTime; 
        });
      }
    }
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
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Añadir Tipo de Madera", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              content: TextField(
                controller: nuevoSaunaController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Ej. Madera de Cedro...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF121212),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
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
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Guardar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double cotizacionActual = double.tryParse(_cotizacionController.text) ?? 0.0;
    double pagoInicialActual = double.tryParse(_pagoInicialController.text) ?? 0.0;
    double restante = cotizacionActual - pagoInicialActual;

    List<DropdownMenuItem<String>> itemsSaunas = _saunasCatalogo.map((sauna) {
      return DropdownMenuItem<String>(
        value: sauna.id,
        child: Text(sauna.nombre, style: const TextStyle(color: Colors.white)),
      );
    }).toList();

itemsSaunas.add(
      const DropdownMenuItem<String>(
        value: 'ADD_NEW',
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF8B5CF6), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Añadir nuevo...", 
                style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: Text("NUEVO PROYECTO", style: GoogleFonts.inter(fontWeight: FontWeight.bold)), centerTitle: true),
      body: _isLoadingCatalogos 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
        : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle("DATOS GENERALES", const Color(0xFF8B5CF6)),
              _buildTextField(_tituloController, "Título del Proyecto", Icons.title, const Color(0xFF8B5CF6), esObligatorio: true),
              const SizedBox(height: 16),
              _buildTextField(_descController, "Descripción", Icons.description, const Color(0xFF8B5CF6), maxLines: 3, esObligatorio: false),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _estatusSeleccionado,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: _inputDecoration("Estatus Inicial", Icons.rule, const Color(0xFF8B5CF6)),
                items: ['pendiente', 'en_proceso', 'finalizado'].map((e) => 
                  DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setState(() => _estatusSeleccionado = val!),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("INFORMACIÓN FINANCIERA", const Color(0xFFFFDE21)),
              _buildFinanzasField(_cotizacionController, "Monto de Cotización Total", Icons.request_quote),
              const SizedBox(height: 16),
              _buildFinanzasField(_pagoInicialController, "Pago Inicial (Anticipo)", Icons.payments),
              const SizedBox(height: 12),
              
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.calculate, color: Colors.orangeAccent),
                title: const Text("Saldo Restante", style: TextStyle(color: Colors.white54, fontSize: 13)),
                trailing: Text(
                  "\$${restante.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("ASIGNACIONES", const Color(0xFF06B6D4)),
           DropdownButtonFormField<String>(
                isExpanded: true, 
                value: _idClienteSeleccionado,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: _inputDecoration("Seleccionar Cliente", Icons.person, const Color(0xFF06B6D4)),
                items: _clientesCatalogo.map((c) => DropdownMenuItem(
                  value: c.id, 
                  child: Text(
                    c.nombre, 
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis, // <-- NUEVO
                  )
                )).toList(),
                onChanged: (val) { setState(() { _idClienteSeleccionado = val; _actualizarLugarEntrega(val!); }); },
                validator: (val) => val == null ? 'Por favor selecciona un cliente' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(_lugarEntregaController, "Lugar de Entrega (Auto-llenado)", Icons.location_on, const Color(0xFF06B6D4)),
              const SizedBox(height: 16),
              
          DropdownButtonFormField<String>(
                isExpanded: true, // <-- NUEVO
                value: _idSaunaSeleccionado,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: _inputDecoration("Tipo de madera", Icons.hot_tub, const Color(0xFF06B6D4)),
                items: itemsSaunas,
                onChanged: (val) {
                  if (val == 'ADD_NEW') {
                    _mostrarDialogoNuevoSauna();
                  } else {
                    setState(() => _idSaunaSeleccionado = val);
                  }
                },
                validator: (val) => val == null ? 'Por favor selecciona un sauna' : null,
              ),
              const SizedBox(height: 24),
              
              Text("Encargados Asignados:", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _trabajadoresCatalogo.map((t) {
                  final isSelected = _encargadosSeleccionados.contains(t.id);
                  return FilterChip(
                    label: Text(t.nombre),
                    selectedColor: const Color(0xFF06B6D4).withOpacity(0.4),
                    checkmarkColor: const Color(0xFF06B6D4),
                    selected: isSelected,
                    onSelected: (sel) { setState(() { if (sel) _encargadosSeleccionados.add(t.id); else _encargadosSeleccionados.remove(t.id); }); },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("FECHAS Y HORARIOS", const Color(0xFF10B981)),
              _buildDateTimeButton("Fecha de Inicio", _fechaInicio, 'inicio', const Color(0xFF10B981)),
              const SizedBox(height: 12),
              _buildDateTimeButton("Fecha de Entrega", _fechaEntrega, 'entrega', const Color(0xFF10B981)),
              const SizedBox(height: 24),
              
              // <-- NUEVO BOTÓN DE SALIDA INSTALACIÓN -->
              _buildSectionTitle("LOGÍSTICA", Colors.orangeAccent),
              Text("Si sabes qué día se van a instalar los equipos, agéndalo aquí para que los trabajadores puedan solicitar sus herramientas a tiempo.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 8),
              _buildDateTimeButton("Salida de Instalación", _fechaSalidaInstalacion, 'salida', Colors.orangeAccent),
              const SizedBox(height: 32),

              _buildSectionTitle("DETALLES TÉCNICOS", const Color(0xFFF59E0B)),
              _buildTextField(_medidasController, "Medidas (Ej. 1.10 x 1.10)", Icons.straighten, const Color(0xFFF59E0B)),
              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)])),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  onPressed: _isGuardando ? null : _guardarProyecto,
                  child: _isGuardando ? const CircularProgressIndicator(color: Colors.white) : const Text("CREAR PROYECTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
    );
  }

  Widget _buildFinanzasField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Color(0xFFFFDE21), fontWeight: FontWeight.bold),
      decoration: _inputDecoration(label, icon, const Color(0xFFFFDE21)),
      onTap: () {
        if (controller.text == '0.0' || controller.text == '0') {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      },
      onChanged: (val) {
        setState(() {});
      },
      validator: (v) => (v == null || double.tryParse(v) == null) ? "Ingresa un número válido" : null,
    );
  }

Widget _buildDateTimeButton(String label, DateTime? date, String tipoFecha, Color iconColor) {
    bool hasDate = date != null;
    String dateString = hasDate ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'Sin agendar';

    return InkWell(
      onTap: () => _pickDateTime(tipoFecha),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: hasDate ? iconColor.withOpacity(0.4) : Colors.white10)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 👇 NUEVO: Expanded para que el texto no desborde la pantalla
            Expanded(
              child: Text(
                label, 
                style: const TextStyle(color: Colors.white54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 👇 NUEVO: mainAxisSize en min para que los íconos ocupen solo lo necesario
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateString, 
                  style: TextStyle(
                    color: hasDate ? Colors.white : Colors.white38, 
                    fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13, // Reduje un poco el tamaño de letra para pantallas chicas
                  )
                ), 
                const SizedBox(width: 10), 
                
                if (tipoFecha == 'salida' && hasDate) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fechaSalidaInstalacion = null;
                      });
                    },
                    child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 8),
                ],

                Icon(Icons.calendar_today, color: iconColor, size: 20)
              ]
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Row(children: [Icon(Icons.label_important, color: color, size: 16), const SizedBox(width: 8), Text(title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5))]));
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color iconColor) {
    return InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), prefixIcon: Icon(icon, color: iconColor), filled: true, fillColor: const Color(0xFF1E1E1E), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: iconColor, width: 2)));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color iconColor, {int maxLines = 1, bool esObligatorio = true}) {
    return TextFormField(
      controller: controller, 
      maxLines: maxLines, 
      style: const TextStyle(color: Colors.white), 
      decoration: _inputDecoration(label, icon, iconColor), 
      validator: esObligatorio ? (v) => v == null || v.trim().isEmpty ? "Este campo es obligatorio" : null : null
    );
  }

  void _guardarProyecto() async {
    // 1. Forzar validación visual y detención si falla el validador automático del Form
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return; 
    }

    // 2. Validación explícita y manual para el TÍTULO
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título del proyecto es obligatorio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 3. Validación manual para los campos que están fuera del estándar clásico del Form
    if (_idClienteSeleccionado == null || _idSaunaSeleccionado == null || _encargadosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, rellene todos los campos obligatorios (Cliente, Madera y Encargados).'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // 4. Validar montos económicos en caso de querer finalizar el proyecto
    double cotizacion = double.tryParse(_cotizacionController.text.trim()) ?? 0.0;
    double pagoInicial = double.tryParse(_pagoInicialController.text.trim()) ?? 0.0;

    if (_estatusSeleccionado == 'finalizado' && pagoInicial < cotizacion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede finalizar el proyecto hasta que el monto esté cubierto al 100%.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; 
    }

    // Si pasó todos los filtros de validación, se procede a guardar
    setState(() => _isGuardando = true);
    try {
      Proyecto nuevoProyecto = Proyecto(
        id: '', 
        idSauna: _idSaunaSeleccionado!, 
        idCliente: _idClienteSeleccionado!, 
        titulo: _tituloController.text.trim(), 
        estatus: _estatusSeleccionado, 
        fechaInicio: _fechaInicio, 
        fechaEntrega: _fechaEntrega,
        fechaSalidaInstalacion: _fechaSalidaInstalacion, // <-- INYECTAMOS LA NUEVA FECHA AQUÍ
        medidas: _medidasController.text.trim(), 
        descripcion: _descController.text.trim(), 
        encargados: _encargadosSeleccionados,
      );
      
      await _proyectoService.crearProyecto(nuevoProyecto, cotizacion, pagoInicial);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }
}