import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/idea_negocio_model.dart';
import '../services/ideas_negocio_service.dart';
import 'crear_nueva_linea_admin_screen.dart';

class IncubadoraIdeasScreen extends StatefulWidget {
  const IncubadoraIdeasScreen({Key? key}) : super(key: key);

  @override
  _IncubadoraIdeasScreenState createState() => _IncubadoraIdeasScreenState();
}

class _IncubadoraIdeasScreenState extends State<IncubadoraIdeasScreen> {
  final IdeasNegocioService _ideasService = IdeasNegocioService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _searchQuery = '';
  String _filtroEstatus = 'TODOS'; // planeacion, desarrollo, completado

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- LOGICA DE ESTILOS ---
  Color _getEstatusColor(String estatus) {
    switch (estatus.toLowerCase()) {
      case 'planeacion': return Colors.amberAccent;
      case 'desarrollo': return Colors.cyanAccent;
      case 'completado': return Colors.greenAccent;
      default: return Colors.white54;
    }
  }

  // --- COMPONENTES DE CRUD ---
  void _confirmarEliminacion(IdeaNegocioModel idea) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar iniciativa?', style: TextStyle(color: Colors.white)),
        content: Text('Se borrará "${idea.titulo}" y todas sus tareas. Esta acción es permanente.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _ideasService.eliminarIdea(idea.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _cambiarEstatusRapido(IdeaNegocioModel idea) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Actualizar Estatus de la Idea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _buildStatusOption('planeacion', 'Planeación / Incubadora', Colors.amberAccent, idea),
            _buildStatusOption('desarrollo', 'En Desarrollo / Prototipado', Colors.cyanAccent, idea),
            _buildStatusOption('completado', 'Lanzado / Finalizado', Colors.greenAccent, idea),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String slug, String label, Color color, IdeaNegocioModel idea) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 16),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        await _ideasService.actualizarEstatusIdea(idea.id, slug);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text('Incubadora de Ideas', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. BUSCADOR PRO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar ideas o misiones...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6)),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
              ),
            ),
          ),

          // 2. FILTROS POR CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('TODOS'),
                _buildFilterChip('PLANEACION'),
                _buildFilterChip('DESARROLLO'),
                _buildFilterChip('COMPLETADO'),
              ],
            ),
          ),

          // 3. LISTADO EN TIEMPO REAL
          Expanded(
            child: StreamBuilder<List<IdeaNegocioModel>>(
              stream: _ideasService.getIdeasStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                
                var ideas = snapshot.data ?? [];

                // Filtrado por estatus y búsqueda
                ideas = ideas.where((idea) {
                  bool matchesSearch = idea.titulo.toLowerCase().contains(_searchQuery) || idea.descripcion.toLowerCase().contains(_searchQuery);
                  bool matchesFilter = _filtroEstatus == 'TODOS' || idea.estatus.toUpperCase() == _filtroEstatus;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (ideas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lightbulb_outline, size: 60, color: Colors.white12),
                        SizedBox(height: 16),
                        Text('No se encontraron iniciativas.', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ideas.length,
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    final colorEstatus = _getEstatusColor(idea.estatus);
                    
                    // Cálculo de progreso
                    int totalTareas = idea.tareas.length;
                    int completadas = idea.tareas.where((t) => t.estatus == 'completado').length;
                    double progreso = totalTareas > 0 ? (completadas / totalTareas) : 0.0;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
                      child: InkWell(
                        onTap: () => _cambiarEstatusRapido(idea),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: colorEstatus.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(idea.estatus.toUpperCase(), style: TextStyle(color: colorEstatus, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Text(DateFormat('dd MMM yyyy').format(idea.fechaCreacion), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(idea.titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(idea.descripcion, style: const TextStyle(color: Colors.white54, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 20),
                              
                              // BARRA DE PROGRESO DE TAREAS
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Progreso de misiones:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  Text('$completadas/$totalTareas Hechas', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progreso,
                                  minHeight: 6,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _confirmarEliminacion(idea),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _cambiarEstatusRapido(idea),
                                    icon: const Icon(Icons.edit_note, color: Colors.cyanAccent),
                                    label: const Text('Gestionar Estatus', style: TextStyle(color: Colors.cyanAccent)),
                                  )
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
        foregroundColor: Colors.black,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CrearNuevaLineaAdminScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Línea', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool selected = _filtroEstatus == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        selected: selected,
        onSelected: (val) => setState(() => _filtroEstatus = label),
        backgroundColor: const Color(0xFF1E1E1E),
        selectedColor: const Color(0xFFDEFF9A), // Color lima suave del tema
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? Colors.transparent : Colors.white12)),
      ),
    );
  }
}