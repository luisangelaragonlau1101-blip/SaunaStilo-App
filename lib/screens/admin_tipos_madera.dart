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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'TIPOS DE MADERA',
          style: GoogleFonts.inter(
            fontSize: 16, 
            color: Colors.white, 
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () {
                setState(() {});
              },
              onTapOutside: (event) {
                _searchFocusNode.unfocus();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o descripción...',
                hintStyle: GoogleFonts.inter(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6)),
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _searchFocusNode.unfocus(); // Cierra el teclado
                      },
                    )
                  : const SizedBox.shrink(),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
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
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.redAccent))
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay tipos de madera registrados.', style: GoogleFonts.inter(color: Colors.white54))
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
                    child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: Colors.white54))
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: saunasFiltradas.length,
                  itemBuilder: (context, index) {
                    final sauna = saunasFiltradas[index];
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white12, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Imagen de la madera
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: sauna.imagenUrl.isNotEmpty
                                    ? Image.network(
                                        sauna.imagenUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.forest_outlined, color: Color(0xFF8B5CF6), size: 28),
                                      )
                                    : const Icon(Icons.forest_outlined, color: Color(0xFF8B5CF6), size: 28),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Información
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sauna.nombre,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2.0),
                                        child: Icon(Icons.description_outlined, size: 14, color: Color(0xFF81C784)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          sauna.descripcion.isNotEmpty ? sauna.descripcion : 'Sin descripción',
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
                                    _abrirFormularioMadera(sauna: sauna);
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.only(bottom: 12),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373), size: 22),
                                  onPressed: () {
                                    _searchFocusNode.unfocus();
                                    _confirmarEliminacion(sauna);
                                  },
                                  constraints: const BoxConstraints(),
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
        backgroundColor: Colors.white,
        onPressed: () {
          _searchFocusNode.unfocus();
          _abrirFormularioMadera();
        },
        label: Text('Nueva Madera', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
        icon: const Icon(Icons.add, color: Colors.black),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('¿Eliminar ${sauna.nombre}?', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Se verificará que no esté en uso en ningún proyecto.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54))
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
            child: Text('Verificar y Eliminar', style: GoogleFonts.inter(color: Colors.white)),
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
                widget.sauna == null ? 'Registrar Madera' : 'Editar Madera',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // SECCIÓN DE IMAGEN
              Center(
                child: GestureDetector(
                  onTap: _mostrarOpcionesImagen,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _mostrarErrorImagen ? Colors.redAccent : const Color(0xFF8B5CF6).withOpacity(0.5), 
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
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Toca para cambiar imagen',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                ),
              ),
              
              if (_mostrarErrorImagen)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      '⚠ Selecciona una imagen para continuar',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
              const SizedBox(height: 24),

              _crearTextField(
                controller: _nombreController,
                label: 'Nombre (Ej. Cedro)',
                icon: Icons.forest_outlined,
                esObligatorio: true,
              ),
              const SizedBox(height: 16),
              _crearTextField(
                controller: _descripcionController,
                label: 'Descripción',
                icon: Icons.description_outlined,
                maxLines: 3,
                esObligatorio: false,
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
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: Color(0xFF8B5CF6), size: 32),
        SizedBox(height: 8),
        Text('Foto', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: Text('Tomar foto', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: Text('Elegir de galería', style: GoogleFonts.inter(color: Colors.white)),
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