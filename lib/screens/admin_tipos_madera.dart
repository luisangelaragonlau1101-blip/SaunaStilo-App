import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sauna_model.dart';

class CatalogoSaunasScreen extends StatefulWidget {
  const CatalogoSaunasScreen({Key? key}) : super(key: key);

  @override
  State<CatalogoSaunasScreen> createState() => _CatalogoSaunasScreenState();
}

class _CatalogoSaunasScreenState extends State<CatalogoSaunasScreen> {
  final CollectionReference _saunasCollection = FirebaseFirestore.instance.collection('cat_saunas');
  final CollectionReference _proyectosCollection = FirebaseFirestore.instance.collection('proyectos');

  // --- VARIABLES DEL BUSCADOR ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Forzamos el redibujado de la pantalla al cambiar el foco para mostrar la "x"
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
          'TIPOS DE MADERA',
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
              style: TextStyle(color: StiloColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o descripción...',
                hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)),
                prefixIcon: Icon(Icons.search, color: StiloColors.accent),
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                  ? IconButton(
                      icon: Icon(Icons.clear, color: StiloColors.text.withValues(alpha: .54)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _searchFocusNode.unfocus(); // Cierra el teclado
                      },
                    )
                  : SizedBox.shrink(),
                filled: true,
                fillColor: StiloColors.surface,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: StiloColors.accent, width: 1.5)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // --- LISTA DE MADERAS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _saunasCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: StiloColors.accent));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.redAccent))
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay tipos de madera registrados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))
                  );
                }

                final saunas = snapshot.data!.docs.map((doc) => Sauna.fromFirestore(doc)).toList();

                // Lógica de filtrado
                final saunasFiltradas = _searchQuery.isEmpty
                    ? saunas
                    : saunas.where((sauna) {
                        final nombre = sauna.nombre.toLowerCase();
                        final descripcion = sauna.descripcion.toLowerCase();
                        return nombre.contains(_searchQuery) || descripcion.contains(_searchQuery);
                      }).toList();

                if (saunasFiltradas.isEmpty) {
                  return Center(
                    child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: saunasFiltradas.length,
                  itemBuilder: (context, index) {
                    final sauna = saunasFiltradas[index];
                    return Card(
                      color: StiloColors.surface,
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Imagen de la madera
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: StiloColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: sauna.imagenUrl.isNotEmpty
                                    ? Image.network(
                                        sauna.imagenUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(Icons.forest_outlined, color: StiloColors.accent, size: 28),
                                      )
                                    : Icon(Icons.forest_outlined, color: StiloColors.accent, size: 28),
                              ),
                            ),
                            SizedBox(width: 16),

                            // Información
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sauna.nombre,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: StiloColors.text),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.0),
                                        child: Icon(Icons.description_outlined, size: 14, color: Color(0xFF81C784)),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          sauna.descripcion.isNotEmpty ? sauna.descripcion : 'Sin descripción',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .70)),
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
                                  icon: Icon(Icons.edit_outlined, color: StiloColors.text.withValues(alpha: .54), size: 22),
                                  onPressed: () {
                                    _searchFocusNode.unfocus();
                                    _abrirFormularioMadera(sauna: sauna);
                                  },
                                  constraints: BoxConstraints(),
                                  padding: EdgeInsets.only(bottom: 12),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
                                  onPressed: () {
                                    _searchFocusNode.unfocus();
                                    _confirmarEliminacion(sauna);
                                  },
                                  constraints: BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            )
                          ],
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
          _abrirFormularioMadera();
        },
        label: Text('Nueva Madera', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: StiloColors.background)),
        icon: Icon(Icons.add, color: StiloColors.background),
      ),
    );
  }

  void _abrirFormularioMadera({Sauna? sauna}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioMaderaModal(sauna: sauna, saunasCollection: _saunasCollection),
    );
  }

 void _confirmarEliminacion(Sauna sauna) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Text('¿Eliminar ${sauna.nombre}?', style: GoogleFonts.inter(color: StiloColors.text)),
        content: Text('Se verificará que no esté en uso en ningún proyecto.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final nav = Navigator.of(context);
              final scaffold = ScaffoldMessenger.of(context);

              try {
                final proyectosUsando = await _proyectosCollection
                    .where('id_sauna', isEqualTo: sauna.id)
                    .limit(1)
                    .get();

                if (proyectosUsando.docs.isNotEmpty) {
                  nav.pop();
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('No se puede eliminar: Esta madera está asignada a un proyecto activo.', style: GoogleFonts.inter()),
                      backgroundColor: Colors.orange,
                    )
                  );
                  return;
                }

                await _saunasCollection.doc(sauna.id).delete();
                nav.pop();

                scaffold.showSnackBar(
                  SnackBar(content: Text('Madera eliminada correctamente', style: GoogleFonts.inter()), backgroundColor: Colors.green)
                );

              } catch (e) {
                nav.pop();
                scaffold.showSnackBar(
                  SnackBar(content: Text('Error al eliminar: $e', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent)
                );
              }
            },
            child: Text('Verificar y Eliminar', style: GoogleFonts.inter(color: StiloColors.text)),
          ),
        ],
      ),
    );
  }
}

// --- FORMULARIO  ---
class _FormularioMaderaModal extends StatefulWidget {
  final Sauna? sauna;
  final CollectionReference saunasCollection;

  const _FormularioMaderaModal({Key? key, this.sauna, required this.saunasCollection}) : super(key: key);

  @override
  State<_FormularioMaderaModal> createState() => _FormularioMaderaModalState();
}

class _FormularioMaderaModalState extends State<_FormularioMaderaModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;

  bool _guardando = false;
  bool _mostrarErrorImagen = false;
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.sauna?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.sauna?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // Método para seleccionar imagen
 Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imagenSeleccionada = File(pickedFile.path);
          _mostrarErrorImagen = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.redAccent),
      );
    }
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
                widget.sauna == null ? 'Registrar Madera' : 'Editar Madera',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: StiloColors.text),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // SECCIÓN DE IMAGEN
              Center(
                child: GestureDetector(
                  onTap: _mostrarOpcionesImagen,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: StiloColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _mostrarErrorImagen ? Colors.redAccent : StiloColors.accent.withOpacity(0.5),
                        width: 2
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _construirImagenPreview(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'Toca para cambiar imagen',
                  style: GoogleFonts.inter(fontSize: 12, color: StiloColors.text.withValues(alpha: .54)),
                ),
              ),

              if (_mostrarErrorImagen)
                Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      '⚠ Selecciona una imagen para continuar',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              SizedBox(height: 24),

              _crearTextField(
                controller: _nombreController,
                label: 'Nombre (Ej. Cedro)',
                icon: Icons.forest_outlined,
                esObligatorio: true,
              ),
              SizedBox(height: 16),
              _crearTextField(
                controller: _descripcionController,
                label: 'Descripción',
                icon: Icons.description_outlined,
                maxLines: 3,
                esObligatorio: false,
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
                        widget.sauna == null ? 'GUARDAR MADERA' : 'GUARDAR CAMBIOS',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirImagenPreview() {
    if (_imagenSeleccionada != null) {
      return Image.file(_imagenSeleccionada!, fit: BoxFit.cover);
    }
    if (widget.sauna != null && widget.sauna!.imagenUrl.isNotEmpty) {
      return Image.network(widget.sauna!.imagenUrl, fit: BoxFit.cover);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: StiloColors.accent, size: 32),
        SizedBox(height: 8),
        Text('Foto', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 12)),
      ],
    );
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: StiloColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: StiloColors.text),
              title: Text('Tomar foto', style: GoogleFonts.inter(color: StiloColors.text)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: StiloColors.text),
              title: Text('Elegir de galería', style: GoogleFonts.inter(color: StiloColors.text)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

 Widget _crearTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool esObligatorio = true,
  }) {
    return TextFormField(contextMenuBuilder: privacyTextMenu,
      controller: controller,
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
          borderSide: BorderSide(color: StiloColors.accent),
        ),
      ),
      validator: (value) {
        if (esObligatorio && (value == null || value.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }
        return null;
      },
    );
  }

  void _guardarFormulario() async {
    bool formularioValido = _formKey.currentState!.validate();
    bool faltaImagen = widget.sauna == null && _imagenSeleccionada == null;

    if (faltaImagen) {
      setState(() => _mostrarErrorImagen = true);
    }

    if (!formularioValido || faltaImagen) {
      if (faltaImagen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, selecciona una imagen para la madera.', style: GoogleFonts.inter()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _guardando = true);

    try {
      String imageUrl = widget.sauna?.imagenUrl ?? '';

      if (_imagenSeleccionada != null) {
        final String nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = FirebaseStorage.instance.ref().child('saunas_imagenes/$nombreArchivo');

        final UploadTask uploadTask = ref.putFile(_imagenSeleccionada!);
        final TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      final datos = {
        'nombre': _nombreController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'imagen_url': imageUrl,
      };

      if (widget.sauna == null) {
        await widget.saunasCollection.add(datos);
      } else {
        await widget.saunasCollection.doc(widget.sauna!.id).update(datos);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
