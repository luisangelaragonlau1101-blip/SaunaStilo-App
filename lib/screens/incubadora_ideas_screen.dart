import '../presentation/appearance.dart';
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
      default: return StiloColors.text.withValues(alpha: .54);
    }
  }

  // --- COMPONENTES DE CRUD ---
  void _confirmarEliminacion(IdeaNegocioModel idea) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StiloColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Eliminar iniciativa?', style: TextStyle(color: StiloColors.text)),
        content: Text('Se borrará "${idea.titulo}" y todas sus tareas. Esta acción es permanente.',
            style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: StiloColors.text.withValues(alpha: .54)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _ideasService.eliminarIdea(idea.id);
              Navigator.pop(context);
            },
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _cambiarEstatusRapido(IdeaNegocioModel idea) {
    showModalBottomSheet(
      context: context,
      backgroundColor: StiloColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Actualizar Estatus de la Idea', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 20),
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
      title: Text(label, style: TextStyle(color: StiloColors.text)),
      onTap: () async {
        await _ideasService.actualizarEstatusIdea(idea.id, slug);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text('Incubadora de Ideas', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. BUSCADOR PRO
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: TextStyle(color: StiloColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar ideas o misiones...',
                hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38)),
                prefixIcon: Icon(Icons.search, color: StiloColors.accent),
                filled: true,
                fillColor: StiloColors.surface,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: StiloColors.accent, width: 1.5)),
              ),
            ),
          ),

          // 2. FILTROS POR CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: StiloColors.accent));

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
                      children: [
                        Icon(Icons.lightbulb_outline, size: 60, color: StiloColors.text.withValues(alpha: .12)),
                        SizedBox(height: 16),
                        Text('No se encontraron iniciativas.', style: TextStyle(color: StiloColors.text.withValues(alpha: .38))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: ideas.length,
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    final colorEstatus = _getEstatusColor(idea.estatus);

                    // Cálculo de progreso
                    int totalTareas = idea.tareas.length;
                    int completadas = idea.tareas.where((t) => t.estatus == 'completado').length;
                    double progreso = totalTareas > 0 ? (completadas / totalTareas) : 0.0;

                    return Card(
                      color: StiloColors.surface,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: StiloColors.text.withValues(alpha: .10))),
                      child: InkWell(
                        onTap: () => _cambiarEstatusRapido(idea),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: colorEstatus.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(idea.estatus.toUpperCase(), style: TextStyle(color: colorEstatus, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Text(DateFormat('dd MMM yyyy').format(idea.fechaCreacion), style: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 12)),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(idea.titulo, style: TextStyle(color: StiloColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
                              SizedBox(height: 6),
                              Text(idea.descripcion, style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              SizedBox(height: 20),

                              // BARRA DE PROGRESO DE TAREAS
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Progreso de misiones:', style: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 11)),
                                  Text('$completadas/$totalTareas Hechas', style: TextStyle(color: StiloColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progreso,
                                  minHeight: 6,
                                  backgroundColor: StiloColors.text.withValues(alpha: .10),
                                  valueColor: AlwaysStoppedAnimation<Color>(StiloColors.accent),
                                ),
                              ),
                              Divider(color: StiloColors.text.withValues(alpha: .10), height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _confirmarEliminacion(idea),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _cambiarEstatusRapido(idea),
                                    icon: Icon(Icons.edit_note, color: Colors.cyanAccent),
                                    label: Text('Gestionar Estatus', style: TextStyle(color: Colors.cyanAccent)),
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
        backgroundColor: StiloColors.text,
        foregroundColor: StiloColors.background,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CrearNuevaLineaAdminScreen())),
        icon: Icon(Icons.add),
        label: Text('Nueva Línea', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool selected = _filtroEstatus == label;
    return Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? StiloColors.background : StiloColors.text.withValues(alpha: .70), fontSize: 11, fontWeight: FontWeight.bold)),
        selected: selected,
        onSelected: (val) => setState(() => _filtroEstatus = label),
        backgroundColor: StiloColors.surface,
        selectedColor: Color(0xFFDEFF9A), // Color lima suave del tema
        checkmarkColor: StiloColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? Colors.transparent : StiloColors.text.withValues(alpha: .12))),
      ),
    );
  }
}
