import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminSolicitudesHerramientasScreen extends StatefulWidget {
  const AdminSolicitudesHerramientasScreen({Key? key}) : super(key: key);

  @override
  State<AdminSolicitudesHerramientasScreen> createState() => _AdminSolicitudesHerramientasScreenState();
}

class _AdminSolicitudesHerramientasScreenState extends State<AdminSolicitudesHerramientasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          "CONTROL DE HERRAMIENTAS",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFDE21),
          labelColor: const Color(0xFFFFDE21),
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "NUEVAS"),
            Tab(text: "EN PRÉSTAMO"),
            Tab(text: "HISTORIAL"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaPorEstatus(['pendiente']), // Pendientes
          _buildListaPrestamosActivos(),        // Aprobadas, retornables y no devueltas
          _buildListaPorEstatus(['rechazada', 'aprobada']), // Historial general (filtrado adentro)
        ],
      ),
    );
  }

  // --- BUILDER PRINCIPAL DE LISTAS ---
  Widget _buildListaPorEstatus(List<String> estatusFiltro) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_herramientas')
          .where('estatus', whereIn: estatusFiltro)
          .orderBy('fechaSolicitud', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)));
        }
        
        var docs = snapshot.data?.docs ?? [];
        
        // Filtro especial para el historial (ocultar las que siguen en préstamo)
        if (estatusFiltro.contains('aprobada') && estatusFiltro.contains('rechazada')) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final esRetornable = data['esRetornable'] ?? false;
            final devueltoAdmin = data['devueltoConfirmadoAdmin'] ?? false;
            if (data['estatus'] == 'aprobada' && esRetornable && !devueltoAdmin) return false;
            return true;
          }).toList();
        }

        if (docs.isEmpty) {
          return _buildEmptyState("No hay solicitudes en esta sección.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildSolicitudCard(docs[index], isHistorial: estatusFiltro.length > 1);
          },
        );
      },
    );
  }

  // --- BUILDER PARA PRÉSTAMOS ACTIVOS ---
  Widget _buildListaPrestamosActivos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_herramientas')
          .where('estatus', isEqualTo: 'aprobada')
          .where('esRetornable', isEqualTo: true)
          .where('devueltoConfirmadoAdmin', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState("No hay herramientas en préstamo activo.");

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildSolicitudCard(docs[index], isPrestamo: true),
        );
      },
    );
  }

  // --- TARJETA DE SOLICITUD ---
  Widget _buildSolicitudCard(DocumentSnapshot doc, {bool isHistorial = false, bool isPrestamo = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final String id = doc.id;
    final String trabajador = data['trabajadorNombre'] ?? 'Desconocido';
    final String insumo = data['nombreInsumo'] ?? 'Sin nombre';
    final int cantidad = data['cantidad'] ?? 1;
    final bool esRetornable = data['esRetornable'] ?? false;
    final String estatus = data['estatus'] ?? 'pendiente';
    final String? notaAdmin = data['notaAdmin'];
    final bool marcadoDevuelto = data['marcadoDevueltoTrabajador'] ?? false;
    final Timestamp? limiteTs = data['fechaLimiteDevolucion'];
    
    // Extraer los nuevos campos de devolución
    final bool tieneFalla = data['tieneReporteFalla'] ?? false;
    final String? observaciones = data['observacionesDevolucion'];
    final String? fotoUrl = data['fotoDevolucionUrl'];
    
    bool estaAtrasada = false;
    if (isPrestamo && limiteTs != null) {
      estaAtrasada = DateTime.now().isAfter(limiteTs.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estaAtrasada 
            ? Colors.redAccent.withOpacity(0.5) 
            : tieneFalla ? Colors.orangeAccent.withOpacity(0.5) : Colors.white10,
          width: estaAtrasada || tieneFalla ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER CARD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trabajador.toUpperCase(),
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              _buildBadgeEstatus(estatus, esRetornable, isPrestamo, marcadoDevuelto),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          
          // INFO INSUMO
          Row(
            children: [
              Icon(esRetornable ? Icons.handyman_rounded : Icons.format_paint_rounded, color: const Color(0xFFFFDE21), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insumo, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "Cantidad solicitada: $cantidad  •  ${esRetornable ? 'RETORNABLE' : 'CONSUMIBLE'}",
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // NOTA ADMIN (Stock 0 o requiere compra)
          if (notaAdmin != null && notaAdmin.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(notaAdmin, style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],

          // NUEVO: SECCIÓN DE REPORTE DE DEVOLUCIÓN
          if (marcadoDevuelto || isHistorial && (observaciones != null || tieneFalla)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tieneFalla ? Colors.redAccent.withOpacity(0.1) : Colors.cyanAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tieneFalla ? Colors.redAccent.withOpacity(0.3) : Colors.cyanAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(tieneFalla ? Icons.warning_rounded : Icons.info_outline, 
                          color: tieneFalla ? Colors.redAccent : Colors.cyanAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        tieneFalla ? "REPORTE DE DAÑO" : "Nota del trabajador",
                        style: GoogleFonts.inter(
                          color: tieneFalla ? Colors.redAccent : Colors.cyanAccent, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                  if (observaciones != null && observaciones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('"$observaciones"', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                  if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _mostrarFotoEvidencia(context, fotoUrl),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_outlined, color: Colors.white54, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Ver foto adjunta", 
                            style: GoogleFonts.inter(color: Colors.lightBlueAccent, fontSize: 13, decoration: TextDecoration.underline)
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],

          // FECHA LÍMITE (Si está en préstamo)
          if (isPrestamo && limiteTs != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: estaAtrasada ? Colors.redAccent : Colors.cyanAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  estaAtrasada ? "VENCIDO: ${DateFormat('dd/MM HH:mm').format(limiteTs.toDate())}" : "Límite: ${DateFormat('dd/MM/yyyy HH:mm').format(limiteTs.toDate())}",
                  style: GoogleFonts.inter(color: estaAtrasada ? Colors.redAccent : Colors.cyanAccent, fontSize: 12, fontWeight: estaAtrasada ? FontWeight.bold : FontWeight.normal),
                ),
              ],
            ),
          ],

          // BOTONES DE ACCIÓN
          if (estatus == 'pendiente') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _actualizarEstatus(id, 'rechazada', data),
                    child: Text("Rechazar", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _aprobarSolicitud(id, data),
                    child: Text("Aprobar", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],

          if (isPrestamo) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: marcadoDevuelto ? Colors.cyanAccent : Colors.white10,
                  foregroundColor: marcadoDevuelto ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _confirmarDevolucion(id, data),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  marcadoDevuelto 
                    ? (tieneFalla ? "Confirmar Recepción (Con Daño)" : "Confirmar Recepción") 
                    : "Forzar Recepción (No marcado)",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  void _mostrarFotoEvidencia(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: const Color(0xFF161B22),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21))),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: const Color(0xFF161B22),
              child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 50)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _aprobarSolicitud(String idSolicitud, Map<String, dynamic> data) async {
    final bool esRetornable = data['esRetornable'] ?? false;
    final String? insumoId = data['insumoId'];
    final int cantidad = data['cantidad'] ?? 1;
    
    if (insumoId == null || insumoId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text("Error: El campo 'insumoId' está vacío."))
        );
      }
      return;
    }

    Map<String, dynamic> updates = {'estatus': 'aprobada'};
    if (esRetornable) {
      updates['fechaLimiteDevolucion'] = DateTime.now().add(const Duration(hours: 24));
    }

    try {
      final docInsumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);
      final docSolicitudRef = FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(idSolicitud);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docInsumo = await transaction.get(docInsumoRef);
        
        if (!docInsumo.exists) {
          throw Exception("El insumo con ID '$insumoId' no existe en el inventario.");
        }

        final dataInsumo = docInsumo.data() as Map<String, dynamic>;
        final dynamic cantidadActualRaw = dataInsumo['cantidad_disponible'];        
        final int actual = (cantidadActualRaw is num) ? cantidadActualRaw.toInt() : int.tryParse(cantidadActualRaw.toString()) ?? 0;

        if (actual >= cantidad) {
          transaction.update(docInsumoRef, {'cantidad_disponible': actual - cantidad});
          updates['notaAdmin'] = ""; 
        } else {
          updates['notaAdmin'] = "¡AGOTADO! Se aprobó sin stock suficiente en almacén. Requiere compra urgente.";
        }

        transaction.update(docSolicitudRef, updates);
      });
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("Solicitud procesada correctamente."))
        );
      }
    } catch (e) {
      print("Error en _aprobarSolicitud: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"))
        );
      }
    }
  }

  Future<void> _actualizarEstatus(String idSolicitud, String nuevoEstatus, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(idSolicitud).update({'estatus': nuevoEstatus});
  }

 Future<void> _confirmarDevolucion(String idSolicitud, Map<String, dynamic> data) async {
    final String insumoId = data['insumoId'];
    final int cantidad = data['cantidad'] ?? 1;
    final bool tieneFalla = data['tieneReporteFalla'] ?? false; 

    try {
      final docInsumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);
      final docSolicitudRef = FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(idSolicitud);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docInsumo = await transaction.get(docInsumoRef);
        
        if (docInsumo.exists) {
          final dataInsumo = docInsumo.data() as Map<String, dynamic>;
          
          if (!tieneFalla) {
            // --- FLUJO NORMAL: Se suma al stock disponible ---
            final dynamic cantidadActualRaw = dataInsumo['cantidad_disponible'];          
            final int actual = (cantidadActualRaw is num) ? cantidadActualRaw.toInt() : int.tryParse(cantidadActualRaw.toString()) ?? 0;

            transaction.update(docInsumoRef, {'cantidad_disponible': actual + cantidad});
          } else {
            // --- NUEVO FLUJO CON DAÑO: Se suma al contador de reparación ---
            final dynamic cantidadReparacionRaw = dataInsumo['en_reparacion'];          
            final int actualReparacion = (cantidadReparacionRaw is num) ? cantidadReparacionRaw.toInt() : int.tryParse(cantidadReparacionRaw.toString()) ?? 0;

            transaction.update(docInsumoRef, {'en_reparacion': actualReparacion + cantidad});
          }
        }

        // Marcamos la solicitud como finalizada/devuelta por el admin
        transaction.update(docSolicitudRef, {
          'devueltoConfirmadoAdmin': true,
        });
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: tieneFalla ? Colors.orange : Colors.cyan, 
            content: Text(tieneFalla 
              ? "Recepción confirmada. Enviada a la sección de reparaciones." 
              : "Herramienta regresada al inventario."
            )
          )
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: $e"))
        );
      }
    }
  }

  // --- COMPONENTES VISUALES SECUNDARIOS ---
  Widget _buildBadgeEstatus(String estatus, bool retornable, bool isPrestamo, bool marcadoDevuelto) {
    Color bg = Colors.white10;
    Color text = Colors.white;
    String label = estatus.toUpperCase();

    if (estatus == 'pendiente') {
      bg = Colors.orange.withOpacity(0.15);
      text = Colors.orangeAccent;
    } else if (estatus == 'rechazada') {
      bg = Colors.red.withOpacity(0.15);
      text = Colors.redAccent;
    } else if (estatus == 'aprobada') {
      if (isPrestamo) {
        if (marcadoDevuelto) {
          bg = Colors.cyan.withOpacity(0.15);
          text = Colors.cyanAccent;
          label = "LISTO P/ RECIBIR";
        } else {
          bg = Colors.blue.withOpacity(0.15);
          text = Colors.lightBlueAccent;
          label = "EN USO";
        }
      } else {
        bg = Colors.green.withOpacity(0.15);
        text = Colors.greenAccent;
        label = retornable ? "DEVUELTO" : "ENTREGADO (Consumido)";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.inter(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_rounded, color: Colors.white24, size: 60),
          const SizedBox(height: 16),
          Text(mensaje, style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}