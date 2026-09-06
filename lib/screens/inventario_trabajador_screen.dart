import '../widgets/warehouse_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/inventario_service.dart';
import '../models/insumo_model.dart';
import 'trabajador_categorias_screen.dart'; 

class InventarioTrabajadorScreen extends StatefulWidget {
  const InventarioTrabajadorScreen({super.key});

  @override
  State<InventarioTrabajadorScreen> createState() => _InventarioTrabajadorScreenState();
}

class _InventarioTrabajadorScreenState extends State<InventarioTrabajadorScreen> {
  final InventarioService _inventarioService = InventarioService();
  
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  bool _estaBuscando = false; 
  String _filtroStock = "Todos"; 

  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF111012);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorAcento = Color(0xFFB7FF2A);
  static const Color colorRosa = Color(0xFFC798FF);
  static const Color colorAzul = Color(0xFFC798FF);
  static const Color colorMorado = Color(0xFFC13CFF);
  static const Color colorRojoCoral = Color(0xFFFF5252);
  static const Color colorRosaVibrante = Color(0xFFFF729C);
  static const Color colorBlanco = Color(0xFFFFFFFF);
  static const Color colorVerde1 = Color(0xFF7CE3BD);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _obtenerColorBarra(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'material':
      case 'materiales':
        return colorRosaVibrante;
      case 'herramienta':
      case 'herramientas':
        return colorRojoCoral;
      case 'máquinas':
      case 'maquinas':
        return colorMorado;
      case 'accesorios':
      case 'accesorio':
        return colorAcento;
      case 'ferretería':
        return colorVerde1;
      case 'eléctrico':
        return colorAzul;
      default:
        return colorBlanco;
    }
  }

  Color _obtenerColorStock(int cantidad, int minimo) {
    if (cantidad == 0) {
      return const Color(0xFF757575); 
    } else if (cantidad <= minimo) {
      return colorAcento; 
    } else {
      return const Color(0xFF66BB6A); 
    }
  }

  Widget _buildFilterChip(String label, Color color) {
    final bool seleccionado = _filtroStock == label;
    return ChoiceChip(
      label: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: seleccionado ? colorFondo : colorTextoPrimario.withOpacity(0.8),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      selected: seleccionado,
      selectedColor: color,
      backgroundColor: colorTarjeta,
      checkmarkColor: colorFondo,
      showCheckmark: false, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: seleccionado ? color : Colors.white10,
          width: 1,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filtroStock = label;
          });
        }
      },
    );
  }

  void _mostrarImagenExpandida(BuildContext context, String imageUrl, String heroTag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10), 
          child: GestureDetector(
            onTap: () => Navigator.pop(context), 
            child: InteractiveViewer( 
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: heroTag,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: colorRosaVibrante)),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0, 
        iconTheme: const IconThemeData(color: colorTextoPrimario),
        title: !_estaBuscando 
          ? Text(
              'INVENTARIO',
              style: GoogleFonts.inter(
                color: colorTextoPrimario,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            )
          : TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, categoría...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
              ),
            ),
        actions: [
          if (!_estaBuscando) ...[
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined, color: colorAcento),
              tooltip: 'Ver Categorías',
              onPressed: () {
                // AQUÍ ESTÁ LA CONEXIÓN CORRECTA
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrabajadorCategoriasScreen()),
                );
              },
            ),
          ],
          _estaBuscando 
            ? IconButton(
                icon: const Icon(Icons.close, color: colorRosaVibrante),
                onPressed: () {
                  setState(() {
                    _estaBuscando = false;
                    _searchController.clear();
                    _searchText = "";
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.search, color: colorTextoPrimario),
                onPressed: () {
                  setState(() {
                    _estaBuscando = true;
                  });
                },
              ),
        ],
      ),
      body: StreamBuilder<List<InsumoModel>>(
        stream: _inventarioService.getInsumosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: colorTextoPrimario));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay insumos registrados.',
                style: TextStyle(color: colorAcento),
              ),
            );
          }

          final todosLosInsumos = snapshot.data!;

          var insumosFiltrados = todosLosInsumos.where((insumo) {
            // --- NUEVA REGLA: Excluir insumos de la tienda online ---
            if (insumo.esProductoTienda) return false;

            final matchNombre = insumo.nombre.toLowerCase().contains(_searchText);
            final matchCategoria = insumo.categoria.toLowerCase().contains(_searchText);
            final matchSubcategoria = insumo.subcategoria.toLowerCase().contains(_searchText);
            return matchNombre || matchCategoria || matchSubcategoria;
          }).toList();

          if (_filtroStock == "Agotados") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible == 0).toList();
          } else if (_filtroStock == "Bajo") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible > 0 && i.cantidadDisponible <= i.stockMinimo).toList();
          } else if (_filtroStock == "Al Día") {
            insumosFiltrados = insumosFiltrados.where((i) => i.cantidadDisponible > i.stockMinimo).toList();
          }
          
          insumosFiltrados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

          return Column(
            children: [
              if (MediaQuery.sizeOf(context).height > 650 && MediaQuery.textScalerOf(context).scale(1) < 1.5) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8), child: WarehouseHeader(title: 'Todo en su lugar.', subtitle: 'Existencias · Herramientas · Insumos', compact: true)),
              // --- FILTROS DE STOCK (CHIPS) ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildFilterChip("Todos", Colors.grey),
                    const SizedBox(width: 8),
                    _buildFilterChip("Agotados", const Color(0xFF757575)), 
                    const SizedBox(width: 8),
                    _buildFilterChip("Bajo", colorAcento), 
                    const SizedBox(width: 8),
                    _buildFilterChip("Al Día", const Color(0xFF66BB6A)), 
                  ],
                ),
              ),
              
              // --- LISTA DE INSUMOS ---
              Expanded(
                child: insumosFiltrados.isEmpty 
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No hay insumos que coincidan con los criterios de búsqueda o filtro.',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center, 
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20), 
                      itemCount: insumosFiltrados.length,
                      itemBuilder: (context, index) {
                        final insumo = insumosFiltrados[index];
                        
                        return GestureDetector(
                          onTap: () {
                            print("Ver detalle de lectura de: ${insumo.nombre}");
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colorTarjeta, 
                              borderRadius: BorderRadius.circular(12), 
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IntrinsicHeight( 
                              child: Row(
                                children: [
                                  // Barra de color lateral
                                  Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      color: _obtenerColorBarra(insumo.categoria),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                  
                                  // --- MINIATURA DE LA IMAGEN EN LA LISTA ---
                                  if (insumo.imagenUrl != null && insumo.imagenUrl!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                      child: GestureDetector(
                                        onTap: () => _mostrarImagenExpandida(context, insumo.imagenUrl!, insumo.id),
                                        child: Hero(
                                          tag: insumo.id, 
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: insumo.imagenUrl!,
                                              width: 65,
                                              height: 65,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 65, height: 65, 
                                                color: Colors.white10, 
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorRosaVibrante))
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: 65, height: 65, 
                                                color: Colors.white10, 
                                                child: const Icon(Icons.broken_image, color: Colors.white54)
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                                      child: Container(
                                        width: 65, height: 65,
                                        decoration: BoxDecoration(
                                          color: Colors.white10, 
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 28),
                                      ),
                                    ),

                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0), 
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center, 
                                        children: [
                                          Text(
                                            insumo.nombre,
                                            style: GoogleFonts.inter( 
                                              color: colorTextoPrimario,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6), 
                                          Text(
                                            '${insumo.categoria.toUpperCase()} > ${insumo.subcategoria.toUpperCase()}',
                                            style: TextStyle(
                                              color: colorTextoPrimario.withOpacity(0.6), 
                                              fontSize: 12,
                                              fontFamily: GoogleFonts.inter().fontFamily, 
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _obtenerColorStock(insumo.cantidadDisponible, insumo.stockMinimo).withOpacity(0.15), 
                                              borderRadius: BorderRadius.circular(6), 
                                            ),
                                            child: Text(
                                              'STOCK: ${insumo.cantidadDisponible} ${insumo.unidadMedida}',
                                              style: GoogleFonts.inter(
                                                color: _obtenerColorStock(insumo.cantidadDisponible, insumo.stockMinimo), 
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                letterSpacing: 0.5,
                                              ),
                                              overflow: TextOverflow.ellipsis, 
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}