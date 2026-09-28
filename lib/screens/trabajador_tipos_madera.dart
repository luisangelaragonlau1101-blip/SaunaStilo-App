import '../presentation/appearance.dart';
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

                            // Información (ahora ocupa todo el espacio restante)
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
