import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/proyecto_model.dart';
import 'gestionar_solicitudes_salida_screen.dart';
import 'proyecto_chat_screen.dart';

// --- CLASE AUXILIAR PARA LA VERIFICACIÓN DEL ALMACÉN ---
class _ItemVerificacionAlmacen {
  final String insumoId;
  final String nombre;
  final int cantidad;
  bool tieneFalla;
  final TextEditingController notasController;
  String? fotoRuta;

  _ItemVerificacionAlmacen({
    required this.insumoId,
    required this.nombre,
    required this.cantidad,
    this.tieneFalla = false,
  }) : notasController = TextEditingController();
}

class ProyectoDetalleAlmacenistaScreen extends StatefulWidget {
  final Proyecto proyecto;
  const ProyectoDetalleAlmacenistaScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<ProyectoDetalleAlmacenistaScreen> createState() => _ProyectoDetalleAlmacenistaScreenState();
}

class _ProyectoDetalleAlmacenistaScreenState extends State<ProyectoDetalleAlmacenistaScreen> {

  Future<String> _getNombreCliente(String id) async {
    if (id.isEmpty) return 'Sin asignar';
    try {
      var doc = await FirebaseFirestore.instance.collection('clientes').doc(id).get();
      return doc.exists ? (doc.data() as Map)['nombre'] ?? 'Sin nombre' : 'Cliente no encontrado';
    } catch (e) {
      return 'Error de conexión';
    }
  }

  Future<String> _getDireccionCliente(String id) async {
    if (id.isEmpty) return 'N/A';
    try {
      var doc = await FirebaseFirestore.instance.collection('clientes').doc(id).get();
      return doc.exists ? (doc.data() as Map)['direccion'] ?? 'Sin dirección registrada' : 'N/A';
    } catch (e) {
      return 'Error de conexión';
    }
  }

  Future<String> _getNombreSauna(String id) async {
    if (id.isEmpty) return 'Sin asignar';
    try {
      var doc = await FirebaseFirestore.instance.collection('cat_saunas').doc(id).get();
      return doc.exists ? (doc.data() as Map)['nombre'] ?? 'Sin nombre' : 'Sauna no encontrada';
    } catch (e) {
      return 'Error de conexión';
    }
  }

  Future<String> _getNombresEncargados(List<dynamic> encargadosRaw) async {
    if (encargadosRaw.isEmpty) return 'Sin encargados asignados';
    try {
      List<String> ids = encargadosRaw.map((e) => e.toString()).toList();
      var snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      if (snap.docs.isEmpty) return 'Usuarios no encontrados';
      return snap.docs.map((doc) => doc.data()['nombre'].toString()).join(', ');
    } catch (e) {
      return 'Error al cargar encargados';
    }
  }

  Future<String> _getNombreTrabajador(String id) async {
    if (id.isEmpty) return 'Trabajador no identificado';
    try {
      var doc = await FirebaseFirestore.instance.collection('usuarios').doc(id).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        return data['nombre'] ?? 'Sin nombre';
      }
      return 'Usuario no encontrado';
    } catch (e) {
      return 'Error de conexión';
    }
  }

  // --- FUNCIÓN PARA ABRIR MODAL DE EVALUACIÓN DE DAÑOS ---
  void _mostrarModalEvaluarDanosAlmacen(BuildContext context, String solicitudId, String proyectoId, String maestroNombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EvaluarDanosAlmacenModal(
        solicitudId: solicitudId,
        proyectoId: proyectoId,
        maestroNombre: maestroNombre,
      ),
    );
  }

  // --- FUNCIÓN PARA ENVIAR EL KIT ---
  Future<void> _enviarKit(String solicitudId) async {
    try {
      await FirebaseFirestore.instance.collection('solicitudes_salida').doc(solicitudId).update({
        'estatus': 'enviada_a_obra',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: StiloColors.text),
              SizedBox(width: 12),
              Expanded(child: Text("Kit enviado a obra exitosamente.", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold))),
            ],
          )
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error al enviar: $e")));
      }
    }
  }

  // --- FUNCIÓN PARA MOSTRAR LOS ARTÍCULOS DEL KIT Y BOTÓN DE ENVÍO ---
  void _mostrarDetalleKit(BuildContext context, String solicitudId, String estatus, List articulos) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: StiloColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: StiloColors.text.withValues(alpha: .10))),
          title: Row(
            children: [
              Icon(Icons.handyman, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text("Contenido del Kit", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: articulos.length,
              separatorBuilder: (context, index) => Divider(color: StiloColors.text.withValues(alpha: .10)),
              itemBuilder: (context, index) {
                var item = articulos[index];
                int cantidad = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;

                // NUEVO: Identificamos si es retornable para la UI
                bool esRet = item['esRetornable'] == true || item['esRetornable'] == 'true';

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(esRet ? Icons.build_circle_outlined : Icons.lightbulb_outline, color: esRet ? Colors.orangeAccent : Colors.cyanAccent, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['nombreInsumo'] ?? 'Herramienta', style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14)),
                            Text(esRet ? "RETORNABLE" : "SE QUEDA EN OBRA", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 10, fontWeight: FontWeight.bold)),
                          ]
                        )
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: StiloColors.text.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
                        child: Text("x$cantidad", style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(estatus == 'pendiente' ? "Cancelar" : "Cerrar", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70))),
            ),
            if (estatus == 'pendiente')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: StiloColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                icon: Icon(Icons.local_shipping, size: 18),
                label: Text("Enviar Kit", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _enviarKit(solicitudId);
                },
              ),
          ],
        );
      }
    );
  }

  // --- FUNCIÓN PARA ABRIR MODAL DE RECEPCIÓN (EL NUEVO ESTILO MAESTRO) ---
  void _mostrarModalRecepcionAlmacen(BuildContext context, String solicitudId, Map<String, dynamic> dataOriginal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VerificarRecepcionAlmacenModal(
        solicitudId: solicitudId,
        dataOriginal: dataOriginal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('proyectos').doc(widget.proyecto.id).snapshots(),
      builder: (context, snapshot) {

        String estatusActual = widget.proyecto.estatus;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          estatusActual = data['estatus'] ?? widget.proyecto.estatus;
        }

        return Scaffold(
          backgroundColor: StiloColors.surface,
          appBar: AppBar(
            backgroundColor: StiloColors.surface,
            elevation: 0,
            title: Text(widget.proyecto.titulo.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            centerTitle: true,
            iconTheme: IconThemeData(color: StiloColors.text),
            actions: [
              IconButton(
                tooltip: 'Chat y avances del proyecto',
                icon: Icon(Icons.forum_rounded, color: Color(0xFF70E1D0)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProyectoChatScreen(proyecto: widget.proyecto),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(estatusActual),
                SizedBox(height: 24),

                Text("DETALLES DEL PROYECTO", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                SizedBox(height: 12),
                _buildInfoCard(),
                SizedBox(height: 30),
                _buildDescripcionSection(),
                SizedBox(height: 30),

                _buildListaKitsSalida(),

                SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatusHeader(String estatusActual) {
    Color statusColor = estatusActual == 'finalizado'
        ? Colors.greenAccent
        : estatusActual == 'en_proceso'
            ? Colors.cyanAccent
            : Colors.orangeAccent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: statusColor, size: 20),
          SizedBox(width: 8),
          Text(estatusActual.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: StiloColors.text.withValues(alpha: .10))),
      child: Column(
        children: [
          FutureBuilder<String>(
            future: _getNombreCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.person_outline, "Cliente", snap.data ?? "Cargando...", Color(0xFF06B6D4)),
          ),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          FutureBuilder<String>(
            future: _getDireccionCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.location_on_outlined, "Lugar de Entrega", snap.data ?? "Cargando...", Color(0xFF06B6D4)),
          ),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          FutureBuilder<String>(
            future: _getNombreSauna(widget.proyecto.idSauna),
            builder: (ctx, snap) => _buildDetailRow(Icons.hot_tub, "Tipo de madera", snap.data ?? "Cargando...", StiloColors.accent),
          ),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          _buildDetailRow(Icons.straighten, "Medidas", widget.proyecto.medidas, Color(0xFFF59E0B)),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          _buildDetailRow(Icons.calendar_today, "Inicio", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaInicio), Color(0xFF10B981)),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          _buildDetailRow(Icons.event_available, "Entrega", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaEntrega), Color(0xFF10B981)),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          _buildDetailRow(
            Icons.local_shipping_outlined,
            "Salida de Instalación",
            widget.proyecto.fechaSalidaInstalacion != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaSalidaInstalacion!)
                : "Sin agendar",
            Colors.orangeAccent
          ),
          Divider(color: StiloColors.text.withValues(alpha: .10), height: 24),

          FutureBuilder<String>(
            future: _getNombresEncargados(widget.proyecto.encargados),
            builder: (ctx, snap) => _buildDetailRow(Icons.badge_outlined, "Encargados", snap.data ?? "Cargando...", StiloColors.text.withValues(alpha: .70)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
              SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(color: StiloColors.text, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescripcionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DESCRIPCIÓN", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Text(
            widget.proyecto.descripcion.isEmpty ? "Sin descripción agregada para este proyecto." : widget.proyecto.descripcion,
            style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 15, height: 1.5)
          ),
        ),
      ],
    );
  }

  Widget _buildListaKitsSalida() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_salida')
          .where('proyectoId', isEqualTo: widget.proyecto.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox.shrink();
        }

        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['fechaSolicitud'] as Timestamp?;
          Timestamp? tB = (b.data() as Map<String, dynamic>)['fechaSolicitud'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ESTATUS DE KITS DEL PROYECTO", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            SizedBox(height: 12),

            ...docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String estatus = data['estatus'] ?? 'pendiente';
              List articulos = data['articulos'] ?? [];
              List reportes = data['reportes_danos'] ?? [];
              Timestamp? fecha = data['fechaSolicitud'] as Timestamp?;
              String fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate()) : 'Sin fecha';

              String usuarioSolicitanteId = data['usuarioId'] ?? data['solicitanteId'] ?? '';

              bool tienePendientesPorRevisar = reportes.any((r) => r['estatusEvaluacion'] == 'pendiente');

              // --- CAMBIO AQUÍ: CALCULAR RETORNABLES ---
              int totalArticulos = 0;
              int totalRetornables = 0;

              for (var a in articulos) {
                int cant = int.tryParse(a['cantidad']?.toString() ?? '1') ?? 1;
                totalArticulos += cant;

                if (a['esRetornable'] == true || a['esRetornable'] == 'true') {
                  totalRetornables += cant;
                }
              }

              int totalAprobadoATaller = 0;
              int totalYaReparado = 0;

              for (var r in reportes) {
                if (r['estatusEvaluacion'] == 'taller') {
                  int cant = int.tryParse(r['cantidad']?.toString() ?? '1') ?? 1;
                  totalAprobadoATaller += cant;
                  String repStatus = r['estatusReparacionInterno'] ?? '';
                  if (repStatus.isNotEmpty && repStatus != 'pendiente' && repStatus != 'en_reparacion') {
                     totalYaReparado += cant;
                  }
                }
              }

              // Basamos la lógica de "todo en taller" solo en las retornables
              bool todoEnTaller = (totalRetornables > 0 && totalAprobadoATaller >= totalRetornables && totalYaReparado < totalAprobadoATaller);
              bool todoReparado = (totalRetornables > 0 && totalAprobadoATaller >= totalRetornables && totalYaReparado >= totalAprobadoATaller);

              Color statusColor;
              String estatusText;

              if (estatus == 'pendiente') {
                statusColor = Colors.yellowAccent;
                estatusText = 'NUEVA SOLICITUD';
              } else if (estatus == 'enviada_a_obra' || estatus == 'aprobada_entregada') {
                statusColor = Colors.cyanAccent;
                estatusText = 'EN TRÁNSITO A OBRA';
              } else if (estatus == 'recibida_en_obra') {
                statusColor = Colors.greenAccent;
                estatusText = 'EN USO POR MAESTRO';
              } else if (estatus == 'recibida_con_danos' || estatus == 'dañado') {
                if (todoEnTaller) {
                  statusColor = Colors.redAccent;
                  estatusText = 'EN TALLER (REPARACIÓN)';
                } else if (todoReparado) {
                  statusColor = Colors.greenAccent;
                  estatusText = 'REPARADO Y DISPONIBLE';
                } else {
                  statusColor = Colors.orangeAccent;
                  estatusText = 'EN USO (DAÑOS REPORTADOS)';
                }
              } else if (estatus == 'en_devolucion') {
                statusColor = Colors.amber;
                estatusText = 'LISTO PARA RECIBIR (DEVOLUCIÓN)';
              } else if (estatus == 'completada' || estatus == 'completada_con_danos') {
                statusColor = Colors.blueAccent;
                // Diferenciamos si se devolvió algo o si todo se quedó en obra
                estatusText = totalRetornables > 0 ? 'DEVUELTO AL ALMACÉN' : 'CERRADO (SIN RETORNOS)';
              } else {
                statusColor = StiloColors.text.withValues(alpha: .54);
                estatusText = estatus.toUpperCase();
              }

              return Column(
                children: [
                  GestureDetector(
                    onTap: () => _mostrarDetalleKit(context, doc.id, estatus, articulos),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: StiloColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                        boxShadow: [
                          if (estatus == 'pendiente')
                            BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 24),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Kit con ${articulos.length} artículos", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                                    SizedBox(height: 6),
                                    FutureBuilder<String>(
                                      future: _getNombreTrabajador(usuarioSolicitanteId),
                                      builder: (context, snapshot) {
                                        return Row(
                                          children: [
                                            Icon(Icons.person, color: Color(0xFF06B6D4), size: 14),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                snapshot.data ?? 'Cargando...',
                                                style: GoogleFonts.inter(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    ),
                                    SizedBox(height: 6),
                                    Text(fechaStr, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.5))
                              ),
                              child: Text(estatusText, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  // --- BOTONES ---
                  if (estatus == 'recibida_con_danos' && tienePendientesPorRevisar)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: StiloColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.plumbing),
                          label: Text("EVALUAR DAÑOS EN OBRA", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarModalEvaluarDanosAlmacen(context, doc.id, widget.proyecto.id, data['solicitanteNombre'] ?? 'Trabajador'),
                        ),
                      ),
                    ),

                  if (estatus == 'en_devolucion')
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: StiloColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.checklist_rtl),
                          label: Text("INSPECCIONAR Y RECIBIR KIT", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarModalRecepcionAlmacen(context, doc.id, data),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

// ============================================================================
// MODAL PARA QUE EL ALMACENISTA EVALUE LOS REPORTES HECHOS POR EL MAESTRO
// ============================================================================
class EvaluarDanosAlmacenModal extends StatefulWidget {
  final String solicitudId;
  final String proyectoId;
  final String maestroNombre;

  const EvaluarDanosAlmacenModal({Key? key, required this.solicitudId, required this.proyectoId, required this.maestroNombre}) : super(key: key);

  @override
  State<EvaluarDanosAlmacenModal> createState() => _EvaluarDanosAlmacenModalState();
}

class _EvaluarDanosAlmacenModalState extends State<EvaluarDanosAlmacenModal> {
  int? _procesandoIndex;

  Future<void> _evaluar(int indexInArray, String decision, List reportesActuales, Map item) async {
    setState(() => _procesandoIndex = indexInArray);
    try {
      List actualizados = List.from(reportesActuales);
      actualizados[indexInArray]['estatusEvaluacion'] = decision;

      WriteBatch batch = FirebaseFirestore.instance.batch();
      DocumentReference solRef = FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId);
      batch.update(solRef, {'reportes_danos': actualizados});

      int cantidad = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
      DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(item['insumoId']);

      if (decision == 'taller') {
        DocumentReference tallerRef = FirebaseFirestore.instance.collection('reparaciones_taller').doc();
        batch.set(tallerRef, {
            'insumoId': item['insumoId'],
            'nombreInsumo': item['nombreInsumo'],
            'cantidad': cantidad,
            'origen': 'recepcion_obra_evaluada',
            'proyectoId': widget.proyectoId,
            'reportadoPor': widget.maestroNombre,
            'fechaIngreso': FieldValue.serverTimestamp(),
            'estatus': 'en_reparacion',
            'notasDelFallo': item['notasDelFallo'],
            'fotoUrl': item['fotoUrl'],
        });

        batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(-cantidad),
            'en_reparacion': FieldValue.increment(cantidad),
        }, SetOptions(merge: true));

      } else if (decision == 'rechazado') {
        batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(-cantidad),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Evaluación guardada con éxito", style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green
        ));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al evaluar: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _procesandoIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: StiloColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.orangeAccent));

            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return Center(child: Text("Sin datos"));

            List reportes = data['reportes_danos'] ?? [];
            var pendientesList = reportes.asMap().entries.where((e) => e.value['estatusEvaluacion'] == 'pendiente').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: StiloColors.text.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text("Evaluar Daños de Obra", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Determina si las herramientas que reportó el maestro van al taller.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13)),
                SizedBox(height: 16),

                if (pendientesList.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
                          SizedBox(height: 16),
                          Text("¡Todos los reportes evaluados!", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      physics: BouncingScrollPhysics(),
                      itemCount: pendientesList.length,
                      separatorBuilder: (_, __) => SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        int indexEnArreglo = pendientesList[idx].key;
                        Map item = pendientesList[idx].value;
                        bool procesandoEste = _procesandoIndex == indexEnArreglo;

                        return Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StiloColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nombreInsumo'] ?? '', style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text("Cantidad reportada: ${item['cantidad']}", style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              SizedBox(height: 12),

                              if (item['notasDelFallo'] != null && item['notasDelFallo'].toString().isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: StiloColors.background.withValues(alpha: .26), borderRadius: BorderRadius.circular(8)),
                                  child: Text('"${item['notasDelFallo']}"', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontStyle: FontStyle.italic)),
                                ),

                              if (item['fotoUrl'] != null && item['fotoUrl'].toString().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(item['fotoUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),

                              SizedBox(height: 16),

                              if (procesandoEste)
                                Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: StiloColors.text.withValues(alpha: .10), foregroundColor: StiloColors.text, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        icon: Icon(Icons.close, size: 16),
                                        label: Text("Rechazar", style: GoogleFonts.inter(fontSize: 12)),
                                        onPressed: () => _evaluar(indexEnArreglo, 'rechazado', reportes, item),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: StiloColors.text, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        icon: Icon(Icons.handyman_rounded, size: 16),
                                        label: Text("Al Taller", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () => _evaluar(indexEnArreglo, 'taller', reportes, item),
                                      ),
                                    ),
                                  ],
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  )
              ],
            );
          }
        )
      )
    );
  }
}

// ============================================================================
// NUEVO MODAL INTERACTIVO DE RECEPCIÓN (ESTILO MAESTRO)
// ============================================================================
class VerificarRecepcionAlmacenModal extends StatefulWidget {
  final String solicitudId;
  final Map<String, dynamic> dataOriginal;

  const VerificarRecepcionAlmacenModal({Key? key, required this.solicitudId, required this.dataOriginal}) : super(key: key);

  @override
  State<VerificarRecepcionAlmacenModal> createState() => _VerificarRecepcionAlmacenModalState();
}

class _VerificarRecepcionAlmacenModalState extends State<VerificarRecepcionAlmacenModal> {
  List<_ItemVerificacionAlmacen> _itemsAVerificar = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _prepararLista();
  }

  void _prepararLista() {
    List articulos = widget.dataOriginal['articulos'] ?? [];
    List reportes = widget.dataOriginal['reportes_danos'] ?? [];

    for (var item in articulos) {
      bool esRetornable = item['esRetornable'] == true || item['esRetornable'] == 'true';
      String insumoId = item['insumoId']?.toString() ?? item['id']?.toString() ?? '';

      bool estaEnTaller = reportes.any((rep) => (rep['insumoId'] == insumoId) && rep['estatusEvaluacion'] == 'taller');

      if (esRetornable && !estaEnTaller && insumoId.isNotEmpty) {
        _itemsAVerificar.add(_ItemVerificacionAlmacen(
          insumoId: insumoId,
          nombre: item['nombreInsumo'] ?? 'Herramienta',
          cantidad: int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1,
          tieneFalla: false,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (var item in _itemsAVerificar) {
      item.notasController.dispose();
    }
    super.dispose();
  }

  Future<void> _tomarFoto(_ItemVerificacionAlmacen item) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() => item.fotoRuta = image.path);
    }
  }

  // NUEVO MÉTODO: Si no hay nada que retornar, cerramos el kit directo
  Future<void> _cerrarKitDirecto() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId).update({
        'estatus': 'completada',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
          content: Text("Kit cerrado correctamente (sin retornos).", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: StiloColors.text)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmarIngreso() async {
    setState(() => _isProcessing = true);

    bool tieneFallasPrevias = widget.dataOriginal['tieneFallasParciales'] == true;
    List reportesAnteriores = widget.dataOriginal['reportes_danos'] ?? [];
    List nuevosReportes = [];
    bool nuevosDanos = false;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var item in _itemsAVerificar) {
        DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(item.insumoId);

        if (!item.tieneFalla) {
          // LLEGÓ BIEN -> REGRESA AL INVENTARIO
          batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // ALMACENISTA DETECTA DAÑO -> SE VA A TALLER INMEDIATAMENTE
          nuevosDanos = true;
          String urlFinalFoto = "";

          if (item.fotoRuta != null) {
            File file = File(item.fotoRuta!);
            String fileName = 'recepciones_almacen/${widget.solicitudId}_${item.insumoId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            Reference ref = FirebaseStorage.instance.ref().child(fileName);
            UploadTask uploadTask = ref.putFile(file);
            TaskSnapshot snapshot = await uploadTask;
            urlFinalFoto = await snapshot.ref.getDownloadURL();
          }

          // 1. Crear documento en el taller
          DocumentReference tallerRef = FirebaseFirestore.instance.collection('reparaciones_taller').doc();
          batch.set(tallerRef, {
              'insumoId': item.insumoId,
              'nombreInsumo': item.nombre,
              'cantidad': item.cantidad,
              'origen': 'recepcion_almacen_directa',
              'proyectoId': widget.dataOriginal['proyectoId'] ?? '',
              'reportadoPor': 'Almacén (Inspección)',
              'fechaIngreso': FieldValue.serverTimestamp(),
              'estatus': 'en_reparacion',
              'notasDelFallo': item.notasController.text.trim(),
              'fotoUrl': urlFinalFoto,
          });

          // 2. Desviar la cantidad a "en_reparacion"
          batch.set(insumoRef, {
            'en_reparacion': FieldValue.increment(item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 3. Añadirlo al historial del kit como un reporte ya evaluado
          nuevosReportes.add({
            'insumoId': item.insumoId,
            'nombreInsumo': item.nombre,
            'cantidad': item.cantidad,
            'notasDelFallo': item.notasController.text.trim(),
            'fotoUrl': urlFinalFoto,
            'estatusEvaluacion': 'taller', // Va directo a taller porque el almacenista lo ordenó
          });
        }
      }

      // Combinar los reportes viejos (del maestro) con los nuevos del almacén
      List reportesActualizados = List.from(reportesAnteriores)..addAll(nuevosReportes);

      // Actualizamos estatus de la solicitud
      DocumentReference solicitudRef = FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId);
      batch.update(solicitudRef, {
        'estatus': (tieneFallasPrevias || nuevosDanos) ? 'completada_con_danos' : 'completada',
        'reportes_danos': reportesActualizados,
        if (nuevosDanos) 'tieneFallasParciales': true,
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating, backgroundColor: nuevosDanos ? Colors.orangeAccent : Colors.green,
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: nuevosDanos ? StiloColors.background : StiloColors.text),
              SizedBox(width: 12),
              Expanded(child: Text(
                nuevosDanos ? "Revisión lista. Herramientas dañadas enviadas al taller." : "Revisión exitosa. Kit reingresado a almacén.",
                style: GoogleFonts.inter(color: nuevosDanos ? StiloColors.background : StiloColors.text, fontWeight: FontWeight.bold)
              )),
            ],
          )
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: StiloColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(top: 12, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: StiloColors.text.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),

            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Inspección de Recepción", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Verifica cada herramienta. Si detectas un daño, repórtalo para enviarla al taller.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13)),
                    SizedBox(height: 24),

                    if (_itemsAVerificar.isEmpty)
                      Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("No hay herramientas retornables para verificar en este kit. Puedes cerrar el registro.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), height: 1.5), textAlign: TextAlign.center),
                      ))
                    else
                      ..._itemsAVerificar.map((item) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: StiloColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: item.tieneFalla ? Colors.orangeAccent.withOpacity(0.5) : StiloColors.text.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.build_circle_outlined, color: item.tieneFalla ? Colors.orangeAccent : Colors.cyanAccent, size: 28),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(item.nombre, style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    Text("Cant: ${item.cantidad}", style: GoogleFonts.outfit(color: StiloColors.text.withValues(alpha: .54), fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              SwitchListTile(
                                title: Text("¿Llegó con falla o daño?", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 15, fontWeight: FontWeight.w500)),
                                subtitle: Text("Mándala a taller si está averiada", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
                                value: item.tieneFalla,
                                activeColor: StiloColors.background,
                                activeTrackColor: Colors.orangeAccent,
                                inactiveThumbColor: StiloColors.text.withValues(alpha: .54),
                                inactiveTrackColor: StiloColors.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onChanged: (bool value) {
                                  setState(() {
                                    item.tieneFalla = value;
                                    if (!value) {
                                      item.notasController.clear();
                                      item.fotoRuta = null;
                                    }
                                  });
                                },
                              ),

                              if (item.tieneFalla)
                                Padding(
                                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Divider(color: StiloColors.text.withValues(alpha: .10)),
                                      SizedBox(height: 8),
                                      Text("Descripción del daño:", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 8),
                                      TextField(contextMenuBuilder: privacyTextMenu,
                                        controller: item.notasController,
                                        maxLines: 2,
                                        style: GoogleFonts.inter(color: StiloColors.text),
                                        decoration: InputDecoration(
                                          hintText: "Ej. Falta una pieza, el motor suena mal...",
                                          hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13),
                                          filled: true,
                                          fillColor: StiloColors.surface,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                      SizedBox(height: 16),

                                      Text("Evidencia Fotográfica:", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: _isProcessing ? null : () => _tomarFoto(item),
                                        child: Container(
                                          width: double.infinity,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: StiloColors.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: item.fotoRuta != null ? Colors.greenAccent.withOpacity(0.5) : StiloColors.text.withOpacity(0.1),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: item.fotoRuta == null
                                              ? Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.camera_alt_outlined, color: Colors.cyanAccent, size: 24),
                                                    SizedBox(height: 8),
                                                    Text("Tocar para tomar foto", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
                                                  ],
                                                )
                                              : Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Image.file(File(item.fotoRuta!), fit: BoxFit.cover, opacity: AlwaysStoppedAnimation(0.6)),
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(color: StiloColors.background.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                                            SizedBox(width: 8),
                                                            Text("Foto lista", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 4, right: 4,
                                                      child: IconButton(
                                                        icon: Icon(Icons.close_rounded, color: StiloColors.text, size: 18),
                                                        style: IconButton.styleFrom(backgroundColor: StiloColors.background.withValues(alpha: .54), padding: EdgeInsets.all(4)),
                                                        onPressed: () => setState(() => item.fotoRuta = null),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              // BOTÓN CONDICIONAL: Cambia de estilo si no hay nada que retornar
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _itemsAVerificar.isEmpty ? Colors.blueAccent : Colors.amber,
                  foregroundColor: _itemsAVerificar.isEmpty ? StiloColors.text : StiloColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isProcessing ? SizedBox.shrink() : Icon(_itemsAVerificar.isEmpty ? Icons.check_circle : Icons.inventory_2),
                onPressed: _isProcessing ? null : (_itemsAVerificar.isEmpty ? _cerrarKitDirecto : _confirmarIngreso),
                label: _isProcessing
                    ? CircularProgressIndicator(color: StiloColors.background)
                    : Text(
                        _itemsAVerificar.isEmpty ? "CERRAR KIT DIRECTO" : "CONFIRMAR RECEPCIÓN",
                        style: GoogleFonts.outfit(color: _itemsAVerificar.isEmpty ? StiloColors.text : StiloColors.background, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
