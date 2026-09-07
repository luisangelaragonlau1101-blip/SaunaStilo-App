import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/proyecto_service.dart';
import '../models/proyecto_model.dart';
import 'proyecto_detalle_trabajador_screen.dart'; 
import 'maestro_proyecto_detalle_screen.dart'; 

class ProyectosTrabajadorScreen extends StatefulWidget {
  final String? filtroInicial;
  final bool esMaestro; 

  const ProyectosTrabajadorScreen({
    Key? key, 
    this.filtroInicial,
    this.esMaestro = false, 
  }) : super(key: key);

  @override
  State<ProyectosTrabajadorScreen> createState() => _ProyectosTrabajadorScreenState();
}

class _ProyectosTrabajadorScreenState extends State<ProyectosTrabajadorScreen> {
  final ProyectoService _proyectoService = ProyectoService();
  
  // Controladores y variables de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); 
  String _searchQuery = ''; 

  // Variable para el filtro de estatus
  late String _filtroEstatus;

  @override
  void initState() {
    super.initState();
    
    _filtroEstatus = widget.filtroInicial ?? 'todos';

    // Forzamos el redibujado de la pantalla al cambiar el foco
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

  // Función para obtener el color según el estatus
  Color _getStatusColor(String estatus) {
    switch (estatus) {
      case 'finalizado': return Colors.greenAccent;
      case 'en_proceso': return Colors.cyanAccent;
      case 'pendiente': return Colors.orangeAccent;
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text('PROYECTOS', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
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
                  hintText: 'Buscar por título, cliente o estatus...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6)),
                  suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchFocusNode.unfocus(); 
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

            // --- FILTROS DE ESTATUS (CHIPS) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFiltroChip('Todos', 'todos'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Pendientes', 'pendiente'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('En Proceso', 'en_proceso'),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Finalizados', 'finalizado'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- LISTA DE PROYECTOS ---
            Expanded(
              child: StreamBuilder<List<Proyecto>>(
                stream: _proyectoService.getProyectos(soloAsignados: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No hay proyectos asignados.', style: GoogleFonts.inter(color: Colors.white54)));
                  }

                  final proyectos = snapshot.data!.where((p) {
                    if (_filtroEstatus != 'todos' && p.estatus != _filtroEstatus) {
                      return false;
                    }

                    final tituloMatch = p.titulo.toLowerCase().contains(_searchQuery);
                    final estatusMatch = p.estatus.replaceAll('_', ' ').toLowerCase().contains(_searchQuery);
                    return tituloMatch || estatusMatch;
                  }).toList();

                  if (proyectos.isEmpty) {
                     return Center(child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: Colors.white54)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: proyectos.length,
                    itemBuilder: (context, index) {
                      final proyecto = proyectos[index];
                      Color statusColor = _getStatusColor(proyecto.estatus);
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _searchFocusNode.unfocus(); 
                            if (widget.esMaestro) {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => ProyectoDetalleMaestroScreen(proyecto: proyecto))
                              );
                            } else {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => ProyectoDetalleTrabajadorScreen(proyecto: proyecto))
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.construction, color: statusColor, size: 24),
                                ),
                                const SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(proyecto.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      
                                      Text(
                                        'Proyecto asignado',
                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                                      ),
                                      const SizedBox(height: 8),

                                      Wrap(
                                        spacing: 8.0,    
                                        runSpacing: 4.0, 
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: statusColor.withOpacity(0.3))
                                            ),
                                            child: Text(
                                              proyecto.estatus.replaceAll('_', ' ').toUpperCase(),
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5),
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

  Widget _buildFiltroChip(String label, String value) {
    final isSelected = _filtroEstatus == value;
    Color statusColor = value == 'todos' ? Colors.white : _getStatusColor(value);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF121212) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: statusColor,
      backgroundColor: const Color(0xFF1E1E1E),
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? Colors.transparent : statusColor.withOpacity(0.5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filtroEstatus = value;
          });
          _searchFocusNode.unfocus();
        }
      },
    );
  }
}
