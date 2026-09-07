import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrabajadorCategoriasScreen extends StatefulWidget {
  const TrabajadorCategoriasScreen({super.key});

  @override
  State<TrabajadorCategoriasScreen> createState() => _TrabajadorCategoriasScreenState();
}

class _TrabajadorCategoriasScreenState extends State<TrabajadorCategoriasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Controladores para el buscador
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _estaBuscando = false;

  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF111012);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorAcento = Color(0xFFB7FF2A);
  static const Color colorRosaVibrante = Color(0xFFFF729C);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Auxiliar para remover acentos y buscar texto de forma segura
  String _normalizarTexto(String texto) {
    var conAcentos = 'áéíóúÁÉÍÓÚüÜ';
    var sinAcentos = 'aeiouAEIOUuU';
    String resultado = texto.trim().toLowerCase();
    for (int i = 0; i < conAcentos.length; i++) {
      resultado = resultado.replaceAll(conAcentos[i], sinAcentos[i]);
    }
    return resultado;
  }

  // Función auxiliar vital para evitar crasheos de "Bad state"
  String _obtenerCampoSeguro(DocumentSnapshot doc, String campo) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey(campo)) {
      return data[campo].toString();
    }
    return '';
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
              'INVENTARIO Y CATEGORÍAS',
              style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.w700, fontSize: 16),
            )
          : TextField(contextMenuBuilder: privacyTextMenu,
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: (valor) {
                setState(() {
                  _searchQuery = _normalizarTexto(valor);
                });
              },
              decoration: const InputDecoration(
                hintText: 'Buscar categoría o producto...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
              ),
            ),
        actions: [
          _estaBuscando 
            ? IconButton(
                icon: const Icon(Icons.close, color: colorRosaVibrante),
                onPressed: () {
                  setState(() {
                    _estaBuscando = false;
                    _searchController.clear();
                    _searchQuery = "";
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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categorias_inventario').snapshots(),
              builder: (context, catSnapshot) {
                if (catSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: colorTextoPrimario));
                }
                if (!catSnapshot.hasData || catSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay categorías registradas.', style: TextStyle(color: Colors.white38)));
                }

                var catDocs = catSnapshot.data!.docs;

                // Ordenar categorías alfabéticamente
                catDocs.sort((a, b) {
                  String nombreA = _obtenerCampoSeguro(a, 'nombre').toUpperCase();
                  String nombreB = _obtenerCampoSeguro(b, 'nombre').toUpperCase();
                  return nombreA.compareTo(nombreB);
                });

                // Filtrar categorías si la búsqueda coincide con el nombre de la categoría
                if (_searchQuery.isNotEmpty) {
                  catDocs = catDocs.where((cat) {
                    String catNombre = _normalizarTexto(_obtenerCampoSeguro(cat, 'nombre'));
                    return catNombre.contains(_searchQuery);
                  }).toList();
                }

                if (catDocs.isEmpty) {
                  return const Center(child: Text('No se encontraron resultados.', style: TextStyle(color: Colors.white38)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: catDocs.length,
                  itemBuilder: (context, index) {
                    String catNombre = _obtenerCampoSeguro(catDocs[index], 'nombre');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: colorAcento,
                          collapsedIconColor: Colors.white70,
                          title: Text(
                            catNombre.toUpperCase(),
                            style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            _buildSubcategoriasYProductos(catNombre),
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

  Widget _buildSubcategoriasYProductos(String categoriaPadre) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('subcategorias_inventario').snapshots(),
      builder: (context, subSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('insumos_inventario').snapshots(),
          builder: (context, insumosSnapshot) {
            if (insumosSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: colorRosaVibrante, strokeWidth: 2),
              );
            }

            final catPadreNorm = _normalizarTexto(categoriaPadre);

            // Obtener documentos asegurando exclusión de productos de la tienda online
            final insumosDocsTotales = insumosSnapshot.data?.docs ?? [];
            final productosFiltrados = insumosDocsTotales.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              
              // Filtrar productos de la tienda online leyendo la llave exacta del modelo
              bool esProductoTienda = data != null && data['es_producto_tienda'] == true;
              if (esProductoTienda) return false;

              // Verificar que pertenezcan a la categoría
              if (_normalizarTexto(_obtenerCampoSeguro(doc, 'categoria')) != catPadreNorm) return false;

              // Filtrar por buscador si está activo
              if (_searchQuery.isNotEmpty) {
                String nombreProd = _normalizarTexto(_obtenerCampoSeguro(doc, 'nombre'));
                String subcatProd = _normalizarTexto(_obtenerCampoSeguro(doc, 'subcategoria'));
                if (!nombreProd.contains(_searchQuery) && !subcatProd.contains(_searchQuery)) {
                  return false;
                }
              }
              
              return true;
            }).toList();

            // Ordenar productos alfabéticamente
            productosFiltrados.sort((a, b) {
              String nombreA = _obtenerCampoSeguro(a, 'nombre').toUpperCase();
              String nombreB = _obtenerCampoSeguro(b, 'nombre').toUpperCase();
              return nombreA.compareTo(nombreB);
            });

            // Agrupar productos por subcategoría
            Set<String> subcategoriasActivas = productosFiltrados
                .map((doc) {
                   String sub = _obtenerCampoSeguro(doc, 'subcategoria');
                   return sub.isEmpty ? 'GENERAL' : sub.trim().toUpperCase();
                })
                .toSet();

            Map<String, List<DocumentSnapshot>> agrupadosPorSub = {};
            for (var doc in productosFiltrados) {
              String sub = _obtenerCampoSeguro(doc, 'subcategoria');
              sub = sub.isEmpty ? 'GENERAL' : sub.trim().toUpperCase();
              if (!agrupadosPorSub.containsKey(sub)) agrupadosPorSub[sub] = [];
              agrupadosPorSub[sub]!.add(doc);
            }

            // Obtener subcategorías oficiales
            final subDocsTotales = subSnapshot.data?.docs ?? [];
            final subDocsFiltrados = subDocsTotales.where((doc) {
               String catVinculada = _obtenerCampoSeguro(doc, 'categoriaNombre');
               if (catVinculada.isEmpty) catVinculada = _obtenerCampoSeguro(doc, 'categoria');
               return _normalizarTexto(catVinculada) == catPadreNorm;
            }).toList();

            Map<String, String> subIdsOficiales = {};
            for (var doc in subDocsFiltrados) {
              String nombreOficial = _obtenerCampoSeguro(doc, 'nombre').trim().toUpperCase();
              if (nombreOficial.isNotEmpty) {
                 // Filtrar subcategorías vacías por el buscador también
                 if (_searchQuery.isEmpty || _normalizarTexto(nombreOficial).contains(_searchQuery)) {
                   subIdsOficiales[nombreOficial] = doc.id;
                 }
              }
            }

            Set<String> todasLasSubcategorias = {...subcategoriasActivas, ...subIdsOficiales.keys};
            
            // Ordenar subcategorías alfabéticamente
            List<String> subcategoriasOrdenadas = todasLasSubcategorias.toList()..sort();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              color: const Color(0xFF161616), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subcategoriasOrdenadas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text('No hay insumos registrados.', style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
                    ),

                  ...subcategoriasOrdenadas.map((subcategoriaNombre) {
                    var productos = agrupadosPorSub[subcategoriaNombre] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 16, color: colorRosaVibrante),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  subcategoriaNombre,
                                  style: GoogleFonts.inter(color: colorRosaVibrante, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (productos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 22, bottom: 8, top: 2),
                            child: Text('• Sin insumos registrados', style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic)),
                          ),
                        ...productos.map((prod) {
                          String nombreProducto = _obtenerCampoSeguro(prod, 'nombre');
                          String stockStr = _obtenerCampoSeguro(prod, 'cantidad_disponible');
                          int stock = int.tryParse(stockStr) ?? 0;
                          String unidad = _obtenerCampoSeguro(prod, 'unidad_medida');

                          return Padding(
                            padding: const EdgeInsets.only(left: 22, bottom: 6, top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• $nombreProducto',
                                    style: GoogleFonts.inter(color: colorTextoPrimario.withOpacity(0.85), fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '$stock $unidad',
                                  style: GoogleFonts.inter(
                                    color: stock > 0 ? const Color(0xFF66BB6A) : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: Colors.white10, height: 20),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}