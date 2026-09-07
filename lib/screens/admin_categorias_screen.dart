import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventario_service.dart';

class AdminCategoriasScreen extends StatefulWidget {
  const AdminCategoriasScreen({super.key});

  @override
  State<AdminCategoriasScreen> createState() => _AdminCategoriasScreenState();
}

class _AdminCategoriasScreenState extends State<AdminCategoriasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF111012);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorAcento = Color(0xFFB7FF2A);
  static const Color colorAzul = Color(0xFFC798FF);
  static const Color colorRosaVibrante = Color(0xFFFF729C);
  static const Color colorBlanco = Color(0xFFFFFFFF);

  // Auxiliar para remover acentos y comparar texto plano de forma segura
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
    return ''; // Retorna vacío si el campo no existe en Firestore
  }

  // CRUD DIALOGS
  void _mostrarFormularioElemento({String? id, required String coleccion, String? nombreInicial, String? categoriaPadre}) {
    final textController = TextEditingController(text: nombreInicial);
    final bool esEdicion = id != null;
    final bool esCategoria = coleccion == 'categorias_inventario';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorTarjeta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: colorRosaVibrante, width: 2), 
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              esEdicion ? 'EDITAR NOMBRE' : (esCategoria ? 'NUEVA CATEGORÍA' : 'NUEVA SUBCATEGORÍA'),
              style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: colorRosaVibrante),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esCategoria && !esEdicion && categoriaPadre != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Pertenece a: ${categoriaPadre.toUpperCase()}',
                  style: const TextStyle(color: colorAcento, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            TextField(contextMenuBuilder: privacyTextMenu,
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: colorRosaVibrante), borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
     actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorAzul,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              String nombreNuevo = textController.text.trim();
              if (nombreNuevo.isNotEmpty) {
                
                if (!esEdicion) {
                  // LÓGICA DE CREACIÓN
                  Map<String, dynamic> datosAEnviar = {'nombre': nombreNuevo};
                  if (!esCategoria && categoriaPadre != null) {
                    datosAEnviar['categoriaNombre'] = categoriaPadre.toLowerCase();
                  }
                  await _firestore.collection(coleccion).add(datosAEnviar);
                } else {
                  // 🔥 NUEVA LÓGICA DE EDICIÓN EN CASCADA
                  if (esCategoria && nombreInicial != null) {
                    await InventarioService().actualizarCategoriaEnCascada(id, nombreInicial, nombreNuevo);
                  } else if (!esCategoria && nombreInicial != null) {
                    await InventarioService().actualizarSubcategoriaEnCascada(id, nombreInicial, nombreNuevo);
                  }
                }
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              'GUARDAR',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarElementoConRestriccion({
    required String id, 
    required String coleccion, 
    required String nombreElemento,
    required bool esCategoria,
  }) async {
    final queryInsumos = await _firestore.collection('insumos_inventario').get();
    final stringBuscado = _normalizarTexto(nombreElemento);

    bool tieneVinculos = queryInsumos.docs.any((doc) {
      String campoAValidar = esCategoria 
          ? _obtenerCampoSeguro(doc, 'categoria') 
          : _obtenerCampoSeguro(doc, 'subcategoria');
      return _normalizarTexto(campoAValidar) == stringBuscado;
    });

    if (esCategoria && !tieneVinculos) {
       final querySubcat = await _firestore.collection('subcategorias_inventario').get();
       tieneVinculos = querySubcat.docs.any((doc) {
         String catVinculada = _obtenerCampoSeguro(doc, 'categoriaNombre');
         if (catVinculada.isEmpty) catVinculada = _obtenerCampoSeguro(doc, 'categoria');
         return _normalizarTexto(catVinculada) == stringBuscado;
       });
    }

    if (tieneVinculos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colorTarjeta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.redAccent, width: 1)),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No se puede eliminar. Hay productos o subcategorías vinculados a esta ${esCategoria ? 'categoría' : 'subcategoría'}.',
                  style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorTarjeta,
        title: const Text('¿Eliminar elemento?', style: TextStyle(color: Colors.white)),
        content: Text('Se eliminará "$nombreElemento". Esta acción no se puede deshacer.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await _firestore.collection(coleccion).doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextoPrimario),
        title: Text(
          'CATEGORÍAS Y SUBCATEGORÍAS',
          style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('categorias_inventario').snapshots(),
        builder: (context, catSnapshot) {
          if (catSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: colorTextoPrimario));
          }
          if (!catSnapshot.hasData || catSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay categorías registradas.', style: TextStyle(color: Colors.white38)));
          }

          final catDocs = catSnapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: catDocs.length,
            itemBuilder: (context, index) {
              String catId = catDocs[index].id;
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                          onPressed: () => _mostrarFormularioElemento(id: catId, coleccion: 'categorias_inventario', nombreInicial: catNombre),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _eliminarElementoConRestriccion(
                            id: catId, 
                            coleccion: 'categorias_inventario', 
                            nombreElemento: catNombre,
                            esCategoria: true
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 22),
                      ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorBlanco,
        foregroundColor: colorFondo,
        elevation: 6,
        onPressed: () => _mostrarFormularioElemento(coleccion: 'categorias_inventario'),
        tooltip: "Nueva Categoría",
        child: const Icon(Icons.add, size: 28),
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

            final subDocsTotales = subSnapshot.data?.docs ?? [];
            final subDocsFiltrados = subDocsTotales.where((doc) {
               String catVinculada = _obtenerCampoSeguro(doc, 'categoriaNombre');
               if (catVinculada.isEmpty) catVinculada = _obtenerCampoSeguro(doc, 'categoria');
               return _normalizarTexto(catVinculada) == catPadreNorm;
            }).toList();

            final insumosDocsTotales = insumosSnapshot.data?.docs ?? [];
            final productosFiltrados = insumosDocsTotales.where((doc) {
              return _normalizarTexto(_obtenerCampoSeguro(doc, 'categoria')) == catPadreNorm;
            }).toList();

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

            Map<String, String> subIdsOficiales = {};
            for (var doc in subDocsFiltrados) {
              String nombreOficial = _obtenerCampoSeguro(doc, 'nombre').trim().toUpperCase();
              if (nombreOficial.isNotEmpty) {
                 subIdsOficiales[nombreOficial] = doc.id;
              }
            }

            Set<String> todasLasSubcategorias = {...subcategoriasActivas, ...subIdsOficiales.keys};

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              color: const Color(0xFF161616), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (todasLasSubcategorias.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Text('No hay subcategorías registradas.', style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
                    ),

                  ...todasLasSubcategorias.map((subcategoriaNombre) {
                    var productos = agrupadosPorSub[subcategoriaNombre] ?? [];
                    String? subIdFirestore = subIdsOficiales[subcategoriaNombre];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
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
                              if (subIdFirestore != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white54, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _mostrarFormularioElemento(
                                        id: subIdFirestore, 
                                        coleccion: 'subcategorias_inventario', 
                                        nombreInicial: subcategoriaNombre.toLowerCase(),
                                        categoriaPadre: categoriaPadre
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _eliminarElementoConRestriccion(
                                        id: subIdFirestore, 
                                        coleccion: 'subcategorias_inventario', 
                                        nombreElemento: subcategoriaNombre.toLowerCase(),
                                        esCategoria: false
                                      ),
                                    ),
                                  ],
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
                        }).toList(),
                        const Divider(color: Colors.white10, height: 20),
                      ],
                    );
                  }).toList(),

                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorAzul,
                        side: BorderSide(color: colorAzul.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 40)
                      ),
                      onPressed: () => _mostrarFormularioElemento(
                        coleccion: 'subcategorias_inventario', 
                        categoriaPadre: categoriaPadre
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'AÑADIR SUBCATEGORÍA EN ${categoriaPadre.toUpperCase()}', 
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}