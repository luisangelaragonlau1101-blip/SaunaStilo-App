import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ventas_service.dart';
import '../models/cliente_model.dart';
import 'cliente_detalle_screen.dart'; 

class AdminClientesScreen extends StatefulWidget {
  const AdminClientesScreen({Key? key}) : super(key: key);

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen> {
  final VentasService _ventasService = VentasService();
  final TextEditingController _searchController = TextEditingController(); 
  final FocusNode _searchFocusNode = FocusNode(); // <-- 1. Añadimos el FocusNode
  String _searchQuery = ''; 

  @override
  void initState() {
    super.initState();
    // <-- 2. Escuchamos los cambios de foco para refrescar la pantalla
    _searchFocusNode.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // <-- 3. Liberamos el FocusNode de la memoria
    super.dispose();
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
          'CLIENTES',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController, 
              focusNode: _searchFocusNode, // <-- 4. Se lo asignamos al TextField
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o teléfono...',
                hintStyle: GoogleFonts.inter(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                // --- BOTÓN "X" SIEMPRE QUE HAYA TEXTO O ESTÉ SELECCIONADO ---
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _searchFocusNode.unfocus(); // <-- Oculta el teclado y quita el foco
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                ),
              ),
            ),
          ),
          
          // --- LISTA DE CLIENTES ---
          Expanded(
            child: StreamBuilder<List<ClienteModel>>(
              stream: _ventasService.obtenerClientes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No hay clientes registrados.', style: GoogleFonts.inter(color: Colors.white54)));
                }

                final clientes = snapshot.data!;
                
                // --- LÓGICA DE FILTRADO ---
                final clientesFiltrados = _searchQuery.isEmpty 
                    ? clientes 
                    : clientes.where((cliente) {
                        final nombre = cliente.nombre.toLowerCase();
                        final telefono = cliente.telefono.toLowerCase();
                        return nombre.contains(_searchQuery) || telefono.contains(_searchQuery);
                      }).toList();

                if (clientesFiltrados.isEmpty) {
                  return Center(
                    child: Text(
                      'No se encontraron resultados.', 
                      style: GoogleFonts.inter(color: Colors.white54)
                    )
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = clientesFiltrados[index];
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white12, width: 1),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Al navegar, también es buena idea quitar el foco si el teclado sigue abierto
                          _searchFocusNode.unfocus();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ClienteDetalleScreen(cliente: cliente)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.person_outline, color: Color(0xFF8B5CF6), size: 28),
                              ),
                              const SizedBox(width: 16),
                              
                              // Información del Cliente
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cliente.nombre,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64B5F6)),
                                        const SizedBox(width: 6),
                                        Text(cliente.telefono, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2.0),
                                          child: Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF81C784)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            cliente.direccion,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Botones de acción
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 22),
                                    onPressed: () {
                                      _searchFocusNode.unfocus();
                                      _abrirFormularioCliente(cliente: cliente);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(bottom: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
                                    onPressed: () {
                                      _searchFocusNode.unfocus();
                                      _confirmarEliminacion(cliente);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
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
        onPressed: () {
           _searchFocusNode.unfocus();
           _abrirFormularioCliente();
        },
        label: Text('Nuevo Cliente', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _abrirFormularioCliente({ClienteModel? cliente}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioClienteModal(cliente: cliente, ventasService: _ventasService),
    );
  }

  void _confirmarEliminacion(ClienteModel cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('¿Eliminar?', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('¿Seguro que deseas eliminar a ${cliente.nombre}?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _ventasService.eliminarCliente(cliente.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}



// --- FORMULARIO MODAL ESTILIZADO ---
class _FormularioClienteModal extends StatefulWidget {
  final ClienteModel? cliente;
  final VentasService ventasService;

  const _FormularioClienteModal({Key? key, this.cliente, required this.ventasService}) : super(key: key);

  @override
  State<_FormularioClienteModal> createState() => _FormularioClienteModalState();
}

class _FormularioClienteModalState extends State<_FormularioClienteModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente?.nombre ?? '');
    _telefonoController = TextEditingController(text: widget.cliente?.telefono ?? '');
    _direccionController = TextEditingController(text: widget.cliente?.direccion ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.cliente == null ? 'Registrar Cliente' : 'Editar Cliente',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _crearTextField(
                controller: _nombreController,
                label: 'Nombre Completo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _crearTextField(
                controller: _telefonoController,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _crearTextField(
                controller: _direccionController,
                label: 'Dirección Completa',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardando ? null : _guardarFormulario,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        widget.cliente == null ? 'GUARDAR CLIENTE' : 'GUARDAR CAMBIOS',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
              ),
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
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF121212),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)), 
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Este campo es obligatorio' : null,
    );
  }

  void _guardarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      if (widget.cliente == null) {
        final nuevoCliente = ClienteModel(
          id: '',
          nombre: _nombreController.text.trim(),
          telefono: _telefonoController.text.trim(),
          direccion: _direccionController.text.trim(),
          fechaRegistro: DateTime.now(),
        );
        await widget.ventasService.crearCliente(nuevoCliente);
      } else {
        final datos = {
          'nombre': _nombreController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'direccion': _direccionController.text.trim(),
        };
        await widget.ventasService.actualizarCliente(widget.cliente!.id, datos);
      }
      Navigator.pop(context);
    } catch (e) {
      // Manejo de error
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}