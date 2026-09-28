import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import 'trabajador_modal_detalle_actividad.dart';

class ActividadesTrabajadorScreen extends StatelessWidget {
  final String proyectoId;
  final String trabajadorId;
  final String tituloProyecto;

  ActividadesTrabajadorScreen({
    Key? key,
    required this.proyectoId,
    required this.trabajadorId,
    required this.tituloProyecto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text(
          "DIAGNÓSTICO Y AVANCES",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: StiloColors.text),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: StiloColors.text),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              tituloProyecto.toUpperCase(),
              style: GoogleFonts.inter(color: Color(0xFFFFDE21), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: _buildEncabezado(),
          ),
          Expanded(
            child: _buildListaActividades(),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezado() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFDE21).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.add_a_photo_outlined, color: Color(0xFFFFDE21)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REPORTA TU AVANCE',
                  style: GoogleFonts.inter(color: StiloColors.text, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Abre cada tarea para describir tu avance y subir todas las fotos o archivos que necesites. La evidencia es obligatoria para terminar.',
                  style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .60), fontSize: 12, height: 1.4),
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

  Widget _buildListaActividades() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('actividades')
          .where('proyectoId', isEqualTo: proyectoId)
          .where('asignadoATrabajadorId', isEqualTo: trabajadorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("ERROR LEYENDO FIREBASE:\n${snapshot.error}", style: TextStyle(color: Colors.red)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "No tienes actividades asignadas aún.",
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 16),
            ),
          );
        }

        final actividades = snapshot.data!.docs
            .map((doc) => ActividadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList()
          ..sort((a, b) {
            final aEsHoy = _esHoy(a.fechaAsignada);
            final bEsHoy = _esHoy(b.fechaAsignada);
            if (aEsHoy != bEsHoy) return aEsHoy ? -1 : 1;
            return b.fechaAsignada.compareTo(a.fechaAsignada);
          });

        return ListView.builder(
          padding: EdgeInsets.all(20),
          itemCount: actividades.length,
          itemBuilder: (context, index) {
            final actividad = actividades[index];
            bool estaAtrasada = actividad.estatus != 'completado' && DateTime.now().isAfter(actividad.fechaTermino);

            return _buildColorfulCard(context, actividad, estaAtrasada);
          },
        );
      },
    );
  }

  Widget _buildColorfulCard(BuildContext context, ActividadModel actividad, bool estaAtrasada) {
    // Configuración de paletas de colores basada en el estatus (Inspiración Impresionista)
    List<Color> gradientColors;
    Color iconColor;
    String badgeText = actividad.estatus.replaceAll('_', ' ').toUpperCase();
    final esHoy = _esHoy(actividad.fechaAsignada);

    if (actividad.estatus == 'completado') {
      gradientColors = [StiloColors.border, StiloColors.surface]; // Verdes profundos
      iconColor = Colors.tealAccent;
    } else if (estaAtrasada) {
      gradientColors = [Color(0xFF991B1B), Color(0xFF7F1D1D)]; // Rojos profundos
      iconColor = Colors.redAccent;
      badgeText = 'ATRASADO';
    } else if (actividad.estatus == 'en_progreso') {
      gradientColors = [Color(0xFF1E3A8A), Color(0xFF312E81)]; // Azules nocturnos
      iconColor = Colors.cyanAccent;
    } else {
      gradientColors = [Color(0xFFB45309), StiloColors.border]; // Dorados/Ocres
      iconColor = Color(0xFFFFDE21);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
            offset: Offset(0, 4),
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
          child: Padding(
            padding: EdgeInsets.all(20),
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
                        style: GoogleFonts.inter(color: StiloColors.text, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 12),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: StiloColors.background.withValues(alpha: .38),
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
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.event_available_outlined, color: StiloColors.text.withValues(alpha: .70), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tarea asignada: ${DateFormat('dd MMM yyyy').format(actividad.fechaAsignada)}",
                        style: GoogleFonts.inter(color: StiloColors.text.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (esHoy)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFDE21),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'HOY',
                          style: GoogleFonts.inter(color: StiloColors.background.withValues(alpha: .87), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: StiloColors.background.withValues(alpha: .26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        estaAtrasada ? Icons.timer_off_outlined : Icons.access_time_filled,
                        color: StiloColors.text.withValues(alpha: .70),
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        estaAtrasada
                            ? "Venció el: ${DateFormat('dd MMM yyyy - HH:mm').format(actividad.fechaTermino)}"
                            : "Límite: ${DateFormat('dd MMM yyyy - HH:mm').format(actividad.fechaTermino)}",
                        style: GoogleFonts.inter(
                          color: StiloColors.text.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.attach_file, color: StiloColors.text.withValues(alpha: .54), size: 17),
                    SizedBox(width: 8),
                    Text(
                      actividad.totalEvidencias == 1
                          ? '1 evidencia adjunta'
                          : '${actividad.totalEvidencias} evidencias adjuntas',
                      style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12, fontStyle: FontStyle.italic),
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
