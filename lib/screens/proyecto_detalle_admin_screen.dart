import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/proyecto_model.dart';
import '../services/proyecto_service.dart';
import 'actividades_admin_screen.dart'; 
import 'gestionar_solicitudes_salida_screen.dart';

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

class ProyectoDetalleAdminScreen extends StatefulWidget {
  final Proyecto proyecto;
  const ProyectoDetalleAdminScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<ProyectoDetalleAdminScreen> createState() => _ProyectoDetalleAdminScreenState();
}

class _ProyectoDetalleAdminScreenState extends State<ProyectoDetalleAdminScreen> {
  final ProyectoService _proyectoService = ProyectoService();

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
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("Kit enviado a obra exitosamente.", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
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
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
          title: Row(
            children: [
              const Icon(Icons.handyman, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Text("Contenido del Kit", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: articulos.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                var item = articulos[index];
                int cantidad = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
                
                // Identificamos si es retornable para la UI
                bool esRet = item['esRetornable'] == true || item['esRetornable'] == 'true';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(esRet ? Icons.build_circle_outlined : Icons.lightbulb_outline, color: esRet ? Colors.orangeAccent : Colors.cyanAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['nombreInsumo'] ?? 'Herramienta', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                            Text(esRet ? "RETORNABLE" : "SE QUEDA EN OBRA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          ]
                        )
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
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
              child: Text(estatus == 'pendiente' ? "Cancelar" : "Cerrar", style: GoogleFonts.inter(color: Colors.white70)),
            ),
            if (estatus == 'pendiente')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                icon: const Icon(Icons.local_shipping, size: 18),
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

  void _abrirDiagnosticoYTareas(String estatusActual) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActividadesProyectoScreen(
          proyectoId: widget.proyecto.id,
          estatusProyecto: estatusActual,
          rolUsuario: 'admin',
        ),
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
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            title: Text(widget.proyecto.titulo.toUpperCase(), 
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            centerTitle: true,
            actions: [
              // --- INICIO DEL BOTÓN CON NOTIFICACIÓN ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('solicitudes_salida')
                    .where('proyectoId', isEqualTo: widget.proyecto.id)
                    .where('estatus', isEqualTo: 'pendiente')
                    .snapshots(),
                builder: (context, snapshot) {
                  int pendientes = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  
                  return IconButton(
                    tooltip: 'Solicitudes de Salida',
                    icon: Badge(
                      isLabelVisible: pendientes > 0,
                      label: Text(pendientes.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.handyman_outlined, color: Color(0xFF06B6D4)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GestionarSolicitudesSalidaScreen(proyecto: widget.proyecto)),
                      );
                    },
                  );
                },
              ),
              // --- FIN DEL BOTÓN CON NOTIFICACIÓN ---

              // Ícono de enrutamiento a la pantalla de actividades
              IconButton(
                tooltip: 'Diagnóstico y tareas del día',
                icon: const Icon(Icons.assignment_outlined, color: Color(0xFFFFDE21)),
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
                Text("INFORMACIÓN FINANCIERA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                _buildFinanzasCard(),
                const SizedBox(height: 24),
                Text("DETALLES DEL PROYECTO", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 12),
               _buildInfoCard(),
                const SizedBox(height: 30),
                _buildDescripcionSection(),
                const SizedBox(height: 30),
                
                // --- SECCIÓN AGREGADA: KITS DE SALIDA (ALMACÉN) ---
                _buildListaKitsSalida(),
                
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
        ? Colors.greenAccent 
        : estatusActual == 'en_proceso' 
            ? Colors.cyanAccent 
            : Colors.orangeAccent;

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
    const accentColor = Color(0xFFFFDE21);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirDiagnosticoYTareas(estatusActual),
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
              const Icon(Icons.assignment_turned_in_outlined, color: accentColor, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIAGNÓSTICO Y TAREAS DEL DÍA',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asigna y revisa avances con evidencia',
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

  Widget _buildFinanzasCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _proyectoService.getFinanzasStream(widget.proyecto.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(color: Color(0xFFFFDE21));
        }
        
        double cotizacion = 0.0;
        double pagoInicial = 0.0;
        double montoPagado = 0.0;

        if (snapshot.hasData && snapshot.data!.exists) {
           var data = snapshot.data!.data() as Map<String, dynamic>?;
           cotizacion = (data?['cotizacion'] ?? 0.0).toDouble();
           pagoInicial = (data?['pago_inicial'] ?? 0.0).toDouble();
           montoPagado = (data?['monto_pagado'] ?? 0.0).toDouble();
        }

        double restante = cotizacion - montoPagado;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFDE21).withOpacity(0.3))),
          child: Column(
            children: [
              _buildFinanzasRow("Cotización Total:", cotizacion, const Color(0xFFFFDE21)),
              const Divider(color: Colors.white10, height: 20),
              _buildFinanzasRow("Pago Inicial (Anticipo):", pagoInicial, Colors.white70),
              const Divider(color: Colors.white10, height: 20),
              _buildFinanzasRow("Monto Total Pagado:", montoPagado, Colors.greenAccent),
              const Divider(color: Colors.white10, height: 20),
              _buildFinanzasRow("Saldo Restante por Pagar:", restante, Colors.orangeAccent, resaltar: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinanzasRow(String etiqueta, double valor, Color colorValor, {bool resaltar = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            etiqueta, 
            style: GoogleFonts.inter(color: Colors.white70, fontSize: resaltar ? 14 : 13, fontWeight: resaltar ? FontWeight.bold : FontWeight.normal)
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "\$${valor.toStringAsFixed(2)}", 
          style: GoogleFonts.inter(color: colorValor, fontSize: resaltar ? 18 : 15, fontWeight: FontWeight.bold)
        ),
      ],
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
          const Divider(color: Colors.white10, height: 24),
          
          FutureBuilder<String>(
            future: _getNombresEncargados(widget.proyecto.encargados),
            builder: (ctx, snap) => _buildDetailRow(Icons.badge_outlined, "Encargados", snap.data ?? "Cargando...", Colors.white70),
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
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 15, height: 1.5)
          ),
        ),
      ],
    );
  }

  // --- COMPONENTE AGREGADO: LISTA DE KITS DE SALIDA (ALMACÉN) ---
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
            Text("ESTATUS DE KITS DEL PROYECTO", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            const SizedBox(height: 12),

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
                statusColor = Colors.white54;
                estatusText = estatus.toUpperCase();
              }

              return Column(
                children: [
                  GestureDetector(
                    onTap: () => _mostrarDetalleKit(context, doc.id, estatus, articulos),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                        boxShadow: [
                          if (estatus == 'pendiente')
                            BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Kit con ${articulos.length} artículos", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 6),
                                    FutureBuilder<String>(
                                      future: _getNombreTrabajador(usuarioSolicitanteId),
                                      builder: (context, snapshot) {
                                        return Row(
                                          children: [
                                            const Icon(Icons.person, color: Color(0xFF06B6D4), size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                snapshot.data ?? 'Cargando...', 
                                                style: GoogleFonts.inter(color: const Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    ),
                                    const SizedBox(height: 6),
                                    Text(fechaStr, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.plumbing),
                          label: Text("EVALUAR DAÑOS EN OBRA", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarModalEvaluarDanosAlmacen(context, doc.id, widget.proyecto.id, data['solicitanteNombre'] ?? 'Trabajador'), 
                        ),
                      ),
                    ),

                  if (estatus == 'en_devolucion')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.checklist_rtl),
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
// MODAL PARA EVALUAR LOS REPORTES HECHOS POR EL MAESTRO
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
          content: Text("Evaluación guardada con éxito", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)), 
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
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
            
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Center(child: Text("Sin datos"));

            List reportes = data['reportes_danos'] ?? [];
            var pendientesList = reportes.asMap().entries.where((e) => e.value['estatusEvaluacion'] == 'pendiente').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text("Evaluar Daños de Obra", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Determina si las herramientas que reportó el maestro van al taller.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),

                if (pendientesList.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
                          const SizedBox(height: 16),
                          Text("¡Todos los reportes evaluados!", style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: pendientesList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        int indexEnArreglo = pendientesList[idx].key;
                        Map item = pendientesList[idx].value;
                        bool procesandoEste = _procesandoIndex == indexEnArreglo;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nombreInsumo'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Cantidad reportada: ${item['cantidad']}", style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              
                              if (item['notasDelFallo'] != null && item['notasDelFallo'].toString().isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                  child: Text('"${item['notasDelFallo']}"', style: GoogleFonts.inter(color: Colors.white70, fontStyle: FontStyle.italic)),
                                ),

                              if (item['fotoUrl'] != null && item['fotoUrl'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(item['fotoUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),

                              const SizedBox(height: 16),
                              
                              if (procesandoEste)
                                const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: Text("Rechazar", style: GoogleFonts.inter(fontSize: 12)),
                                        onPressed: () => _evaluar(indexEnArreglo, 'rechazado', reportes, item),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        icon: const Icon(Icons.handyman_rounded, size: 16),
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
          content: Text("Kit cerrado correctamente (sin retornos).", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
          batch.set(insumoRef, {
            'cantidad_disponible': FieldValue.increment(item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
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

          batch.set(insumoRef, {
            'en_reparacion': FieldValue.increment(item.cantidad),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          nuevosReportes.add({
            'insumoId': item.insumoId,
            'nombreInsumo': item.nombre,
            'cantidad': item.cantidad,
            'notasDelFallo': item.notasController.text.trim(),
            'fotoUrl': urlFinalFoto,
            'estatusEvaluacion': 'taller', 
          });
        }
      }

      List reportesActualizados = List.from(reportesAnteriores)..addAll(nuevosReportes);

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
              Icon(Icons.check_circle_rounded, color: nuevosDanos ? Colors.black : Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(
                nuevosDanos ? "Revisión lista. Herramientas dañadas enviadas al taller." : "Revisión exitosa. Kit reingresado a almacén.", 
                style: GoogleFonts.inter(color: nuevosDanos ? Colors.black : Colors.white, fontWeight: FontWeight.bold)
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
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
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
                    Text("Inspección de Recepción", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Verifica cada herramienta. Si detectas un daño, repórtalo para enviarla al taller.", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 24),

                    if (_itemsAVerificar.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text("No hay herramientas retornables para verificar en este kit. Puedes cerrar el registro.", style: GoogleFonts.inter(color: Colors.white54, height: 1.5), textAlign: TextAlign.center),
                      ))
                    else
                      ..._itemsAVerificar.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: item.tieneFalla ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.build_circle_outlined, color: item.tieneFalla ? Colors.orangeAccent : Colors.cyanAccent, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(item.nombre, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                    Text("Cant: ${item.cantidad}", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              
                              SwitchListTile(
                                title: Text("¿Llegó con falla o daño?", style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                subtitle: Text("Mándala a taller si está averiada", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                value: item.tieneFalla,
                                activeColor: Colors.black,
                                activeTrackColor: Colors.orangeAccent,
                                inactiveThumbColor: Colors.white54,
                                inactiveTrackColor: const Color(0xFF121212),
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
                                      Text("Descripción del daño:", style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: item.notasController,
                                        maxLines: 2,
                                        style: GoogleFonts.inter(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: "Ej. Falta una pieza, el motor suena mal...",
                                          hintStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                          filled: true,
                                          fillColor: const Color(0xFF121212),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      Text("Evidencia Fotográfica:", style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: _isProcessing ? null : () => _tomarFoto(item), 
                                        child: Container(
                                          width: double.infinity,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF121212),
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
                                                    const Icon(Icons.camera_alt_outlined, color: Colors.cyanAccent, size: 24),
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
                  backgroundColor: _itemsAVerificar.isEmpty ? Colors.blueAccent : Colors.amber,
                  foregroundColor: _itemsAVerificar.isEmpty ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isProcessing ? const SizedBox.shrink() : Icon(_itemsAVerificar.isEmpty ? Icons.check_circle : Icons.inventory_2),
                onPressed: _isProcessing ? null : (_itemsAVerificar.isEmpty ? _cerrarKitDirecto : _confirmarIngreso),
                label: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        _itemsAVerificar.isEmpty ? "CERRAR KIT DIRECTO" : "CONFIRMAR RECEPCIÓN", 
                        style: GoogleFonts.outfit(color: _itemsAVerificar.isEmpty ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
              ),
            )
          ],
        ),
      ),
    ); 
  }
}
