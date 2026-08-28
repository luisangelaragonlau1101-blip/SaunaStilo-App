import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/proyecto_model.dart';
import 'trabajador_control_herramientas_screen.dart'; 
import 'actividades_trabajador_screen.dart'; 
import 'crear_solicitud_salida_screen.dart'; 
import 'proyecto_chat_screen.dart';

// --- CLASE AUXILIAR PARA EL ESTADO INDIVIDUAL ---
class _ItemEvaluacion {
  final String insumoId;
  final String nombre;
  final int cantidad;
  final bool esRetornable;
  bool tieneFalla;
  final TextEditingController notasController;
  String? fotoRuta;

  _ItemEvaluacion({
    required this.insumoId,
    required this.nombre,
    required this.cantidad,
    required this.esRetornable,
    this.tieneFalla = false,
  }) : notasController = TextEditingController();
}

class ProyectoDetalleTrabajadorScreen extends StatefulWidget {
  final Proyecto proyecto;
  const ProyectoDetalleTrabajadorScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<ProyectoDetalleTrabajadorScreen> createState() => _ProyectoDetalleTrabajadorScreenState();
}

class _ProyectoDetalleTrabajadorScreenState extends State<ProyectoDetalleTrabajadorScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String trabajadorNombre = 'Trabajador';

  @override
  void initState() {
    super.initState();
    _obtenerNombreTrabajador();
  }

  Future<void> _obtenerNombreTrabajador() async {
    if (currentUid.isEmpty) return;
    var doc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUid).get();
    if (doc.exists) {
      if (mounted) {
        setState(() {
          trabajadorNombre = doc.data()?['nombre'] ?? 'Trabajador';
        });
      }
    }
  }

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

  void _abrirDiagnosticoYAvances() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActividadesTrabajadorScreen(
          proyectoId: widget.proyecto.id,
          trabajadorId: currentUid,
          tituloProyecto: widget.proyecto.titulo,
        ),
      ),
    );
  }

  // --- ABRE EL MODAL DE EVALUACIÓN CON FOTO POR PIEZA ---
  void _mostrarModalRecepcionKit(BuildContext context, String solicitudId, List articulos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecepcionKitModal(
        solicitudId: solicitudId, 
        articulos: articulos,
        proyectoId: widget.proyecto.id,
        trabajadorNombre: trabajadorNombre,
      ),
    );
  }

  // --- FUNCIÓN PARA MARCAR PARA DEVOLUCIÓN (ACTUALIZADA) ---
  Future<void> _marcarParaDevolucion(String solicitudId, Map<String, dynamic> dataOriginal) async {
    List articulos = dataOriginal['articulos'] ?? [];
    List reportes = dataOriginal['reportes_danos'] ?? [];
    List<String> herramientasADevolver = [];

    for (var art in articulos) {
      String id = art['insumoId'] ?? art['id'] ?? '';
      int cantidad = int.tryParse(art['cantidad']?.toString() ?? '1') ?? 1;

      // Evaluamos si es retornable
      bool esRetornable = art['esRetornable'] == true || art['esRetornable'] == 'true';

      if (esRetornable) {
        bool estaEnTaller = reportes.any((rep) => 
            (rep['insumoId'] == id) && rep['estatusEvaluacion'] == 'taller');

        if (!estaEnTaller) {
          herramientasADevolver.add("• ${art['nombreInsumo']} (x$cantidad)");
        }
      }
    }

    String tituloModal = herramientasADevolver.isNotEmpty ? "¿Devolver Kit al Almacén?" : "¿Finalizar Kit?";
    String mensajeModal = herramientasADevolver.isNotEmpty 
        ? "¿Confirmas que ya organizaste estas herramientas y están listas para que el almacenista confirme de recibido?"
        : "Este kit no contiene herramientas retornables pendientes (todas se quedan en obra o están en taller). ¿Deseas darlo por finalizado?";

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(tituloModal, 
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensajeModal,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            if (herramientasADevolver.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("Herramientas a devolver:", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 150), 
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: herramientasADevolver.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(h, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    )).toList(),
                  ),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              herramientasADevolver.isNotEmpty ? "Sí, están listas" : "Sí, finalizar", 
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        String estatusFinal = herramientasADevolver.isNotEmpty ? 'en_devolucion' : 'completada';

        await FirebaseFirestore.instance.collection('solicitudes_salida').doc(solicitudId).update({
          'estatus': estatusFinal, 
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.greenAccent,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      herramientasADevolver.isNotEmpty 
                        ? "Kit marcado para devolución. Avisa al almacén."
                        : "Kit cerrado exitosamente.", 
                      style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text("Error al actualizar: $e"))
          );
        }
      }
    }
  }

  // --- FUNCIÓN PARA VER EL ESTATUS DE LOS REPORTES ---
  void _mostrarEstatusDanosTrabajador(BuildContext context, List reportes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text("Estatus de tus Reportes", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: reportes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {

                      var rep = reportes[index];
                      String estatusEval = rep['estatusEvaluacion'] ?? 'pendiente';
                      String estatusRep = rep['estatusReparacionInterno'] ?? ''; 
                      
                      Color colorEst;
                      String textoEst;
                      IconData iconEst;

                      if (estatusRep == 'reparado') {
                          colorEst = Colors.greenAccent;
                          textoEst = "REPARADO Y DISPONIBLE EN ALMACÉN";
                          iconEst = Icons.check_circle_rounded;
                      } else if (estatusEval == 'pendiente') {
                          colorEst = Colors.orangeAccent;
                          textoEst = "EN REVISIÓN POR ALMACÉN";
                          iconEst = Icons.access_time_rounded;
                      } else if (estatusEval == 'taller') {
                          colorEst = Colors.redAccent;
                          textoEst = "APROBADO - EN REPARACIÓN EN TALLER";
                          iconEst = Icons.handyman_rounded;
                      } else {
                          colorEst = const Color(0xFF06B6D4);
                          textoEst = "RECHAZADO - ESTÁ EN BUEN ESTADO";
                          iconEst = Icons.thumb_up_alt_outlined;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorEst.withOpacity(0.3))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(rep['nombreInsumo'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(iconEst, color: colorEst, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(textoEst, style: GoogleFonts.inter(color: colorEst, fontWeight: FontWeight.bold, fontSize: 12))),
                                ]
                              ),
                              if (rep['fotoUrl'] != null && rep['fotoUrl'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(rep['fotoUrl'], height: 120, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),
                          ]
                        )
                      );
                    }
                  )
                )
              ]
            )
          )
        );
      }
    );
  }

  // --- FUNCIÓN PARA RE-SOLICITAR HERRAMIENTAS ---
  Future<void> _solicitarHerramientasReparadas(String solicitudOriginalId, Map<String, dynamic> dataOriginal) async {
    List reportes = dataOriginal['reportes_danos'] ?? [];
    List articulosReparados = [];
    List reportesActualizados = List.from(reportes);
    List<String> herramientasVisuales = []; 

    for (var i = 0; i < reportesActualizados.length; i++) {
      if (reportesActualizados[i]['estatusReparacionInterno'] == 'reparado') {
        articulosReparados.add({
          'insumoId': reportesActualizados[i]['insumoId'],
          'nombreInsumo': reportesActualizados[i]['nombreInsumo'],
          'cantidad': reportesActualizados[i]['cantidad'],
          'esRetornable': true, 
        });
        
        herramientasVisuales.add("• ${reportesActualizados[i]['nombreInsumo']} (x${reportesActualizados[i]['cantidad']})");
        
        reportesActualizados[i]['estatusReparacionInterno'] = 're_solicitado';
      }
    }

    if (articulosReparados.isEmpty) return;

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("¿Volver a solicitar?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Se creará una nueva solicitud para que el almacén te envíe de regreso exclusivamente las siguientes herramientas reparadas:",
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: herramientasVisuales.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(h, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Sí, solicitar", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        DocumentReference nuevaSolicitud = FirebaseFirestore.instance.collection('solicitudes_salida').doc();
        batch.set(nuevaSolicitud, {
          'proyectoId': widget.proyecto.id,
          'usuarioId': currentUid, 
          'solicitanteNombre': trabajadorNombre,
          'articulos': articulosReparados,
          'fechaSolicitud': FieldValue.serverTimestamp(),
          'estatus': 'pendiente',
        });

        DocumentReference viejaSolicitud = FirebaseFirestore.instance.collection('solicitudes_salida').doc(solicitudOriginalId);
        batch.update(viejaSolicitud, {
          'reportes_danos': reportesActualizados,
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.greenAccent,
              content: Text("Solicitud enviada al almacén. Revisa tus pendientes.", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)),
            )
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text("Error al solicitar: $e"))
          );
        }
      }
    }
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
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            title: Text(
              widget.proyecto.titulo.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'Chat y avances del proyecto',
                icon: const Icon(Icons.forum_rounded, color: Color(0xFF70E1D0)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProyectoChatScreen(proyecto: widget.proyecto),
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('actividades')
                    .where('proyectoId', isEqualTo: widget.proyecto.id)
                    .where('asignadoATrabajadorId', isEqualTo: currentUid)
                    .snapshots(),
                builder: (context, badgeSnapshot) {
                  int actividadesPendientes = 0;
                  
                  if (badgeSnapshot.hasData) {
                    actividadesPendientes = badgeSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['estatus'] != 'completado';
                    }).length;
                  }

                  return IconButton(
                    icon: Badge(
                      isLabelVisible: actividadesPendientes > 0,
                      label: Text(
                        '$actividadesPendientes',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      offset: const Offset(4, -4),
                      child: const Icon(Icons.list_alt_rounded, color: Color(0xFF06B6D4), size: 28),
                    ),
                    tooltip: 'Diagnóstico y avances',
                    onPressed: _abrirDiagnosticoYAvances,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(estatusActual),
                const SizedBox(height: 12),
                _buildDiagnosticoYAvancesCard(),
                const SizedBox(height: 24),
                
                Text("DETALLES DEL PROYECTO", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                _buildInfoCard(),
                const SizedBox(height: 24),
                
                _buildDescripcionSection(),
                const SizedBox(height: 28),

                // --- 1. SALIDA DE INSTALACIÓN ---
                Text("SALIDA A INSTALACIÓN", style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, 
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                    label: Text("SOLICITAR HERRAMIENTAS DE SALIDA", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 0.8)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CrearSolicitudSalidaScreen(proyecto: widget.proyecto),
                        ),
                      );
                    },
                  ),
                ),
                _buildListaKitsSalida(),
                const SizedBox(height: 28),

                // --- 2. HERRAMIENTAS DE FABRICACIÓN (TALLER) ---
                Text("HERRAMIENTAS DE TALLER (FABRICACIÓN)", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                _buildBotonControlHerramientas(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(String estatusActual) {
    Color statusColor = estatusActual == 'finalizado'
        ? Colors.greenAccent
        : estatusActual == 'en_proceso'
            ? Colors.cyanAccent
            : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(estatusActual.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildDiagnosticoYAvancesCard() {
    const accentColor = Color(0xFF06B6D4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _abrirDiagnosticoYAvances,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_photo_alternate_outlined, color: accentColor, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MIS TAREAS Y EVIDENCIAS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reporta avances y entrega evidencia obligatoria',
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          FutureBuilder<String>(
            future: _getNombreCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.person_outline, "Cliente", snap.data ?? "Cargando...", const Color(0xFF06B6D4)),
          ),
          const Divider(color: Colors.white10, height: 24),
          FutureBuilder<String>(
            future: _getDireccionCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.location_on_outlined, "Lugar de Entrega", snap.data ?? "Cargando...", const Color(0xFF06B6D4)),
          ),
          const Divider(color: Colors.white10, height: 24),
          FutureBuilder<String>(
            future: _getNombreSauna(widget.proyecto.idSauna),
            builder: (ctx, snap) => _buildDetailRow(Icons.hot_tub, "Tipo de madera", snap.data ?? "Cargando...", const Color(0xFF8B5CF6)),
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildDetailRow(Icons.straighten, "Medidas", widget.proyecto.medidas, const Color(0xFFF59E0B)),
          const Divider(color: Colors.white10, height: 24),
          _buildDetailRow(Icons.calendar_today, "Inicio", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaInicio), const Color(0xFF10B981)),
          const Divider(color: Colors.white10, height: 24),
          _buildDetailRow(Icons.event_available, "Entrega", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaEntrega), const Color(0xFF10B981)),
          const Divider(color: Colors.white10, height: 24),
          _buildDetailRow(
            Icons.local_shipping_outlined, 
            "Salida de Instalación", 
            widget.proyecto.fechaSalidaInstalacion != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaSalidaInstalacion!) 
                : "Sin agendar", 
            Colors.orangeAccent
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
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
        Text("DESCRIPCIÓN", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
          child: Text(
            widget.proyecto.descripcion.isEmpty ? "Sin descripción agregada para este proyecto." : widget.proyecto.descripcion,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBotonControlHerramientas(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ControlHerramientasScreen(
                proyecto: widget.proyecto,
                usuarioId: currentUid,            
                usuarioNombre: trabajadorNombre,  
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.build_circle, color: Color(0xFF06B6D4), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Control de Herramientas (Taller)", 
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Uso diario para fabricación", 
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
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
          return const SizedBox.shrink(); 
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
            const SizedBox(height: 16),
            Text("ESTATUS DE KITS SOLICITADOS:", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String estatus = data['estatus'] ?? 'pendiente';
              List articulos = data['articulos'] ?? [];
              List reportes = data['reportes_danos'] ?? [];
              Timestamp? fecha = data['fechaSolicitud'] as Timestamp?;
              String fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate()) : 'Sin fecha';

              // --- LÓGICA DE CANTIDADES Y REPORTES (ACTUALIZADA) ---
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
              bool hayReparadosDisponibles = false;

              for (var r in reportes) {
                if (r['estatusEvaluacion'] == 'taller') {
                  int cant = int.tryParse(r['cantidad']?.toString() ?? '1') ?? 1;
                  totalAprobadoATaller += cant;
                  
                  String repStatus = r['estatusReparacionInterno'] ?? '';
                  if (repStatus.isNotEmpty && repStatus != 'pendiente' && repStatus != 'en_reparacion') { 
                     totalYaReparado += cant;
                  }
                  
                  if (repStatus == 'reparado') {
                      hayReparadosDisponibles = true;
                  }
                }
              }
              
              bool todoEnTaller = (totalRetornables > 0 && totalAprobadoATaller >= totalRetornables && totalYaReparado < totalAprobadoATaller);
              bool todoReparado = (totalRetornables > 0 && totalAprobadoATaller >= totalRetornables && totalYaReparado >= totalAprobadoATaller);
              bool quedanCosasPorDevolver = totalAprobadoATaller < totalRetornables;

              Color statusColor;
              String estatusText;

              if (estatus == 'pendiente') {
                statusColor = Colors.orangeAccent;
                estatusText = 'PENDIENTE';
              } else if (estatus == 'enviada_a_obra' || estatus == 'aprobada_entregada') { 
                statusColor = Colors.cyanAccent;
                estatusText = 'EN CAMINO / REVISAR';
              } else if (estatus == 'recibida_en_obra') {
                statusColor = Colors.greenAccent;
                estatusText = 'EN TU PODER';
              } else if (estatus == 'recibida_con_danos' || estatus == 'dañado') {
                if (todoEnTaller) {
                  statusColor = Colors.redAccent; 
                  estatusText = 'EN TALLER (REPARACIÓN)';
                } else if (todoReparado) {
                  statusColor = Colors.greenAccent; 
                  estatusText = 'REPARADO Y DISPONIBLE';
                } else {
                  statusColor = Colors.orangeAccent;
                  estatusText = 'EN USO (CON REPORTES)';
                }
              } else if (estatus == 'en_devolucion') { 
                statusColor = Colors.amber;
                estatusText = 'ESPERANDO ALMACÉN';
              } else if (estatus == 'completada' || estatus == 'completada_con_danos') {
                statusColor = Colors.blueAccent;
                estatusText = totalRetornables > 0 ? 'DEVUELTO AL ALMACÉN' : 'CERRADO (SIN RETORNOS)';
              } else {
                statusColor = Colors.white54;
                estatusText = estatus.toUpperCase();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _mostrarDetalleKit(context, data, estatusText, statusColor, fechaStr, reportes),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Kit con ${articulos.length} artículos", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(fechaStr, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusColor.withOpacity(0.5))
                                ),
                                child: Text(estatusText, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // BOTÓN 1: RECIBIR KIT
                  if (estatus == 'enviada_a_obra' || estatus == 'aprobada_entregada')
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: Text("RECIBIR Y EVALUAR KIT", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarModalRecepcionKit(context, doc.id, articulos), 
                        ),
                      ),
                    )
                  // BOTÓN 2: DEVOLVER AL ALMACÉN
                  else if (estatus == 'recibida_en_obra' || (estatus == 'recibida_con_danos' && quedanCosasPorDevolver))
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.assignment_return_rounded),
                          label: Text("DEVOLVER KIT AL ALMACÉN", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _marcarParaDevolucion(doc.id, data), 
                        ),
                      ),
                    ),

                  // BOTÓN 3: VOLVER A SOLICITAR
                  if (hayReparadosDisponibles)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: Text("VOLVER A SOLICITAR REPARADAS", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _solicitarHerramientasReparadas(doc.id, data), 
                        ),
                      ),
                    ),

                  // BOTÓN 4: VER ESTATUS DAÑOS
                  if (reportes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF121212),
                            foregroundColor: Colors.orangeAccent,
                            side: BorderSide(color: Colors.orangeAccent.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: Text("VER ESTATUS DE DAÑOS", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarEstatusDanosTrabajador(context, reportes), 
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

  // --- MODAL PARA VER EL CONTENIDO DEL KIT ---
  void _mostrarDetalleKit(BuildContext context, Map<String, dynamic> data, String estatusText, Color statusColor, String fechaStr, List reportes) {
    List articulos = data['articulos'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70, 
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text("Contenido del Kit", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fechaStr, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.5))
                      ),
                      child: Text(estatusText, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white10),
                ),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: articulos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = articulos[index];
                      final bool esRetornable = item['esRetornable'] == true || item['esRetornable'] == 'true';
                      
                      String? estadoDano;
                      Color? colorDano;
                      try {
                        var reporte = reportes.firstWhere((r) => r['insumoId'] == item['insumoId'] || r['insumoId'] == item['id']);
                        if (reporte['estatusReparacionInterno'] == 'reparado') {
                          estadoDano = "REPARADO (ALMACÉN)";
                          colorDano = Colors.greenAccent;
                        } else if (reporte['estatusReparacionInterno'] == 're_solicitado') {
                          estadoDano = "RE-SOLICITADO";
                          colorDano = const Color(0xFF06B6D4);
                        } else if (reporte['estatusEvaluacion'] == 'taller') {
                          estadoDano = "EN TALLER";
                          colorDano = Colors.redAccent;
                        } else if (reporte['estatusEvaluacion'] == 'pendiente') {
                          estadoDano = "EN REVISIÓN";
                          colorDano = Colors.orangeAccent;
                        }
                      } catch (e) {
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              esRetornable ? Icons.build_rounded : Icons.lightbulb_outline,
                              color: esRetornable ? Colors.orangeAccent : Colors.cyanAccent,
                              size: 28
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['nombreInsumo'] ?? 'Desconocido', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(esRetornable ? "RETORNABLE" : "SE QUEDA EN OBRA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                  
                                  if (estadoDano != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colorDano!.withOpacity(0.1), 
                                        borderRadius: BorderRadius.circular(4), 
                                        border: Border.all(color: colorDano.withOpacity(0.5))
                                      ),
                                      child: Text(estadoDano, style: GoogleFonts.inter(color: colorDano, fontSize: 9, fontWeight: FontWeight.bold)),
                                    )
                                  ]
                                ],
                              ),
                            ),
                            Text("x${item['cantidad']}", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// RECEPCIÓN DEL TRABAJADOR CON EVALUACIÓN FUNCIONAL ESTILO SWITCH
// ============================================================================
class RecepcionKitModal extends StatefulWidget {
  final String solicitudId;
  final List articulos;
  final String proyectoId;
  final String trabajadorNombre;

  const RecepcionKitModal({
    Key? key, 
    required this.solicitudId, 
    required this.articulos,
    required this.proyectoId,
    required this.trabajadorNombre,
  }) : super(key: key);

  @override
  State<RecepcionKitModal> createState() => _RecepcionKitModalState();
}

class _RecepcionKitModalState extends State<RecepcionKitModal> {
  List<_ItemEvaluacion> _items = [];
  bool _subiendoDatos = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.articulos) {
      _items.add(_ItemEvaluacion(
        insumoId: item['insumoId']?.toString() ?? item['id']?.toString() ?? '',
        nombre: item['nombreInsumo']?.toString() ?? 'Herramienta Desconocida',
        cantidad: int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1,
        esRetornable: item['esRetornable'] == true || item['esRetornable'] == 'true',
        tieneFalla: false,
      ));
    }
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.notasController.dispose();
    }
    super.dispose();
  }

  Future<void> _tomarFoto(_ItemEvaluacion item) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() => item.fotoRuta = image.path);
    }
  }

  Future<void> _procesarRecepcion() async {
    setState(() => _subiendoDatos = true);
    
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      DocumentReference solicitudRef = FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId);
      
      bool huboDanos = false;
      List<Map<String, dynamic>> reportesDanos = [];

      for (var item in _items) {
        if (item.insumoId.isEmpty || item.cantidad <= 0) continue;

        if (!item.tieneFalla) {
          DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(item.insumoId);
          batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(-item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)); 
        } else {
          huboDanos = true;
          String urlFinalFoto = "";
          
          if (item.fotoRuta != null) {
            File file = File(item.fotoRuta!);
            String fileName = 'recepciones_obra/${widget.solicitudId}_${item.insumoId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            Reference ref = FirebaseStorage.instance.ref().child(fileName);
            UploadTask uploadTask = ref.putFile(file);
            TaskSnapshot snapshot = await uploadTask;
            urlFinalFoto = await snapshot.ref.getDownloadURL();
          }

          reportesDanos.add({
            'insumoId': item.insumoId,
            'nombreInsumo': item.nombre,
            'cantidad': item.cantidad,
            'notasDelFallo': item.notasController.text.trim(),
            'fotoUrl': urlFinalFoto,
            'estatusEvaluacion': 'pendiente', 
          });
        }
      }

      batch.update(solicitudRef, {
        'estatus': huboDanos ? 'recibida_con_danos' : 'recibida_en_obra',
        'fechaRecepcion': FieldValue.serverTimestamp(),
        'tieneFallasParciales': huboDanos,
        if (huboDanos) 'reportes_danos': reportesDanos,
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: huboDanos ? Colors.orangeAccent : Colors.greenAccent,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  huboDanos ? "Recibido. Espera a que almacén evalúe los daños reportados." : "Todo el kit fue recibido y descontado del almacén.", 
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)
                )),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error al procesar: $e")));
    } finally {
      if (mounted) setState(() => _subiendoDatos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90, 
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(top: 12, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Revisión de Llegada", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Si algo llegó mal, repórtalo para que el almacén evalúe si te la deja o se va a taller.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 24),

                    ..._items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: item.tieneFalla ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.build_circle_outlined, color: item.tieneFalla ? Colors.redAccent : const Color(0xFF06B6D4), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item.nombre, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Text("Cant: ${item.cantidad}", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            
                            SwitchListTile(
                              title: Text("¿Presenta falla o daño?", style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                              subtitle: Text("Activa si llegó roto o incompleto", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                              value: item.tieneFalla,
                              activeColor: Colors.black,
                              activeTrackColor: Colors.redAccent,
                              inactiveThumbColor: Colors.white54,
                              inactiveTrackColor: const Color(0xFF1E1E1E),
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
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 8),
                                    Text("Descripción del problema:", style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: item.notasController,
                                      maxLines: 2,
                                      style: GoogleFonts.inter(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: "Ej. Llegó roto, no enciende...",
                                        hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                        filled: true,
                                        fillColor: const Color(0xFF1E1E1E),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Text("Evidencia Fotográfica:", style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _subiendoDatos ? null : () => _tomarFoto(item), 
                                      child: Container(
                                        width: double.infinity,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: item.fotoRuta != null ? Colors.greenAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: item.fotoRuta == null
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.camera_alt_outlined, color: Color(0xFF06B6D4), size: 24),
                                                  const SizedBox(height: 8),
                                                  Text("Tocar para tomar foto", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                                ],
                                              )
                                            : Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: Image.file(File(item.fotoRuta!), fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(0.6)),
                                                    ),
                                                  ),
                                                  Center(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                                          const SizedBox(width: 8),
                                                          Text("Foto lista", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 4, right: 4,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                                      style: IconButton.styleFrom(backgroundColor: Colors.black54, padding: const EdgeInsets.all(4)),
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
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _subiendoDatos ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded),
                onPressed: _subiendoDatos ? null : _procesarRecepcion,
                label: _subiendoDatos 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        "CONFIRMAR RECEPCIÓN", 
                        style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)
                      ),
              ),
            ) 
          ],
        ),
      ),
    ); 
  }
}
