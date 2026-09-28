import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/proyecto_service.dart';
import '../models/proyecto_model.dart';
// Importamos la pantalla de detalles que creamos para el almacenista
import 'proyecto_detalle_almacenista_screen.dart';

class ProyectosAlmacenistaScreen extends StatefulWidget {
  final String? filtroInicial;

  const ProyectosAlmacenistaScreen({
    Key? key,
    this.filtroInicial,
  }) : super(key: key);

  @override
  State<ProyectosAlmacenistaScreen> createState() => _ProyectosAlmacenistaScreenState();
}

class _ProyectosAlmacenistaScreenState extends State<ProyectosAlmacenistaScreen> {
  final ProyectoService _proyectoService = ProyectoService();

  // Controladores y variables de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Variable para el filtro de estatus
  late String _filtroEstatus;

  // Diccionario para cargar los clientes una sola vez y buscar rápido
  Map<String, String> _clientesDict = {};
  bool _isLoadingClientes = true;

  @override
  void initState() {
    super.initState();

    _filtroEstatus = widget.filtroInicial ?? 'todos';
    _cargarClientesParaBuscador();

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

  // Descarga los nombres de los clientes para filtrar en tiempo real
  Future<void> _cargarClientesParaBuscador() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('clientes').get();
      final Map<String, String> dict = {};
      for (var doc in snap.docs) {
        dict[doc.id] = (doc.data()['nombre'] ?? 'Sin nombre').toString();
      }
      if (mounted) {
        setState(() {
          _clientesDict = dict;
          _isLoadingClientes = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando clientes: $e");
      if (mounted) setState(() => _isLoadingClientes = false);
    }
  }

  // Función para obtener el color según el estatus
  Color _getStatusColor(String estatus) {
    switch (estatus) {
      case 'finalizado': return Colors.greenAccent;
      case 'en_proceso': return Colors.cyanAccent;
      case 'pendiente': return Colors.orangeAccent;
      default: return StiloColors.text.withValues(alpha: .54);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text('PROYECTOS', style: GoogleFonts.inter(fontSize: 16, color: StiloColors.text, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: _isLoadingClientes
      ? Center(child: CircularProgressIndicator(color: StiloColors.accent))
      : Column(
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
                  hintText: 'Buscar por título, cliente o estatus...',
                  hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFFF9800)), // Color naranja para almacén
                  suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                    ? IconButton(
                        icon: Icon(Icons.clear, color: StiloColors.text.withValues(alpha: .54)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchFocusNode.unfocus();
                        },
                      )
                    : SizedBox.shrink(),
                  filled: true,
                  fillColor: StiloColors.surface,
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Color(0xFFFF9800), width: 1.5)),
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
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFiltroChip('Todos', 'todos'),
                  SizedBox(width: 8),
                  _buildFiltroChip('Pendientes', 'pendiente'),
                  SizedBox(width: 8),
                  _buildFiltroChip('En Proceso', 'en_proceso'),
                  SizedBox(width: 8),
                  _buildFiltroChip('Finalizados', 'finalizado'),
                ],
              ),
            ),
            SizedBox(height: 12),

            // --- LISTA DE PROYECTOS ---
            Expanded(
              child: StreamBuilder<List<Proyecto>>(
                stream: _proyectoService.getProyectos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Color(0xFFFF9800)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No hay proyectos asignados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))));
                  }

                  final proyectos = snapshot.data!.where((p) {
                    if (_filtroEstatus != 'todos' && p.estatus != _filtroEstatus) {
                      return false;
                    }

                    final tituloMatch = p.titulo.toLowerCase().contains(_searchQuery);
                    final estatusMatch = p.estatus.replaceAll('_', ' ').toLowerCase().contains(_searchQuery);
                    final nombreCliente = (_clientesDict[p.idCliente] ?? '').toLowerCase();
                    final clienteMatch = nombreCliente.contains(_searchQuery);

                    return tituloMatch || estatusMatch || clienteMatch;
                  }).toList();

                  if (proyectos.isEmpty) {
                     return Center(child: Text('No se encontraron resultados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: proyectos.length,
                    itemBuilder: (context, index) {
                      final proyecto = proyectos[index];
                      Color statusColor = _getStatusColor(proyecto.estatus);
                      String nombreClienteReal = _clientesDict[proyecto.idCliente] ?? 'Cliente desconocido';

                      return Card(
                        color: StiloColors.surface,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: StiloColors.text.withValues(alpha: .12))),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _searchFocusNode.unfocus();

                            // NAVEGACIÓN DIRECTA A LA PANTALLA DEL ALMACENISTA
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProyectoDetalleAlmacenistaScreen(proyecto: proyecto)
                              )
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.construction, color: statusColor, size: 24),
                                ),
                                SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(proyecto.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: StiloColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      SizedBox(height: 6),

                                      Row(
                                        children: [
                                          Icon(Icons.person, color: StiloColors.text.withValues(alpha: .54), size: 14),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              nombreClienteReal,
                                              style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .54)),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),

                                      Wrap(
                                        spacing: 8.0,
                                        runSpacing: 4.0,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                                // --- BURBUJA DE NOTIFICACIÓN DE KITS ---
                                SizedBox(width: 8),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('solicitudes_salida')
                                      .where('proyectoId', isEqualTo: proyecto.id)
                                      .where('estatus', whereIn: ['pendiente', 'en_devolucion'])
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    int pendientes = snapshot.hasData ? snapshot.data!.docs.length : 0;

                                    if (pendientes == 0) return SizedBox.shrink();

                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: Offset(0, 2))
                                        ]
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.notification_important, color: StiloColors.text, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            "$pendientes",
                                            style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 12)
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
    Color statusColor = value == 'todos' ? StiloColors.text : _getStatusColor(value);

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? StiloColors.surface : StiloColors.text.withValues(alpha: .70),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: statusColor,
      backgroundColor: StiloColors.surface,
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
