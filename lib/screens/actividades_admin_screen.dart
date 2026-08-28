import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import '../services/actividades_service.dart';
import 'admin_modal_detalle_actividad.dart';
import 'modal_asignar_actividades.dart';

class ActividadesProyectoScreen extends StatelessWidget {
  final String proyectoId;
  final String estatusProyecto;
  final String rolUsuario; // <--- 1. AGREGAMOS EL ROL

  const ActividadesProyectoScreen({
    Key? key, 
    required this.proyectoId, 
    required this.estatusProyecto,
    required this.rolUsuario, // <--- 2. LO PEDIMOS AQUÍ
  }) : super(key: key);

  // Instancia del servicio de actividades
  ActividadesService get _actividadesService => ActividadesService();

  // Función para mostrar el diálogo de eliminación
  void _mostrarDialogoEliminar(BuildContext context, ActividadModel actividad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar Actividad',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la actividad "${actividad.titulo}"? Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              try {
                await _actividadesService.eliminarActividad(actividad.id);

                if (context.mounted) {
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Actividad eliminada', style: GoogleFonts.inter()),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e', style: GoogleFonts.inter()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          'DIAGNÓSTICO Y TAREAS',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEncabezado(),
            const SizedBox(height: 20),
            StreamBuilder<List<ActividadModel>>(
              stream: _actividadesService.obtenerActividadesPorProyecto(proyectoId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.red.withOpacity(0.2),
                    child: Text("ERROR LEYENDO FIREBASE:\n${snapshot.error}",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      "Todavía no hay tareas asignadas para este proyecto.",
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final actividades = [...snapshot.data!]
                  ..sort((a, b) {
                    final aEsHoy = _esHoy(a.fechaAsignada);
                    final bEsHoy = _esHoy(b.fechaAsignada);
                    if (aEsHoy != bEsHoy) return aEsHoy ? -1 : 1;
                    return b.fechaAsignada.compareTo(a.fechaAsignada);
                  });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: actividades.length,
                  itemBuilder: (context, index) {
                    final actividad = actividades[index];
                    bool estaAtrasada = actividad.estatus != 'completado' && DateTime.now().isAfter(actividad.fechaTermino);

                    return _buildColorfulCard(context, actividad, estaAtrasada);
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: estatusProyecto == 'finalizado'
          ? null 
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFDE21),
              foregroundColor: Colors.black87,
              elevation: 4,
              icon: const Icon(Icons.add_task),
              label: Text(
                'Asignar tarea del día',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
             onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent, 
                  builder: (context) => ModalAsignarActividad(
                    proyectoId: proyectoId,
                    rolUsuario: rolUsuario, // <--- AGREGAR AQUÍ
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEncabezado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDE21).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFFFFDE21)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASIGNA Y REVISA EL TRABAJO DEL DÍA',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Asigna tareas a cada trabajador y revisa sus avances. Para terminar una tarea deberán adjuntar evidencia obligatoria.',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _esHoy(DateTime fecha) {
    final ahora = DateTime.now();
    return fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;
  }

  Widget _buildColorfulCard(BuildContext context, ActividadModel actividad, bool estaAtrasada) {
    List<Color> gradientColors;
    Color iconColor;
    String badgeText = actividad.estatus.replaceAll('_', ' ').toUpperCase();
    final esHoy = _esHoy(actividad.fechaAsignada);

    if (actividad.estatus == 'completado') {
      gradientColors = [const Color(0xFF0F766E), const Color(0xFF064E3B)]; 
      iconColor = Colors.tealAccent;
    } else if (estaAtrasada) {
      gradientColors = [const Color(0xFF991B1B), const Color(0xFF7F1D1D)]; 
      iconColor = Colors.redAccent;
      badgeText = 'ATRASADO';
    } else if (actividad.estatus == 'en_progreso') {
      gradientColors = [const Color(0xFF1E3A8A), const Color(0xFF312E81)]; 
      iconColor = Colors.cyanAccent;
    } else {
      gradientColors = [const Color(0xFFB45309), const Color(0xFF78350F)]; 
      iconColor = const Color(0xFFFFDE21);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ModalDetalleActividad(actividad: actividad),
            );
          },
          onLongPress: () {
            _mostrarDialogoEliminar(context, actividad);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        actividad.titulo.toUpperCase(),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    
                    if (actividad.estatus == 'pendiente')
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                        onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ModalAsignarActividad(
                                proyectoId: proyectoId,
                                rolUsuario: rolUsuario, // <--- AGREGAR AQUÍ TAMBIÉN
                                actividadAEditar: actividad, 
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: iconColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.inter(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.event_available_outlined, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tarea asignada: ${DateFormat('dd MMM yyyy').format(actividad.fechaAsignada)}",
                        style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (esHoy)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDE21),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'HOY',
                          style: GoogleFonts.inter(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        estaAtrasada ? Icons.timer_off_outlined : Icons.access_time_filled,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        estaAtrasada
                            ? "Venció el: ${DateFormat('dd MMM yyyy - HH:mm').format(actividad.fechaTermino)}"
                            : "Límite: ${DateFormat('dd MMM yyyy - HH:mm').format(actividad.fechaTermino)}",
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(actividad.asignadoATrabajadorId)
                      .get()
                      .then((doc) => doc.exists ? (doc.data() as Map)['nombre'] ?? 'Sin nombre' : 'No encontrado'),
                  builder: (context, userSnap) {
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Asignado: ${userSnap.data ?? 'Cargando...'}",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.white54, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      actividad.totalEvidencias == 1
                          ? '1 evidencia adjunta'
                          : '${actividad.totalEvidencias} evidencias adjuntas',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
