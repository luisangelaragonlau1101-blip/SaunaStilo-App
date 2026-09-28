import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/proveedor_service.dart';
import '../models/proveedor_model.dart';
import 'proveedor_detalle_screen.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({Key? key}) : super(key: key);

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final ProveedorService _proveedorService = ProveedorService();

  // --- VARIABLES PARA EL BUSCADOR ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // <-- Agregado el FocusNode
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Escuchamos los cambios en el campo de texto para actualizar la búsqueda en tiempo real
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // <-- Escuchamos el foco para forzar el redibujado de la "x"
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // <-- Liberamos la memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: StiloColors.text),
        title: Text(
          'PROVEEDORES',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: StiloColors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () {
                setState(() {});
              },
              onTapOutside: (event) {
                _searchFocusNode.unfocus();
              },
              style: GoogleFonts.inter(color: StiloColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar por empresa, encargado, teléfono...',
                hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38)),
                prefixIcon: Icon(Icons.search, color: StiloColors.text.withValues(alpha: .54)),
                // --- BOTÓN "X" SIEMPRE QUE ESTÉ ENFOCADO O CON TEXTO ---
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                    ? IconButton(
                        icon: Icon(Icons.close, color: StiloColors.text.withValues(alpha: .70)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _searchFocusNode.unfocus();
                        },
                      )
                    : SizedBox.shrink(), // Evita bugs de renderizado
                filled: true,
                fillColor: StiloColors.surface,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1),
                ),
              ),
            ),
          ),

          // --- LISTA DE PROVEEDORES ---
          Expanded(
            child: StreamBuilder<List<Proveedor>>(
              stream: _proveedorService.getProveedores(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6))
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.redAccent)
                    )
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'Aún no hay proveedores registrados.',
                      style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))
                    )
                  );
                }

                final todosLosProveedores = snapshot.data!;

                // --- LÓGICA DE FILTRADO ---
                final proveedoresFiltrados = todosLosProveedores.where((proveedor) {
                  final query = _searchQuery.toLowerCase();
                  return proveedor.nombreEmpresa.toLowerCase().contains(query) ||
                         proveedor.encargadoNegocio.toLowerCase().contains(query) ||
                         proveedor.telefonoEmpresa.toLowerCase().contains(query) ||
                         proveedor.telefonoPersonal.toLowerCase().contains(query) ||
                         proveedor.ubicacion.toLowerCase().contains(query);
                }).toList();

                if (proveedoresFiltrados.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: StiloColors.text.withValues(alpha: .24)),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron resultados para "$_searchQuery".',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proveedoresFiltrados.length,
                  itemBuilder: (context, index) {
                    final proveedor = proveedoresFiltrados[index];
                    return Card(
                      color: StiloColors.surface,
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _searchFocusNode.unfocus(); // Ocultamos teclado al navegar
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProveedorDetalleScreen(proveedor: proveedor),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(0xFF3B82F6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.business, color: Color(0xFF3B82F6), size: 28),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      proveedor.nombreEmpresa,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        color: StiloColors.text
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: Color(0xFF81C784)),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            proveedor.encargadoNegocio,
                                            style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .70)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64B5F6)),
                                        SizedBox(width: 6),
                                        Text(
                                          proveedor.telefonoEmpresa,
                                          style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .70))
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(top: 2.0),
                                          child: Icon(Icons.location_on_outlined, size: 14, color: StiloColors.text.withValues(alpha: .38)),
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            proveedor.ubicacion,
                                            style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .54)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: StiloColors.text.withValues(alpha: .54), size: 22),
                                    onPressed: () {
                                      _searchFocusNode.unfocus();
                                      _abrirFormularioProveedor(proveedor: proveedor);
                                    },
                                    constraints: BoxConstraints(),
                                    padding: EdgeInsets.only(bottom: 12),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
                                    onPressed: () {
                                      _searchFocusNode.unfocus();
                                      _confirmarEliminacion(proveedor);
                                    },
                                    constraints: BoxConstraints(),
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
        backgroundColor: StiloColors.text,
        onPressed: () {
          _searchFocusNode.unfocus();
          _abrirFormularioProveedor();
        },
        label: Text('Nuevo Proveedor', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: StiloColors.background)),
        icon: Icon(Icons.add, color: StiloColors.background),
      ),
    );
  }

  void _abrirFormularioProveedor({Proveedor? proveedor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioProveedorModal(
        proveedor: proveedor,
        proveedorService: _proveedorService
      ),
    );
  }

  void _confirmarEliminacion(Proveedor proveedor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Text('¿Eliminar proveedor?', style: GoogleFonts.inter(color: StiloColors.text)),
        content: Text('Esta acción eliminará de forma permanente a ${proveedor.nombreEmpresa}.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _proveedorService.deleteProveedor(proveedor.id);
            },
            child: Text('Eliminar', style: GoogleFonts.inter(color: StiloColors.text)),
          ),
        ],
      ),
    );
  }
}

// --- FORMULARIO MODAL ESTILIZADO ---
class _FormularioProveedorModal extends StatefulWidget {
  final Proveedor? proveedor;
  final ProveedorService proveedorService;

  const _FormularioProveedorModal({Key? key, this.proveedor, required this.proveedorService}) : super(key: key);

  @override
  State<_FormularioProveedorModal> createState() => _FormularioProveedorModalState();
}

class _FormularioProveedorModalState extends State<_FormularioProveedorModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _empresaController;
  late TextEditingController _encargadoController;
  late TextEditingController _telefonoController;
  late TextEditingController _telefonoPersonalController;
  late TextEditingController _ubicacionController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _empresaController = TextEditingController(text: widget.proveedor?.nombreEmpresa ?? '');
    _encargadoController = TextEditingController(text: widget.proveedor?.encargadoNegocio ?? '');
    _telefonoController = TextEditingController(text: widget.proveedor?.telefonoEmpresa ?? '');
    _telefonoPersonalController = TextEditingController(text: widget.proveedor?.telefonoPersonal ?? '');
    _ubicacionController = TextEditingController(text: widget.proveedor?.ubicacion ?? '');
  }

  @override
  void dispose() {
    _empresaController.dispose();
    _encargadoController.dispose();
    _telefonoController.dispose();
    _telefonoPersonalController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1)),
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
                widget.proveedor == null ? 'Registrar Proveedor' : 'Editar Proveedor',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: StiloColors.text),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              _crearTextField(
                controller: _empresaController,
                label: 'Nombre de la Empresa',
                icon: Icons.business,
              ),
              SizedBox(height: 16),
              _crearTextField(
                controller: _encargadoController,
                label: 'Encargado del Negocio',
                icon: Icons.person_outline,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _crearTextField(
                      controller: _telefonoController,
                      label: 'Tel. Empresa',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _crearTextField(
                      controller: _telefonoPersonalController,
                      label: 'Tel. Personal',
                      icon: Icons.smartphone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _crearTextField(
                controller: _ubicacionController,
                label: 'Ubicación / Dirección',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StiloColors.text,
                  foregroundColor: StiloColors.background,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _guardando ? null : _guardarFormulario,
                child: _guardando
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: StiloColors.background, strokeWidth: 2))
                    : Text(
                        widget.proveedor == null ? 'GUARDAR PROVEEDOR' : 'GUARDAR CAMBIOS',
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
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: StiloColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)),
        prefixIcon: Icon(icon, color: StiloColors.text.withValues(alpha: .54)),
        filled: true,
        fillColor: StiloColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Requerido' : null,
    );
  }

  void _guardarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      if (widget.proveedor == null) {
        final nuevoProveedor = Proveedor(
          id: '',
          nombreEmpresa: _empresaController.text.trim(),
          encargadoNegocio: _encargadoController.text.trim(),
          telefonoEmpresa: _telefonoController.text.trim(),
          telefonoPersonal: _telefonoPersonalController.text.trim(),
          ubicacion: _ubicacionController.text.trim(),
        );
        await widget.proveedorService.addProveedor(nuevoProveedor);
      } else {
        final proveedorEditado = Proveedor(
          id: widget.proveedor!.id,
          nombreEmpresa: _empresaController.text.trim(),
          encargadoNegocio: _encargadoController.text.trim(),
          telefonoEmpresa: _telefonoController.text.trim(),
          telefonoPersonal: _telefonoPersonalController.text.trim(),
          ubicacion: _ubicacionController.text.trim(),
        );
        await widget.proveedorService.updateProveedor(proveedorEditado);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error al guardar: $e");
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
