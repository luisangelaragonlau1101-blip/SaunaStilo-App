import '../services/external_transfer.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/proyecto_model.dart';
import '../models/insumo_model.dart';
import 'package:intl/intl.dart';

class CrearSolicitudSalidaScreen extends StatefulWidget {
  final Proyecto proyecto;

  const CrearSolicitudSalidaScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<CrearSolicitudSalidaScreen> createState() => _CrearSolicitudSalidaScreenState();
}

class _CrearSolicitudSalidaScreenState extends State<CrearSolicitudSalidaScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _nombreSolicitante = 'Cargando...';
  bool _enviando = false;

  List<Map<String, dynamic>> _carrito = [];

  @override
  void initState() {
    super.initState();
    _obtenerDatosUsuario();
  }

  Future<void> _obtenerDatosUsuario() async {
    if (currentUid.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUid).get();
      if (doc.exists && mounted) {
        setState(() {
          _nombreSolicitante = doc.data()?['nombre'] ?? 'Usuario';
        });
      }
    } catch (e) {
      debugPrint("Error al cargar usuario: $e");
    }
  }

  // --- ENVÍO DEL CARRITO A FIREBASE ---
  Future<void> _enviarSolicitudAlmacen() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una herramienta a la lista.'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      await FirebaseFirestore.instance.collection('solicitudes_salida').add({
        'proyectoId': widget.proyecto.id,
        'proyectoNombre': widget.proyecto.titulo,
        'usuarioId': currentUid,        // <--- ¡AÑADIDO! Para que el admin lo detecte directo
        'solicitanteId': currentUid,    // (Mantenemos este por si lo usas en otra parte)
        'solicitanteNombre': _nombreSolicitante,
        'fechaSalidaInstalacion': widget.proyecto.fechaSalidaInstalacion != null 
            ? Timestamp.fromDate(widget.proyecto.fechaSalidaInstalacion!) 
            : null,
        'fechaSolicitud': FieldValue.serverTimestamp(),
        'estatus': 'pendiente', 
        'articulos': _carrito, 
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text("Lista enviada a almacén con éxito.", style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
              ],
            ),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la solicitud: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text("ARMAR KIT DE SALIDA", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // CABECERA INFORMATIVA
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Proyecto Destino:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(widget.proyecto.titulo, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.proyecto.fechaSalidaInstalacion != null 
                          ? "Salida: ${widget.proyecto.fechaSalidaInstalacion!.day}/${widget.proyecto.fechaSalidaInstalacion!.month}/${widget.proyecto.fechaSalidaInstalacion!.year}" 
                          : "Fecha de salida sin agendar",
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // LISTA DEL CARRITO
          Expanded(
            child: _carrito.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text("Tu lista está vacía", style: GoogleFonts.inter(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text("Toca el botón abajo para agregar en bloque", style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _carrito.length,
                  itemBuilder: (context, index) {
                    final item = _carrito[index];
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: item['esRetornable'] ? Colors.orangeAccent.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.2),
                          child: Icon(
                            item['esRetornable'] ? Icons.build_rounded : Icons.lightbulb_outline,
                            color: item['esRetornable'] ? Colors.orangeAccent : Colors.cyanAccent,
                          ),
                        ),
                        title: Text(item['nombreInsumo'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text("Cant: ${item['cantidad']}", style: GoogleFonts.inter(color: Colors.white70)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item['esRetornable'] ? Colors.orangeAccent.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: item['esRetornable'] ? Colors.orangeAccent.withOpacity(0.5) : Colors.white38)
                                ),
                                child: Text(
                                  item['esRetornable'] ? "RETORNABLE" : "SE QUEDA EN OBRA", 
                                  style: GoogleFonts.inter(
                                    color: item['esRetornable'] ? Colors.orangeAccent : Colors.white54, 
                                    fontSize: 9, 
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                              )
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _carrito.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),

          
          if (_carrito.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _enviando ? null : _enviarSolicitudAlmacen,
                  child: _enviando 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text("ENVIAR LISTA AL ALMACÉN", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            )
        ],
      ),
      
      floatingActionButton: _carrito.isEmpty ? _buildFabAgregar() : Padding(
        padding: const EdgeInsets.only(bottom: 80.0), 
        child: _buildFabAgregar(),
      ),
    );
  }

  Widget _buildFabAgregar() {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF06B6D4),
      onPressed: _mostrarBuscadorInventarioMultiple,
      icon: const Icon(Icons.add, color: Colors.black),
      label: Text("Agregar Herramientas", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }

  void _mostrarBuscadorInventarioMultiple() {
   
    Map<String, Map<String, dynamic>> selecciones = {};
    String searchQuery = "";
    TextEditingController searchController = TextEditingController();

    final Stream<QuerySnapshot> inventarioStream = FirebaseFirestore.instance.collection('insumos_inventario').snapshots();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            int totalSeleccionados = selecciones.values.where((item) => item['cantidad'] > 0).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), 
                borderRadius: BorderRadius.vertical(top: Radius.circular(32))
              ),
              padding: EdgeInsets.only(
                top: 12, left: 16, right: 16, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 20 
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Selección Múltiple", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  
                  
                  TextField(contextMenuBuilder: privacyTextMenu,
                    controller: searchController,
                    onChanged: (value) => setModalState(() => searchQuery = value.toLowerCase()),
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre...",
                      hintStyle: GoogleFonts.inter(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF121212),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
               
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: inventarioStream, 
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)));
                        }
                        
                        var docs = snapshot.data?.docs ?? [];
                        if (searchQuery.isNotEmpty) {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return (data['nombre'] ?? '').toString().toLowerCase().contains(searchQuery);
                          }).toList();
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final insumo = InsumoModel.fromFirestore(docs[index]);
                            final noStock = insumo.cantidadDisponible == 0;

                            if (!selecciones.containsKey(insumo.id)) {
                              selecciones[insumo.id] = {
                                'insumoId': insumo.id,
                                'nombreInsumo': insumo.nombre,
                                'cantidad': 0, 
                                'esRetornable': true, 
                                'estatusArticulo': 'bueno'
                              };
                            }

                            final seleccion = selecciones[insumo.id]!;
                            final int cantActual = seleccion['cantidad'];
                            final bool isSelected = cantActual > 0;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.1) : const Color(0xFF121212),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.build_circle_outlined, color: isSelected ? const Color(0xFF06B6D4) : Colors.white54, size: 28),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(insumo.nombre, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                            const SizedBox(height: 4),
                                            Text(
                                              noStock ? "Sin stock" : "Disponibles: ${insumo.cantidadDisponible}", 
                                              style: GoogleFonts.inter(color: noStock ? Colors.redAccent : Colors.white54, fontSize: 12)
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.remove_circle_outline, color: cantActual > 0 ? Colors.white : Colors.white24),
                                            onPressed: cantActual > 0 ? () {
                                              setModalState(() => selecciones[insumo.id]!['cantidad']--);
                                            } : null,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              "$cantActual", 
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(color: cantActual > 0 ? Colors.white : Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add_circle_outline, color: (noStock || cantActual >= insumo.cantidadDisponible) ? Colors.white24 : const Color(0xFF06B6D4)),
                                            onPressed: (noStock || cantActual >= insumo.cantidadDisponible) ? null : () {
                                              setModalState(() => selecciones[insumo.id]!['cantidad']++);
                                            },
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Divider(color: Colors.white10, height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("¿Regresa al almacén después?", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                        Switch(
                                          value: seleccion['esRetornable'],
                                          activeColor: const Color(0xFFFF9800),
                                          inactiveThumbColor: Colors.white54,
                                          inactiveTrackColor: Colors.black26,
                                          onChanged: (bool val) {
                                            setModalState(() => selecciones[insumo.id]!['esRetornable'] = val);
                                          },
                                        ),
                                      ],
                                    )
                                  ]
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // BOTON GUARDAR TODO EL BLOQUE
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4), 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: totalSeleccionados == 0 ? null : () {
                        final agregados = selecciones.values.where((item) => item['cantidad'] > 0).toList();
                        
                        setState(() {
                          for (var nuevoItem in agregados) {
                              int indexExistente = _carrito.indexWhere((c) => c['insumoId'] == nuevoItem['insumoId'] && c['esRetornable'] == nuevoItem['esRetornable']);
                              if (indexExistente >= 0) {
                                 _carrito[indexExistente]['cantidad'] += nuevoItem['cantidad'];
                              } else {
                                 _carrito.add(Map<String, dynamic>.from(nuevoItem));
                              }
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        totalSeleccionados == 0 ? "SELECCIONA HERRAMIENTAS" : "AGREGAR $totalSeleccionados AL CARRITO", 
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}