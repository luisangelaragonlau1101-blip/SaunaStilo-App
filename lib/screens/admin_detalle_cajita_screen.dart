import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDetalleCajitaScreen extends StatefulWidget {
  final String usuarioId; 
  final String nombreUsuario;

  const AdminDetalleCajitaScreen({
    super.key,
    required this.usuarioId,
    required this.nombreUsuario,
  });

  @override
  State<AdminDetalleCajitaScreen> createState() => _AdminDetalleCajitaScreenState();
}

class _AdminDetalleCajitaScreenState extends State<AdminDetalleCajitaScreen> {
  static const Color colorFondo = Color(0xFF121212);
  static const Color colorTarjeta = Color(0xFF1E1E1E);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorVerde = Color(0xFF00E676);

  bool _asignando = false;

  Future<void> _asignarHerramienta(String insumoId, Map<String, dynamic> insumoData) async {
    setState(() => _asignando = true);
    Navigator.pop(context); // Cerramos el modal de búsqueda

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);
        DocumentReference nuevaCajitaRef = FirebaseFirestore.instance.collection('cajitas_inventario').doc();

        DocumentSnapshot insumoSnap = await transaction.get(insumoRef);
        if (!insumoSnap.exists) throw Exception("El insumo no existe");

        final data = insumoSnap.data() as Map<String, dynamic>;
        int disponible = data['cantidad_disponible'] ?? 0;

        if (disponible <= 0) {
          throw Exception("No hay stock disponible de esta herramienta");
        }

        // Restamos 1 del inventario general
        transaction.update(insumoRef, {
          'cantidad_disponible': disponible - 1,
        });

        // Creamos el registro en la cajita (Mantenemos la llave vieja en BD)
        transaction.set(nuevaCajitaRef, {
          'herramienta_base_id': insumoId,
          'nombre': data['nombre'] ?? 'Herramienta',
          'categoria': data['categoria'] ?? 'General',
          'trabajador_actual_id': widget.usuarioId, // Aquí usamos el ID genérico
          'estado': 'asignado',
          'fecha_entrega': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: colorVerde, content: Text("Herramienta asignada con éxito.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _asignando = false);
    }
  }

  // 2. NUEVO: Lógica para quitar de la cajita y devolver al inventario global
  Future<void> _devolverHerramienta(String cajitaId, String insumoId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);
        DocumentReference cajitaRef = FirebaseFirestore.instance.collection('cajitas_inventario').doc(cajitaId);

        DocumentSnapshot insumoSnap = await transaction.get(insumoRef);
        
        // Sumamos 1 al inventario general (si el insumo base aún existe en bd)
        if (insumoSnap.exists) {
          final data = insumoSnap.data() as Map<String, dynamic>;
          int disponible = data['cantidad_disponible'] ?? 0;
          transaction.update(insumoRef, {
            'cantidad_disponible': disponible + 1,
          });
        }

        // Eliminamos el registro de la cajita actual
        transaction.delete(cajitaRef);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: colorVerde, content: Text("Herramienta devuelta al almacén.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Error al devolver: $e")),
        );
      }
    }
  }

  // 3. NUEVO: Lógica para mandar a reparación (Actualiza el estado para que lo jale tu otro módulo)
  Future<void> _mandarAReparacion(String cajitaId) async {
    try {
      await FirebaseFirestore.instance.collection('cajitas_inventario').doc(cajitaId).update({
        'estado': 'mantenimiento',
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.orangeAccent, content: Text("Herramienta enviada a reparación.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")),
        );
      }
    }
  }

  // Modal Inferior con el Inventario General y Buscador
  void _mostrarModalInventarioGeneral() {
    String searchQuery = "";

    showModalBottomSheet(
      context: context,
      backgroundColor: colorTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    Text(
                      "INVENTARIO GENERAL",
                      style: GoogleFonts.inter(color: colorNaranja, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Text(
                      "Selecciona la herramienta a entregar",
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    
                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        style: GoogleFonts.inter(color: colorTextoPrimario),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('insumos_inventario')
                            .where('cantidad_disponible', isGreaterThan: 0)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: colorNaranja));

                          final todosLosInsumos = snapshot.data!.docs;

                       // Lógica de filtrado
final insumos = todosLosInsumos.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
  
  // NUEVA REGLA: Si es un producto de la tienda online, lo ocultamos.
  final esProductoTienda = data['es_producto_tienda'] ?? false;
  if (esProductoTienda == true) {
    return false; 
  }

  // El buscador de texto se queda igual
  if (searchQuery.isNotEmpty && !nombre.contains(searchQuery)) {
    return false;
  }
  
  return true;
}).toList();

                          if (insumos.isEmpty) {
                            return Center(
                              child: Text(
                                searchQuery.isEmpty 
                                  ? "No hay herramientas disponibles en el almacén." 
                                  : "No se encontraron herramientas con '$searchQuery'.", 
                                style: GoogleFonts.inter(color: Colors.white54)
                              )
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: insumos.length,
                            itemBuilder: (context, index) {
                              final doc = insumos[index];
                              final data = doc.data() as Map<String, dynamic>;

                              return ListTile(
                                leading: const Icon(Icons.build_circle_outlined, color: Colors.white38),
                                title: Text(data['nombre'] ?? 'Sin nombre', style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text("Stock: ${data['cantidad_disponible']} - ${data['categoria']}", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: colorVerde),
                                  onPressed: () => _asignarHerramienta(doc.id, data),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
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
        title: Text(
          'CAJITA: ${widget.nombreUsuario.toUpperCase()}', // Variable actualizada
          style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Botón superior para asignar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorNaranja.withOpacity(0.15),
                  foregroundColor: colorNaranja,
                  elevation: 0,
                  side: BorderSide(color: colorNaranja.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _asignando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colorNaranja, strokeWidth: 2))
                  : const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  _asignando ? "ASIGNANDO..." : "ASIGNAR DESDE ALMACÉN",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                onPressed: _asignando ? null : _mostrarModalInventarioGeneral,
              ),
            ),
          ),
          
          const Divider(color: Colors.white10),
          
          // Lista de herramientas que tiene el usuario
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cajitas_inventario')
                  // Aquí se usa el ID genérico manteniendo la llave de BD
                  .where('trabajador_actual_id', isEqualTo: widget.usuarioId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: colorNaranja));
                }

                final herramientas = snapshot.data?.docs ?? [];

                if (herramientas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.home_repair_service_outlined, color: Colors.white24, size: 60),
                        const SizedBox(height: 16),
                        Text('La cajita está vacía.', style: GoogleFonts.inter(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: herramientas.length,
                  itemBuilder: (context, index) {
                    final docId = herramientas[index].id;
                    final data = herramientas[index].data() as Map<String, dynamic>;
                    final insumoBaseId = data['herramienta_base_id'] ?? '';
                    final estado = data['estado'] ?? 'asignado';
                    
                    Color colorEstado = colorVerde;
                    String textoEstado = "EN USO";
                    
                    if (estado == 'en_transito') {
                      colorEstado = Colors.orangeAccent;
                      textoEstado = "PRESTANDO";
                    } else if (estado == 'mantenimiento') {
                      colorEstado = Colors.redAccent;
                      textoEstado = "TALLER";
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.handyman_rounded, color: colorEstado, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['nombre'] ?? 'Herramienta',
                                  style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['categoria'] ?? '',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              textoEstado,
                              style: GoogleFonts.inter(color: colorEstado, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Menú de opciones (Devolver / Reparar)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
                            color: colorTarjeta,
                            onSelected: (value) {
                              if (value == 'devolver') {
                                _devolverHerramienta(docId, insumoBaseId);
                              } else if (value == 'reparacion') {
                                _mandarAReparacion(docId);
                              }
                            },
                            itemBuilder: (context) => [
                              if (estado != 'mantenimiento') 
                                PopupMenuItem(
                                  value: 'reparacion',
                                  child: Text('Mandar a taller / daño', style: GoogleFonts.inter(color: Colors.orangeAccent)),
                                ),
                              PopupMenuItem(
                                value: 'devolver',
                                child: Text('Devolver al almacén', style: GoogleFonts.inter(color: colorVerde)),
                              ),
                            ],
                          ),
                        ],
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