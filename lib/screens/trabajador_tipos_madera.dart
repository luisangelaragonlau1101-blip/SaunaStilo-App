import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sauna_model.dart';

class CatalogoSaunasTrabajadorScreen extends StatefulWidget {
  const CatalogoSaunasTrabajadorScreen({Key? key}) : super(key: key);

  @override
  State<CatalogoSaunasTrabajadorScreen> createState() => _CatalogoSaunasTrabajadorScreenState();
}

class _CatalogoSaunasTrabajadorScreenState extends State<CatalogoSaunasTrabajadorScreen> {
  final CollectionReference _saunasCollection = FirebaseFirestore.instance.collection('cat_saunas');

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
                            
                            // Información (ahora ocupa todo el espacio restante)
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
    );
  }
}