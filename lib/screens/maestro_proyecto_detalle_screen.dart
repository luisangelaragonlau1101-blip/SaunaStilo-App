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
import 'actividades_admin_screen.dart'; 
import 'trabajador_control_herramientas_screen.dart'; 
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

class ProyectoDetalleMaestroScreen extends StatefulWidget {
  final Proyecto proyecto;
  const ProyectoDetalleMaestroScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<ProyectoDetalleMaestroScreen> createState() => _ProyectoDetalleMaestroScreenState();
}

class _ProyectoDetalleMaestroScreenState extends State<ProyectoDetalleMaestroScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String maestroNombre = 'Maestro';

  static const Color colorFondo = Color(0xFF161210);
  static const Color colorTarjeta = Color(0xFF221A16);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Color(0xFFB5ABA5);
  static const Color colorAcento = Color(0xFFFFDE21);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorVerde = Color(0xFF4CAF50);
  static const Color colorRojo = Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _obtenerNombreMaestro();
  }

  Future<void> _obtenerNombreMaestro() async {
    if (currentUid.isEmpty) return;
    var doc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUid).get();
    if (doc.exists) {
      if (mounted) {
        setState(() {
          maestroNombre = doc.data()?['nombre'] ?? 'Maestro';
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

  void _abrirDiagnosticoYTareas(String estatusActual) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActividadesProyectoScreen(
          proyectoId: widget.proyecto.id,
          estatusProyecto: estatusActual,
          rolUsuario: 'maestro',
        ),
      ),
    );
  }

  void _mostrarModalRecepcionKit(BuildContext context, String solicitudId, List articulos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecepcionKitModal(
        solicitudId: solicitudId, 
        articulos: articulos,
        proyectoId: widget.proyecto.id,
        trabajadorNombre: maestroNombre,
      ),
    );
  }

Future<void> _marcarParaDevolucion(String solicitudId, Map<String, dynamic> dataOriginal) async {
    // 1. Calcular qué herramientas REALMENTE se van a devolver
    List articulos = dataOriginal['articulos'] ?? [];
    List reportes = dataOriginal['reportes_danos'] ?? [];
    List<String> herramientasADevolver = [];

    for (var art in articulos) {
      String id = art['insumoId'] ?? art['id'] ?? '';
      int cantidad = int.tryParse(art['cantidad']?.toString() ?? '1') ?? 1;
      
      // NUEVO: Verificamos si la herramienta es retornable
      bool esRetornable = art['esRetornable'] == true || art['esRetornable'] == 'true';

      // Solo evaluamos y listamos las que SÍ DEBEN regresar al almacén
      if (esRetornable) {
        // Verificamos si esta herramienta en específico está en el taller
        bool estaEnTaller = reportes.any((rep) => 
            (rep['insumoId'] == id) && rep['estatusEvaluacion'] == 'taller');

        if (!estaEnTaller) {
          herramientasADevolver.add("• ${art['nombreInsumo']} (x$cantidad)");
        }
      }
    }

    // Textos dinámicos por si el kit contenía PURAS herramientas que se quedan en obra
    String tituloModal = herramientasADevolver.isNotEmpty ? "¿Devolver Kit al Almacén?" : "¿Finalizar Kit?";
    String mensajeModal = herramientasADevolver.isNotEmpty 
        ? "¿Confirmas que ya organizaste estas herramientas y están listas para que el almacenista confirme de recibido?"
        : "Este kit no contiene herramientas retornables pendientes (todas se quedan en obra o están en taller). ¿Deseas darlo por finalizado?";

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorTarjeta,
        title: Text(tituloModal, 
          style: GoogleFonts.outfit(color: colorTextoPrimario, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensajeModal,
              style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14),
            ),
            if (herramientasADevolver.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("Herramientas a devolver:", style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: herramientasADevolver.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(h, style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 13)),
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
            child: Text("Cancelar", style: GoogleFonts.inter(color: colorTextoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorNaranja),
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
        // Si no hay retornables, el estatus salta directo a 'completada' en lugar de 'en_devolucion'
        String estatusFinal = herramientasADevolver.isNotEmpty ? 'en_devolucion' : 'completada';

        await FirebaseFirestore.instance.collection('solicitudes_salida').doc(solicitudId).update({
          'estatus': estatusFinal, 
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: colorVerde,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      herramientasADevolver.isNotEmpty 
                        ? "Kit marcado para devolución. Avisa al almacén."
                        : "Kit cerrado exitosamente.", 
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)
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
            SnackBar(backgroundColor: colorRojo, content: Text("Error al actualizar: $e"))
          );
        }
      }
    }
  }

  // --- NUEVA FUNCIÓN PARA VER EL ESTATUS DE LOS REPORTES ---
  void _mostrarEstatusDanosMaestro(BuildContext context, List reportes) {
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
              color: colorFondo,
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
                Text("Estatus de tus Reportes", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
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
                          colorEst = colorVerde;
                          textoEst = "REPARADO Y DISPONIBLE EN ALMACÉN";
                          iconEst = Icons.check_circle_rounded;
                      } else if (estatusEval == 'pendiente') {
                          colorEst = colorNaranja;
                          textoEst = "EN REVISIÓN POR ALMACÉN";
                          iconEst = Icons.access_time_rounded;
                      } else if (estatusEval == 'taller') {
                          colorEst = colorRojo;
                          textoEst = "APROBADO - EN REPARACIÓN EN TALLER";
                          iconEst = Icons.handyman_rounded;
                      } else {
                          colorEst = Colors.cyanAccent;
                          textoEst = "RECHAZADO - ESTÁ EN BUEN ESTADO";
                          iconEst = Icons.thumb_up_alt_outlined;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
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
        
        // Marcamos este reporte para que ya no vuelva a salir el botón
        reportesActualizados[i]['estatusReparacionInterno'] = 're_solicitado';
      }
    }

    if (articulosReparados.isEmpty) return;

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorTarjeta,
        title: Text("¿Volver a solicitar?", style: GoogleFonts.outfit(color: colorTextoPrimario, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Se creará una nueva solicitud para que el almacén te envíe de regreso exclusivamente las siguientes herramientas reparadas:",
              style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: herramientasVisuales.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(h, style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 13)),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: colorTextoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorAcento),
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
          'solicitanteNombre': maestroNombre,
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
              backgroundColor: colorVerde,
              content: Text("Solicitud enviada al almacén. Revisa tus pendientes.", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: colorRojo, content: Text("Error al solicitar: $e"))
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
          backgroundColor: colorFondo,
          appBar: AppBar(
            backgroundColor: colorFondo,
            elevation: 0,
            title: Text(widget.proyecto.titulo.toUpperCase(), 
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorTextoPrimario)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: colorTextoPrimario),
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
              IconButton(
                tooltip: 'Diagnóstico y tareas del día',
                icon: const Icon(Icons.assignment_outlined, color: colorAcento),
                onPressed: () => _abrirDiagnosticoYTareas(estatusActual),
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
                _buildDiagnosticoYTareasCard(estatusActual),
                const SizedBox(height: 24),
           
                Text("DETALLES DEL PROYECTO", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                _buildInfoCard(),
                const SizedBox(height: 30),
                _buildDescripcionSection(),
                const SizedBox(height: 30),

                Text("SALIDA A INSTALACIÓN", style: GoogleFonts.inter(color: colorNaranja, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorNaranja,
                    boxShadow: [
                      BoxShadow(color: colorNaranja.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, 
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.local_shipping_rounded, color: Colors.black),
                    label: Text("SOLICITAR HERRAMIENTAS DE SALIDA", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, letterSpacing: 0.8)),
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

                Text("HERRAMIENTAS DE TALLER (FABRICACIÓN)", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                _buildBotonControlHerramientas(context),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatusHeader(String estatusActual) {
    Color statusColor = estatusActual == 'finalizado' 
        ? colorVerde 
        : estatusActual == 'en_proceso' 
            ? Colors.cyanAccent 
            : colorNaranja;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))),
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

  Widget _buildDiagnosticoYTareasCard(String estatusActual) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirDiagnosticoYTareas(estatusActual),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorAcento.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorAcento.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, color: colorAcento, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIAGNÓSTICO Y TAREAS DEL DÍA',
                      style: GoogleFonts.inter(
                        color: colorTextoPrimario,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asigna y revisa avances con evidencia',
                      style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: colorAcento),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorTarjeta, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          FutureBuilder<String>(
            future: _getNombreCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.person_outline, "Cliente", snap.data ?? "Cargando...", Colors.cyanAccent),
          ),
          const Divider(color: Colors.white10, height: 24),
          
          FutureBuilder<String>(
            future: _getDireccionCliente(widget.proyecto.idCliente),
            builder: (ctx, snap) => _buildDetailRow(Icons.location_on_outlined, "Lugar de Entrega", snap.data ?? "Cargando...", Colors.cyanAccent),
          ),
          const Divider(color: Colors.white10, height: 24),

          FutureBuilder<String>(
            future: _getNombreSauna(widget.proyecto.idSauna),
            builder: (ctx, snap) => _buildDetailRow(Icons.hot_tub, "Tipo de madera", snap.data ?? "Cargando...", const Color(0xFF8B5CF6)),
          ),
          const Divider(color: Colors.white10, height: 24),
          
          _buildDetailRow(Icons.straighten, "Medidas", widget.proyecto.medidas, colorNaranja),
          const Divider(color: Colors.white10, height: 24),
          
          _buildDetailRow(Icons.calendar_today, "Inicio", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaInicio), colorVerde),
          const Divider(color: Colors.white10, height: 24),
          
          _buildDetailRow(Icons.event_available, "Entrega", DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaEntrega), colorVerde),
          const Divider(color: Colors.white10, height: 24),

          _buildDetailRow(
            Icons.local_shipping_outlined, 
            "Salida de Instalación", 
            widget.proyecto.fechaSalidaInstalacion != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format(widget.proyecto.fechaSalidaInstalacion!) 
                : "Sin agendar", 
            colorNaranja
          ),
          const Divider(color: Colors.white10, height: 24),
          
          FutureBuilder<String>(
            future: _getNombresEncargados(widget.proyecto.encargados),
            builder: (ctx, snap) => _buildDetailRow(Icons.badge_outlined, "Encargados", snap.data ?? "Cargando...", colorTextoSecundario),
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
              Text(label, style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.w500)),
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
        Text("DESCRIPCIÓN", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colorTarjeta, borderRadius: BorderRadius.circular(16)),
          child: Text(
            widget.proyecto.descripcion.isEmpty ? "Sin descripción agregada para este proyecto." : widget.proyecto.descripcion, 
            style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 15, height: 1.5)
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
                usuarioNombre: maestroNombre,  
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorTarjeta,
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
                        color: colorAcento.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.build_circle, color: colorAcento, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Control de Herramientas (Taller)", 
                            style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Uso diario para fabricación", 
                            style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: colorTextoSecundario, size: 16),
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
            Text("ESTATUS DE KITS SOLICITADOS:", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),

            ...docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String estatus = data['estatus'] ?? 'pendiente';
              List articulos = data['articulos'] ?? [];
              List reportes = data['reportes_danos'] ?? [];
              Timestamp? fecha = data['fechaSolicitud'] as Timestamp?;
              String fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate()) : 'Sin fecha';

              // --- LÓGICA UNIFICADA: VERIFICAR TALLER Y REPARACIONES ---
              int totalArticulos = 0;
              for (var a in articulos) {
                totalArticulos += int.tryParse(a['cantidad']?.toString() ?? '1') ?? 1;
              }
              
              int totalAprobadoATaller = 0;
              int totalYaReparado = 0;
              bool hayReparadosDisponibles = false;

              for (var r in reportes) {
                if (r['estatusEvaluacion'] == 'taller') {
                  int cant = int.tryParse(r['cantidad']?.toString() ?? '1') ?? 1;
                  totalAprobadoATaller += cant;
                  
                  String repStatus = r['estatusReparacionInterno'] ?? '';
                  // ESTE ES EL CORAZÓN DEL ARREGLO:
                  if (repStatus.isNotEmpty && repStatus != 'pendiente' && repStatus != 'en_reparacion') { 
                     totalYaReparado += cant;
                  }
                  
                  // Validar botón de solicitar (solo si no se ha pedido antes)
                  if (repStatus == 'reparado') {
                      hayReparadosDisponibles = true;
                  }
                }
              }
              
              bool todoEnTaller = (totalArticulos > 0 && totalAprobadoATaller >= totalArticulos && totalYaReparado < totalAprobadoATaller);
              bool todoReparado = (totalArticulos > 0 && totalAprobadoATaller >= totalArticulos && totalYaReparado >= totalAprobadoATaller);
              
          int totalRetornables = articulos.where((a) => a['esRetornable'] == true || a['esRetornable'] == 'true').map((a) => int.tryParse(a['cantidad']?.toString() ?? '1') ?? 1).fold(0, (prev, cant) => prev + cant);
bool quedanCosasPorDevolver = totalAprobadoATaller < totalRetornables;

              Color statusColor;
              String estatusText;

              if (estatus == 'pendiente') {
                statusColor = colorAcento;
                estatusText = 'PENDIENTE';
              } else if (estatus == 'enviada_a_obra' || estatus == 'aprobada_entregada') { 
                statusColor = Colors.cyanAccent;
                estatusText = 'EN CAMINO / REVISAR';
              } else if (estatus == 'recibida_en_obra') {
                statusColor = colorVerde;
                estatusText = 'EN TU PODER';
              } else if (estatus == 'recibida_con_danos' || estatus == 'dañado') {
                if (todoEnTaller) {
                  statusColor = colorRojo; 
                  estatusText = 'EN TALLER (REPARACIÓN)';
                } else if (todoReparado) {
                  statusColor = colorVerde; 
                  estatusText = 'REPARADO Y DISPONIBLE';
                } else {
                  statusColor = colorNaranja;
                  estatusText = 'EN USO (CON REPORTES)';
                }
              } else if (estatus == 'en_devolucion') { 
                statusColor = Colors.amber;
                estatusText = 'ESPERANDO ALMACÉN';
              } else if (estatus == 'completada' || estatus == 'completada_con_danos') {
                // UNIFICADO CON ALMACÉN (Color azul y texto exacto)
                statusColor = Colors.blueAccent;
                estatusText = 'DEVUELTO AL ALMACÉN';
              } else {
                statusColor = colorTextoSecundario;
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
                            color: colorTarjeta,
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
                                    Text("Kit con ${articulos.length} artículos", style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(fechaStr, style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 11)),
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
                            backgroundColor: colorVerde,
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

                  // BOTÓN 3: VOLVER A SOLICITAR (YA CORREGIDO)
                  if (hayReparadosDisponibles)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorAcento,
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
                            backgroundColor: colorFondo,
                            foregroundColor: colorNaranja,
                            side: BorderSide(color: colorNaranja.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: Text("VER ESTATUS DE DAÑOS", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarEstatusDanosMaestro(context, reportes), 
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
              color: colorFondo,
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
                Text("Contenido del Kit", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fechaStr, style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
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
                          colorDano = colorVerde;
                        } else if (reporte['estatusReparacionInterno'] == 're_solicitado') {
                          estadoDano = "RE-SOLICITADO";
                          colorDano = colorAcento;
                        } else if (reporte['estatusEvaluacion'] == 'taller') {
                          estadoDano = "EN TALLER";
                          colorDano = colorRojo;
                        } else if (reporte['estatusEvaluacion'] == 'pendiente') {
                          estadoDano = "EN REVISIÓN";
                          colorDano = colorNaranja;
                        }
                      } catch (e) {
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              esRetornable ? Icons.build_rounded : Icons.lightbulb_outline,
                              color: esRetornable ? colorNaranja : Colors.cyanAccent,
                              size: 28
                            ),
                            const SizedBox(width: 16),
                           Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['nombreInsumo'] ?? 'Desconocido', style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(esRetornable ? "RETORNABLE" : "SE QUEDA EN OBRA", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 10, fontWeight: FontWeight.bold)),
                                  
                                  // ETIQUETA VISUAL DE DAÑO
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
                            Text("x${item['cantidad']}", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 18, fontWeight: FontWeight.bold)),
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
// RECEPCIÓN DEL MAESTRO CON EVALUACIÓN FUNCIONAL ESTILO SWITCH
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
  static const Color colorFondo = Color(0xFF161210);
  static const Color colorTarjeta = Color(0xFF221A16);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Color(0xFFB5ABA5);
  static const Color colorAcento = Color(0xFFFFDE21);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorVerde = Color(0xFF4CAF50);
  static const Color colorRojo = Color(0xFFFF5252);

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
          // LLEGÓ BIEN A LA OBRA -> SE DESCUENTA DEL ALMACÉN DE INMEDIATO
          DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(item.insumoId);
          batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(-item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)); 
        } else {
          // LLEGÓ MAL -> SE REPORTA AL ADMIN Y NO SE DESCUENTA TODAVÍA
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
            'estatusEvaluacion': 'pendiente', // <--- Se queda pendiente para que el admin lo decida
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
            backgroundColor: huboDanos ? colorNaranja : colorVerde,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: huboDanos ? Colors.black : Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  huboDanos ? "Recibido. Espera a que almacén evalúe los daños reportados." : "Todo el kit fue recibido y descontado del almacén.", 
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: huboDanos ? Colors.black : Colors.white)
                )),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: colorRojo, content: Text("Error al procesar: $e")));
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
          color: colorFondo,
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
                    Text("Revisión de Llegada", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Si algo llegó mal, repórtalo para que el almacén evalúe si te la deja o se va a taller.", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
                    const SizedBox(height: 24),

                    ..._items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: item.tieneFalla ? colorNaranja.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.build_circle_outlined, color: item.tieneFalla ? colorNaranja : colorAcento, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item.nombre, style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Text("Cant: ${item.cantidad}", style: GoogleFonts.outfit(color: colorTextoSecundario, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            
                            // --- SWITCH ESTILO FUNCIONAL ---
                            SwitchListTile(
                              title: Text("¿Presenta falla o daño?", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.w500)),
                              subtitle: Text("Activa si llegó roto o incompleto", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12)),
                              value: item.tieneFalla,
                              activeColor: Colors.black,
                              activeTrackColor: colorNaranja,
                              inactiveThumbColor: colorTextoSecundario,
                              inactiveTrackColor: colorFondo,
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

                            // --- SECCIÓN DE REPORTES SI ESTÁ DAÑADO ---
                            if (item.tieneFalla)
                              Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 8),
                                    Text("Descripción del problema:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: item.notasController,
                                      maxLines: 2,
                                      style: GoogleFonts.inter(color: colorTextoPrimario),
                                      decoration: InputDecoration(
                                        hintText: "Ej. Llegó roto, no enciende...",
                                        hintStyle: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13),
                                        filled: true,
                                        fillColor: colorFondo,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Text("Evidencia Fotográfica:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _subiendoDatos ? null : () => _tomarFoto(item), 
                                      child: Container(
                                        width: double.infinity,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: colorFondo,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: item.fotoRuta != null ? colorVerde.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: item.fotoRuta == null
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.camera_alt_outlined, color: colorAcento, size: 24),
                                                  const SizedBox(height: 8),
                                                  Text("Tocar para tomar foto", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12)),
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
                                                          const Icon(Icons.check_circle_rounded, color: colorVerde, size: 16),
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
                  backgroundColor: colorVerde,
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
