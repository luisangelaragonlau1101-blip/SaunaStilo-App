import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/proveedor_model.dart';
import '../models/compra_insumo_model.dart'; 
import '../models/insumo_model.dart';
import '../services/inventario_service.dart';

class FormPedidoInsumoScreen extends StatefulWidget {
  final Proveedor proveedor;
  
  const FormPedidoInsumoScreen({Key? key, required this.proveedor}) : super(key: key);

  @override
  State<FormPedidoInsumoScreen> createState() => _FormPedidoInsumoScreenState();
}

class _FormPedidoInsumoScreenState extends State<FormPedidoInsumoScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventarioService _inventarioService = InventarioService(); 
  
  // Controladores de texto
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _cotizacionController = TextEditingController();
  final TextEditingController _fleteController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  DateTime _fechaPrevista = DateTime.now().add(const Duration(days: 7)); 
  double _totalCalculado = 0.0;
  bool _guardando = false;

  String? _insumoSeleccionadoId; 
  
  // 1. AÑADIDO: Declaramos la variable para almacenar el Stream
  late Stream<List<InsumoModel>> _insumosStream;

  @override
  void initState() {
    super.initState();
    // 2. AÑADIDO: Inicializamos el Stream una sola vez aquí
    _insumosStream = _inventarioService.getInsumosStream();
    
    _cotizacionController.addListener(_calcularTotal);
    _fleteController.addListener(_calcularTotal);
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _cotizacionController.dispose();
    _fleteController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _calcularTotal() {
    final cotizacion = double.tryParse(_cotizacionController.text) ?? 0.0;
    final flete = double.tryParse(_fleteController.text) ?? 0.0;
    setState(() {
      _totalCalculado = cotizacion + flete;
    });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaPrevista,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccionada != null && seleccionada != _fechaPrevista) {
      setState(() {
        _fechaPrevista = seleccionada;
      });
    }
  }

  void _guardarPedido() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_insumoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un insumo de la lista', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final nuevoPedido = CompraInsumoModel(
        id: '', 
        proveedorId: widget.proveedor.id,
        insumoId: _insumoSeleccionadoId!,
        cantidadSolicitada: double.tryParse(_cantidadController.text.trim()) ?? 0.0,
        cotizacion: double.tryParse(_cotizacionController.text) ?? 0.0,
        costoFlete: double.tryParse(_fleteController.text) ?? 0.0,
        totalCompra: _totalCalculado,
        statusPedido: 'pendiente', 
        folioFactura: '', 
        observaciones: _observacionesController.text.trim(),
        fechaSolicitud: DateTime.now(),
        fechaEntregaPrevista: _fechaPrevista,
      );

      await FirebaseFirestore.instance.collection('compras_insumos').add(nuevoPedido.toMap());
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("Error al guardar el pedido: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar el pedido'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "NUEVO PEDIDO", 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info del Proveedor
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Proveedor: ${widget.proveedor.nombreEmpresa}",
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              StreamBuilder<List<InsumoModel>>(
                // 3. MODIFICADO: Usamos la variable guardada en vez de llamar a la función
                stream: _insumosStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No hay insumos en el inventario.', style: GoogleFonts.inter(color: Colors.redAccent));
                  }

                  final insumos = snapshot.data!;

                  return DropdownButtonFormField<String>(
                    value: _insumoSeleccionadoId,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Selecciona el Insumo',
                      labelStyle: GoogleFonts.inter(color: Colors.white54),
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)), 
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    items: insumos.map((insumo) {
                      return DropdownMenuItem<String>(
                        value: insumo.id, 
                        child: Text(insumo.nombre),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _insumoSeleccionadoId = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Requerido' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              _crearTextField(
                controller: _cantidadController,
                label: 'Cantidad Solicitada',
                icon: Icons.numbers_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _crearTextField(
                      controller: _cotizacionController,
                      label: 'Cotización (\$)',
                      icon: Icons.monetization_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _crearTextField(
                      controller: _fleteController,
                      label: 'Costo Flete (\$)',
                      icon: Icons.local_shipping_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Estimado:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 16)),
                    Text("\$${_totalCalculado.toStringAsFixed(2)}", style: GoogleFonts.inter(color: const Color(0xFF81C784), fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              InkWell(
                onTap: () => _seleccionarFecha(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Fecha Entrega Prevista: ${DateFormat('dd/MM/yyyy').format(_fechaPrevista)}",
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _crearTextField(
                controller: _observacionesController,
                label: 'Observaciones (Opcional)',
                icon: Icons.notes_outlined,
                maxLines: 3,
                isRequired: false,
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardando ? null : _guardarPedido,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'REGISTRAR PEDIDO',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crearTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)), 
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: isRequired 
        ? (value) => value!.isEmpty ? 'Requerido' : null
        : null,
    );
  }
}