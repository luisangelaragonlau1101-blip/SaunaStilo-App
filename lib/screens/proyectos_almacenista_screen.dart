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
      body: _isLoadingClientes 
      ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
      : Column(
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
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF9800)), // Color naranja para almacén
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
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFF9800), width: 1.5)),
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
                stream: _proyectoService.getProyectos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800)));
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
                    final nombreCliente = (_clientesDict[p.idCliente] ?? '').toLowerCase();
                    final clienteMatch = nombreCliente.contains(_searchQuery);

                    return tituloMatch || estatusMatch || clienteMatch;
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
                      String nombreClienteReal = _clientesDict[proyecto.idCliente] ?? 'Cliente desconocido';

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
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
                                      
                                      Row(
                                        children: [
                                          const Icon(Icons.person, color: Colors.white54, size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              nombreClienteReal, 
                                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
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

                                // --- BURBUJA DE NOTIFICACIÓN DE KITS ---
                                const SizedBox(width: 8),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('solicitudes_salida')
                                      .where('proyectoId', isEqualTo: proyecto.id)
                                      .where('estatus', whereIn: ['pendiente', 'en_devolucion'])
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    int pendientes = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                    
                                    if (pendientes == 0) return const SizedBox.shrink(); 

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
                                        ]
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.notification_important, color: Colors.white, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$pendientes", 
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
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