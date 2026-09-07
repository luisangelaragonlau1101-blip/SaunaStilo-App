import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/compra_insumo_model.dart';

class EditarPedidoScreen extends StatefulWidget {
  final CompraInsumoModel pedido;

  const EditarPedidoScreen({Key? key, required this.pedido}) : super(key: key);

  @override
  State<EditarPedidoScreen> createState() => _EditarPedidoScreenState();
}

class _EditarPedidoScreenState extends State<EditarPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  late TextEditingController _cantidadController;
  late TextEditingController _cotizacionController;
  late TextEditingController _fleteController;
  late TextEditingController _folioFacturaController;
  late TextEditingController _observacionesController;

  late String _statusSeleccionado;
  double _totalCalculado = 0.0;
  bool _guardando = false;

  final List<String> _opcionesStatus = ['pendiente', 'completado', 'cancelado'];

  @override
  void initState() {
    super.initState();
    
    // Inicializar controladores con los datos actuales del pedido
    _cantidadController = TextEditingController(text: widget.pedido.cantidadSolicitada.toString());
    _cotizacionController = TextEditingController(text: widget.pedido.cotizacion.toString());
    _fleteController = TextEditingController(text: widget.pedido.costoFlete.toString());
    _folioFacturaController = TextEditingController(text: widget.pedido.folioFactura);
    _observacionesController = TextEditingController(text: widget.pedido.observaciones);
    
    // Si el estatus en BD no coincide con las opciones, por defecto 'pendiente'
    _statusSeleccionado = _opcionesStatus.contains(widget.pedido.statusPedido) 
        ? widget.pedido.statusPedido 
        : 'pendiente';

    _totalCalculado = widget.pedido.totalCompra;

    // Escuchar cambios para recalcular el total en tiempo real
    _cotizacionController.addListener(_calcularTotal);
    _fleteController.addListener(_calcularTotal);
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _cotizacionController.dispose();
    _fleteController.dispose();
    _folioFacturaController.dispose();
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

  Future<void> _actualizarPedido() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);

    try {
      final dataAActualizar = {
        'cantidad_solicitada': double.tryParse(_cantidadController.text.trim()) ?? 0.0,
        'cotizacion': double.tryParse(_cotizacionController.text) ?? 0.0,
        'costo_flete': double.tryParse(_fleteController.text) ?? 0.0,
        'total_compra': _totalCalculado,
        'folio_factura': _folioFacturaController.text.trim(),
        'observaciones': _observacionesController.text.trim(),
        'status_pedido': _statusSeleccionado,
      };

      // Si marcamos como completado y no tenía fecha de entrega final, se la ponemos
      if (_statusSeleccionado == 'completado') {
        dataAActualizar['fecha_entrega_final'] = Timestamp.now();
      }

      await FirebaseFirestore.instance
          .collection('compras_insumos')
          .doc(widget.pedido.id)
          .update(dataAActualizar);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido actualizado correctamente'), backgroundColor: Color(0xFF81C784)),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      debugPrint("Error al actualizar el pedido: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el pedido'), backgroundColor: Colors.redAccent),
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
          "EDITAR PEDIDO", 
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
              // --- SECCIÓN DE ESTATUS Y FACTURA ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Gestión del Pedido", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Estatus
                    DropdownButtonFormField<String>(
                      value: _statusSeleccionado,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Estatus del Pedido',
                        labelStyle: GoogleFonts.inter(color: Colors.white54),
                        prefixIcon: const Icon(Icons.sync_alt_outlined, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)), 
                        ),
                      ),
                      items: _opcionesStatus.map((status) {
                        return DropdownMenuItem<String>(
                          value: status, 
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _statusSeleccionado = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo de Folio de Factura (Destacado)
                    _crearTextField(
                      controller: _folioFacturaController,
                      label: 'Folio de Factura',
                      icon: Icons.receipt_long_outlined,
                      isRequired: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text("Detalles Financieros y Cantidades", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(height: 12),

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
              // Total Auto-calculado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Calculado:", style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    Text("\$${_totalCalculado.toStringAsFixed(2)}", style: GoogleFonts.inter(color: const Color(0xFF81C784), fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _crearTextField(
                controller: _observacionesController,
                label: 'Observaciones',
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
                onPressed: _guardando ? null : _actualizarPedido,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'ACTUALIZAR PEDIDO',
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

  // Widget reutilizable para los TextFields
  Widget _crearTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
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
        ? (value) => value == null || value.isEmpty ? 'Requerido' : null
        : null,
    );
  }
}