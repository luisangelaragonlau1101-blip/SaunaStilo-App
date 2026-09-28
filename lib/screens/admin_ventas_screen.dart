import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compra_model.dart';
import '../models/cliente_model.dart';
import '../services/ventas_service.dart';

class AdminVentasScreen extends StatefulWidget {
  final ClienteModel cliente;
  const AdminVentasScreen({Key? key, required this.cliente}) : super(key: key);

  @override
  State<AdminVentasScreen> createState() => _AdminVentasScreenState();
}

class _AdminVentasScreenState extends State<AdminVentasScreen> {
  final VentasService _ventasService = VentasService();

  final _cantidadController = TextEditingController(text: "1");
  final _precioUnitController = TextEditingController();

  List<Map<String, dynamic>> _productosExtras = [];
  bool _guardando = false;

  // Variables para controlar los productos de la tienda
  List<DocumentSnapshot> _productosTienda = [];
  DocumentSnapshot? _productoSeleccionado;
  bool _cargandoProductos = true;

  @override
  void initState() {
    super.initState();
    _cargarProductosTienda();
  }

  // Carga solo los insumos que son productos de la tienda
  Future<void> _cargarProductosTienda() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insumos_inventario')
          .where('es_producto_tienda', isEqualTo: true)
          .get();

      setState(() {
        _productosTienda = snap.docs;
        _cargandoProductos = false;
      });
    } catch (e) {
      setState(() => _cargandoProductos = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar productos: $e')),
      );
    }
  }

  // Calcula la cuenta final sumando los productos agregados
  double get _montoTotalCalculado {
    return _productosExtras.fold(
      0.0,
      (sum, item) => sum + ((item['precio_unitario'] * item['cantidad']) as double)
    );
  }

void _registrarVenta() async {
    if (_productosExtras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agrega al menos un producto para registrar la venta.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final nuevaCompra = CompraModel(
        id: '',
        idCliente: widget.cliente.id,
        // ¡Se eliminó por completo la línea de idProyecto!
        productosExtra: _productosExtras,
        montoTotal: _montoTotalCalculado,
        fechaCompra: DateTime.now(),
      );

      await _ventasService.registrarCompra(nuevaCompra);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        title: Text("NUEVA VENTA", style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _cargandoProductos
          ? Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                _buildSeccionProductos(),

                Divider(color: StiloColors.text.withValues(alpha: .24), height: 40),

                // Totalizador
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: StiloColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL A COBRAR:", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontWeight: FontWeight.bold)),
                      Text(
                        "\$${_montoTotalCalculado.toStringAsFixed(2)}",
                        style: GoogleFonts.inter(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    padding: EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _guardando ? null : _registrarVenta,
                  child: Text(_guardando ? "GUARDANDO..." : "FINALIZAR VENTA"),
                )
              ],
            ),
    );
  }


  Widget _buildSeccionProductos() {
    return Column(
      children: [
        // Selector de Productos desde Firestore con Stock visible
        DropdownButtonFormField<DocumentSnapshot>(
          dropdownColor: StiloColors.surface,
          decoration: _inputDecoration("Seleccionar Producto", Icons.shopping_bag_outlined),
          value: _productoSeleccionado,
          items: _productosTienda.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sin nombre';
            final stock = data['cantidad_disponible'] ?? 0;

            return DropdownMenuItem<DocumentSnapshot>(
              value: doc,
              child: Text("$nombre ($stock disp.)", style: TextStyle(color: StiloColors.text)),
            );
          }).toList(),
          onChanged: (doc) {
            setState(() {
              _productoSeleccionado = doc;
              if (doc != null) {
                final data = doc.data() as Map<String, dynamic>;
                final precio = data['precio_unitario'] ?? data['precio'] ?? 0.0;
                _precioUnitController.text = precio.toString();
              } else {
                _precioUnitController.clear();
              }
            });
          },
        ),
        SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(_precioUnitController, "Precio Unitario", Icons.tag, type: TextInputType.number),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildTextField(_cantidadController, "Cant", Icons.numbers, type: TextInputType.number),
            ),
          ],
        ),

        SizedBox(height: 8),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: StiloColors.surface,
            minimumSize: Size.fromHeight(50),
          ),
          onPressed: () {
            if (_productoSeleccionado != null) {
              final data = _productoSeleccionado!.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Producto';

              // 1. Obtener el stock total disponible desde Firestore
              final int stockDisponible = (data['cantidad_disponible'] ?? 0).toInt();
              final int cantIngresada = int.tryParse(_cantidadController.text) ?? 1;

              // 2. Controlar si el mismo producto ya se sumó previamente a la lista local
              int cantYaAgregada = _productosExtras
                  .where((p) => p['id_producto'] == _productoSeleccionado!.id)
                  .fold(0, (sum, item) => sum + (item['cantidad'] as int));

              // 3. Validación de límite excedido
              if ((cantYaAgregada + cantIngresada) > stockDisponible) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(
                      'No hay disponibles suficientes. Stock: $stockDisponible (En lista: $cantYaAgregada)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
                return; // Detiene el flujo y evita que se añada
              }

              setState(() {
                _productosExtras.add({
                  'id_producto': _productoSeleccionado!.id,
                  'nombre_producto': nombre,
                  'cantidad': cantIngresada,
                  'precio_unitario': double.tryParse(_precioUnitController.text) ?? 0.0,
                });

                // Limpiar campos de selección
                _productoSeleccionado = null;
                _cantidadController.text = "1";
                _precioUnitController.clear();
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Por favor, selecciona un producto primero.')),
              );
            }
          },
          child: Text("AÑADIR PRODUCTO"),
        ),
        SizedBox(height: 15),

        ..._productosExtras.map((p) => Card(
          color: StiloColors.surface,
          child: ListTile(
            title: Text(p['nombre_producto'], style: TextStyle(color: StiloColors.text)),
            subtitle: Text("Cant: ${p['cantidad']} | @\$${p['precio_unitario']}", style: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => setState(() => _productosExtras.remove(p)),
            ),
          ),
        )).toList(),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
    prefixIcon: Icon(icon, color: StiloColors.accent),
    filled: true,
    fillColor: StiloColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) => Container(
    margin: EdgeInsets.only(bottom: 12),
    child: TextField(contextMenuBuilder: privacyTextMenu, controller: controller, keyboardType: type, style: TextStyle(color: StiloColors.text), decoration: _inputDecoration(label, icon)),
  );
}
