import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/proyecto_model.dart';
import '../models/insumo_model.dart';
import '../models/solicitud_herramienta_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';

class ControlHerramientasScreen extends StatefulWidget {
  final Proyecto? proyecto;
  
  final String? usuarioId; 
  final String? usuarioNombre;

  const ControlHerramientasScreen({
    Key? key,
    this.proyecto,
    this.usuarioId,
    this.usuarioNombre,
  }) : super(key: key);

  @override
  State<ControlHerramientasScreen> createState() => _ControlHerramientasScreenState();
}

class _ControlHerramientasScreenState extends State<ControlHerramientasScreen> {
  late String currentUid; 
  String? nombreUsuario; 
  bool cargando = false; 

  String _filtroSeleccionado = 'Todas';
  final List<String> _opcionesFiltro = ['Todas', 'Pendientes', 'Aprobadas', 'Rechazadas'];

  static const Color colorFondo = Color(0xFF161210);
  static const Color colorTarjeta = Color(0xFF221A16);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Color(0xFFB5ABA5);
  static const Color colorAcento = Color(0xFFFFDE21);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorRojo = Color(0xFFFF5252);
  static const Color colorVerde = Color(0xFF4CAF50); 
  static const Color colorGradiente1 = Color(0xFF8B4513); 
  static const Color colorGradiente2 = Color(0xFF4A1504); 

  @override
  void initState() {
    super.initState();
    if (widget.usuarioId != null && widget.usuarioNombre != null) {
      currentUid = widget.usuarioId!;
      nombreUsuario = widget.usuarioNombre;
    } else {
      currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      cargando = true; 
      _cargarDatosUsuario();
    }
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUid).get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        if (mounted) {
          setState(() {
            nombreUsuario = user.nombre;
            cargando = false;
          });
        }
      } else {
         if (mounted) setState(() => cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "CONTROL DE HERRAMIENTAS",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: colorTextoPrimario),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: colorTextoPrimario),
      ),
      body: cargando 
        ? const Center(child: CircularProgressIndicator(color: colorAcento))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Text(
                  "Historial de Solicitudes",
                  style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildFiltros(),
                const SizedBox(height: 16),
                _buildHerramientasSection(),
              ],
            ),
          ),
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _opcionesFiltro.length,
        itemBuilder: (context, index) {
          final filtro = _opcionesFiltro[index];
          final isSelected = _filtroSeleccionado == filtro;
          
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ChoiceChip(
              label: Text(
                filtro, 
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.black : colorTextoSecundario,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                )
              ),
              selected: isSelected,
              selectedColor: colorAcento,
              backgroundColor: colorTarjeta,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? colorAcento : Colors.white.withOpacity(0.1),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _filtroSeleccionado = filtro);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [colorGradiente1, colorGradiente2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5), 
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "PROYECTO ACTUAL", 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.proyecto?.titulo ?? "HERRAMIENTAS GENERALES",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => _mostrarModalSolicitudHerramienta(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorAcento, 
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: const Icon(Icons.add_rounded, color: Colors.black, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerramientasSection() {
    Query query = FirebaseFirestore.instance.collection('solicitudes_herramientas')
        .where('trabajadorId', isEqualTo: currentUid)
        .orderBy('fechaSolicitud', descending: true);
    
    if (widget.proyecto != null) {
      query = FirebaseFirestore.instance.collection('solicitudes_herramientas')
        .where('trabajadorId', isEqualTo: currentUid)
        .where('proyectoId', isEqualTo: widget.proyecto!.id)
        .orderBy('fechaSolicitud', descending: true); 
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: colorAcento));
        
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState();
        
        List<SolicitudHerramientaModel> solicitudes = snapshot.data!.docs
            .map((doc) => SolicitudHerramientaModel.fromFirestore(doc))
            .toList();

        if (_filtroSeleccionado != 'Todas') {
          solicitudes = solicitudes.where((sol) {
            if (_filtroSeleccionado == 'Pendientes') return sol.estatus.toLowerCase() == 'pendiente';
            if (_filtroSeleccionado == 'Aprobadas') return sol.estatus.toLowerCase() == 'aprobada';
            if (_filtroSeleccionado == 'Rechazadas') return sol.estatus.toLowerCase() == 'rechazada';
            return true;
          }).toList();
        }

        if (solicitudes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: Center(
              child: Text(
                "No hay solicitudes ${_filtroSeleccionado.toLowerCase()}",
                style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14),
              ),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: solicitudes.length,
          itemBuilder: (context, index) {
            return _buildSolicitudCard(solicitudes[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: colorTarjeta,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorFondo,
              shape: BoxShape.circle,
              border: Border.all(color: colorTextoSecundario.withOpacity(0.2)),
            ),
            child: const Icon(Icons.handyman_rounded, color: colorTextoSecundario, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            "Sin herramientas", 
            style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            "Aún no has solicitado herramientas\no insumos para este proyecto.", 
            style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _mostrarModalSolicitudHerramienta(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Solicitar ahora"),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorAcento,
              side: const BorderSide(color: colorAcento),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(SolicitudHerramientaModel sol) {
    bool estaAtrasada = false;
    if (sol.esRetornable && sol.estatus == 'aprobada' && !sol.devueltoConfirmadoAdmin && sol.fechaLimiteDevolucion != null) {
      estaAtrasada = DateTime.now().isAfter(sol.fechaLimiteDevolucion!);
    }

    Color statusColor;
    IconData statusIcon;
    
    if (estaAtrasada) {
      statusColor = colorRojo;
      statusIcon = Icons.warning_rounded;
    } else if (sol.devueltoConfirmadoAdmin) {
      statusColor = colorVerde;
      statusIcon = Icons.check_circle_rounded;
    } else if (sol.estatus == 'pendiente') {
      statusColor = colorNaranja;
      statusIcon = Icons.schedule_rounded;
    } else if (sol.estatus == 'rechazada') {
      statusColor = colorRojo;
      statusIcon = Icons.cancel_rounded;
    } else if (sol.marcadoDevueltoTrabajador) {
      statusColor = colorAcento;
      statusIcon = Icons.sync_rounded;
    } else {
      statusColor = colorAcento;
      statusIcon = Icons.build_rounded;
    }

    final esPendiente = sol.estatus.trim().toLowerCase() == 'pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorTarjeta, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: esPendiente ? () => _mostrarModalEditarSolicitud(context, sol) : null,
          onLongPress: esPendiente ? () => _confirmarEliminacion(context, sol.id) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sol.nombreInsumo, 
                        style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.business_center_outlined, size: 14, color: colorAcento),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sol.proyectoNombre ?? "General",
                              style: GoogleFonts.inter(color: colorAcento, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0), 
                            child: Icon(Icons.calendar_today_outlined, size: 13, color: colorTextoSecundario),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${sol.fechaSolicitud.day.toString().padLeft(2, '0')}/${sol.fechaSolicitud.month.toString().padLeft(2, '0')}/${sol.fechaSolicitud.year} - ${sol.fechaSolicitud.hour.toString().padLeft(2, '0')}:${sol.fechaSolicitud.minute.toString().padLeft(2, '0')}",
                              style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12),
                              overflow: TextOverflow.ellipsis, 
                              maxLines: 2, 
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6, 
                        runSpacing: 4, 
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: colorTextoSecundario),
                          Text("Cant: ${sol.cantidad}", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
                          if (sol.esRetornable) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.assignment_return_outlined, size: 14, color: colorTextoSecundario),
                            Text("Retornable", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), 
                _buildEstatusSolicitudAccion(sol, statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstatusSolicitudAccion(SolicitudHerramientaModel sol, Color statusColor) {
    if (sol.estatus == 'aprobada' && sol.esRetornable && !sol.devueltoConfirmadoAdmin && !sol.marcadoDevueltoTrabajador) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorAcento, 
          foregroundColor: Colors.black, 
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        onPressed: () => _mostrarModalReporteDevolucion(context, sol),
        child: Text("Devolver", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    String text = sol.estatus.toUpperCase();
    if (sol.devueltoConfirmadoAdmin) text = "DEVUELTA";
    else if (sol.marcadoDevueltoTrabajador) text = "ESPERANDO";
    else if (sol.estatus != 'pendiente' && sol.estatus != 'rechazada' && !sol.esRetornable) text = "ENTREGADO";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: statusColor.withOpacity(0.3))
      ),
      child: Text(text, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  void _mostrarModalSolicitudHerramienta(BuildContext context) {
    InsumoModel? insumoSeleccionado;
    int cantidad = 1;
    bool esRetornable = true;
    
    String searchQuery = "";
    TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool sinStock = insumoSeleccionado != null && insumoSeleccionado!.cantidadDisponible == 0;
            
          return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: colorFondo, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(32))
              ),
              padding: EdgeInsets.only(
                top: 12, 
                left: 24, 
                right: 24, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 24 
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Solicitar Insumo", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  
                  // BUSCADOR
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    style: GoogleFonts.inter(color: colorTextoPrimario),
                    decoration: InputDecoration(
                      hintText: "Buscar herramienta...",
                      hintStyle: GoogleFonts.inter(color: colorTextoSecundario),
                      prefixIcon: const Icon(Icons.search_rounded, color: colorTextoSecundario),
                      filled: true,
                      fillColor: colorTarjeta,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: colorTextoSecundario),
                            onPressed: () {
                              searchController.clear();
                              setModalState(() => searchQuery = "");
                            }
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('insumos_inventario').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: colorAcento));
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 48, color: colorTextoSecundario),
                                const SizedBox(height: 16),
                                Text("No hay herramientas", style: GoogleFonts.inter(color: colorTextoSecundario)),
                              ],
                            ),
                          );
                        }

                        var docs = snapshot.data!.docs;
                        if (searchQuery.isNotEmpty) {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                            return nombre.contains(searchQuery);
                          }).toList();
                        }

                        if (docs.isEmpty) {
                          return Center(
                            child: Text("No se encontraron resultados", style: GoogleFonts.inter(color: colorTextoSecundario)),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final insumo = InsumoModel.fromFirestore(doc);
                            final isSelected = insumoSeleccionado?.id == insumo.id;
                            final noStock = insumo.cantidadDisponible == 0;
                            
                            final imageUrl = data['imagen_url'] as String?;

                            return InkWell(
                              onTap: () => setModalState(() => insumoSeleccionado = insumo),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? colorAcento.withOpacity(0.1) : colorTarjeta,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? colorAcento : Colors.white.withOpacity(0.05),
                                    width: isSelected ? 1.5 : 1
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isSelected ? colorAcento.withOpacity(0.2) : colorFondo,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Icon(
                                                  Icons.image_not_supported_outlined,
                                                  color: colorTextoSecundario.withOpacity(0.5),
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.build_circle_outlined, 
                                              color: isSelected ? colorAcento : colorTextoSecundario,
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            insumo.nombre, 
                                            style: GoogleFonts.inter(
                                              color: colorTextoPrimario, 
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15
                                            )
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            noStock ? "Sin stock" : "Disponibles: ${insumo.cantidadDisponible}", 
                                            style: GoogleFonts.inter(
                                              color: noStock ? colorRojo : colorTextoSecundario, 
                                              fontSize: 12,
                                              fontWeight: noStock ? FontWeight.w600 : FontWeight.normal
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: colorAcento)
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                const SizedBox(height: 16),
                  
                  // --- INICIO DE SECCIÓN AÑADIDA: CANTIDAD Y RETORNABLE ---
                  if (insumoSeleccionado != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorTarjeta, 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Cantidad:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.w500)),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorFondo, 
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1))
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_rounded, color: colorTextoSecundario),
                                      onPressed: () { if (cantidad > 1) setModalState(() => cantidad--); },
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        "$cantidad", 
                                        textAlign: TextAlign.center, 
                                        style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 20, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_rounded, color: colorAcento),
                                      onPressed: () => setModalState(() => cantidad++),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          SwitchListTile(
                            title: Text("¿Regresa al almacén después?", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.w500)),
                            subtitle: Text("Desactiva si el material se queda en la obra", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12)),
                            value: esRetornable,
                            activeColor: Colors.black,
                            activeTrackColor: colorAcento,
                            inactiveThumbColor: colorTextoSecundario,
                            inactiveTrackColor: colorFondo,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (bool value) => setModalState(() => esRetornable = value),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorAcento, 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: insumoSeleccionado == null ? 0 : 8,
                        shadowColor: colorAcento.withOpacity(0.5),
                        disabledBackgroundColor: colorTarjeta,
                        disabledForegroundColor: colorTextoSecundario,
                      ),
                      onPressed: (insumoSeleccionado == null || nombreUsuario == null) ? null : () async {
                        Map<String, dynamic> datosSolicitud = SolicitudHerramientaModel(
                          id: '',
                          proyectoId: widget.proyecto?.id ?? 'general',
                          // Dejamos las llaves originales para no romper el modelo de la BD
                          trabajadorId: currentUid, 
                          trabajadorNombre: nombreUsuario!, 
                          insumoId: insumoSeleccionado!.id,
                          nombreInsumo: insumoSeleccionado!.nombre,
                          cantidad: cantidad,
                          esRetornable: esRetornable,
                          fechaSolicitud: DateTime.now(),
                        ).toFirestore();

                        datosSolicitud['proyectoNombre'] = widget.proyecto?.titulo ?? 'General';

                        if (sinStock) {
                          datosSolicitud['notaAdmin'] = "Solicitud urgente: Sin stock.";
                          datosSolicitud['requiereCompra'] = true;
                        }

                        final db = FirebaseFirestore.instance;
                        final solicitudRef = db.collection('solicitudes_herramientas').doc();
                        final avisoRef = db.collection('notificaciones').doc();
                        final batch = db.batch();
                        batch.set(solicitudRef, datosSolicitud);
                        batch.set(
                          avisoRef,
                          NotificacionesService.datosAviso(
                            titulo: 'Nueva solicitud de almacén',
                            mensaje: '$nombreUsuario solicitó $cantidad × ${insumoSeleccionado!.nombre}',
                            tipo: 'almacen',
                            rolesDestinatarios: const ['admin', 'almacenista'],
                          ),
                        );
                        await batch.commit();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text("Confirmar Solicitud", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _mostrarModalEditarSolicitud(BuildContext context, SolicitudHerramientaModel sol) {
    int cantidad = sol.cantidad;
    bool esRetornable = sol.esRetornable;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),  
                padding: EdgeInsets.only(top: 12, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Text("Editar Solicitud", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(sol.nombreInsumo, style: GoogleFonts.inter(color: colorNaranja, fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 32),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorTarjeta, 
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Cantidad:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.w500)),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorFondo, 
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1))
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_rounded, color: colorTextoSecundario),
                                      onPressed: () { if (cantidad > 1) setModalState(() => cantidad--); },
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        "$cantidad", 
                                        textAlign: TextAlign.center, 
                                        style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 20, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_rounded, color: colorAcento),
                                      onPressed: () => setModalState(() => cantidad++),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),


                         SwitchListTile(
                            title: Text("¿Regresa al almacén después?", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.w500)),
                            subtitle: Text("Desactiva si el material se queda en la obra", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 12)),
                            value: esRetornable,


                            activeColor: Colors.black,
                            activeTrackColor: colorAcento,
                            inactiveThumbColor: colorTextoSecundario,
                            inactiveTrackColor: colorFondo,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (bool value) => setModalState(() => esRetornable = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorAcento,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: colorAcento.withOpacity(0.5),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(sol.id).update({
                            'cantidad': cantidad,
                            'esRetornable': esRetornable,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: colorVerde,
                                margin: const EdgeInsets.all(16),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text("Solicitud actualizada.", style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                        child: Text("Guardar Cambios", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmarEliminacion(BuildContext context, String solicitudId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorTarjeta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: colorRojo.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, color: colorRojo),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text("Eliminar", style: GoogleFonts.outfit(color: colorTextoPrimario, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text("¿Estás seguro de que deseas cancelar esta solicitud?", style: GoogleFonts.inter(color: colorTextoSecundario, height: 1.5)),
        actionsPadding: const EdgeInsets.only(right: 20, bottom: 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Volver", style: GoogleFonts.inter(color: colorTextoSecundario, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorRojo,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(solicitudId).delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: colorRojo,
                    margin: const EdgeInsets.all(16),
                    content: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text("Solicitud eliminada.", style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                );
              }
            },
            child: Text("Eliminar", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalReporteDevolucion(BuildContext context, SolicitudHerramientaModel sol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReporteDevolucionModal(solicitud: sol),
    );
  }
}

class ReporteDevolucionModal extends StatefulWidget {
  final SolicitudHerramientaModel solicitud;

  const ReporteDevolucionModal({Key? key, required this.solicitud}) : super(key: key);

  @override
  State<ReporteDevolucionModal> createState() => _ReporteDevolucionModalState();
}

class _ReporteDevolucionModalState extends State<ReporteDevolucionModal> {
  final TextEditingController _observacionesController = TextEditingController();
  bool _tieneFalla = false;
  String? _imagenLocalRuta;
  bool _subiendoDatos = false;

  static const Color colorFondo = Color(0xFF161210);
  static const Color colorTarjeta = Color(0xFF221A16);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Color(0xFFB5ABA5);
  static const Color colorAcento = Color(0xFFFFDE21);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorVerde = Color(0xFF4CAF50);

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    
    if (image != null) {
      setState(() {
        _imagenLocalRuta = image.path;
      });
    }
  }

  Future<void> _procesarDevolucion() async {
    setState(() => _subiendoDatos = true);
    
    String urlFinalFoto = "";
    
    try {
      if (_imagenLocalRuta != null) {
        File file = File(_imagenLocalRuta!);
        String fileName = 'devoluciones/${widget.solicitud.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        urlFinalFoto = await snapshot.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('solicitudes_herramientas').doc(widget.solicitud.id).update({
        'marcadoDevueltoTrabajador': true,
        'tieneReporteFalla': _tieneFalla,
        'observacionesDevolucion': _observacionesController.text.trim(),
        'fotoDevolucionUrl': urlFinalFoto,
        'fechaMarcadoDevuelto': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: colorVerde,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text("Reporte enviado correctamente.", style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _subiendoDatos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("Error al enviar el reporte: $e", style: GoogleFonts.inter()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: const BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(top: 12, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Reporte de Devolución", style: GoogleFonts.outfit(color: colorTextoPrimario, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      "Herramienta: ${widget.solicitud.nombreInsumo}", 
                      style: GoogleFonts.inter(color: colorNaranja, fontSize: 15, fontWeight: FontWeight.w600)
                    ),
                    const SizedBox(height: 32),

                    Container(
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _tieneFalla ? colorNaranja.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                      ),
                      child: SwitchListTile(
                        title: Text("¿Presenta falla o daño?", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.w500)),
                        subtitle: Text("Activa si requiere mantenimiento", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13)),
                        value: _tieneFalla,
                        activeColor: Colors.black,
                        activeTrackColor: colorNaranja,
                        inactiveThumbColor: colorTextoSecundario,
                        inactiveTrackColor: colorFondo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onChanged: (bool value) => setState(() => _tieneFalla = value),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text("Observaciones:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _observacionesController,
                      maxLines: 4,
                      style: GoogleFonts.inter(color: colorTextoPrimario),
                      decoration: InputDecoration(
                        hintText: _tieneFalla 
                            ? "Describe detalladamente la falla mecánica..."
                            : "Escribe comentarios adicionales (opcional)...",
                        hintStyle: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14),
                        filled: true,
                        fillColor: colorTarjeta,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16), 
                          borderSide: BorderSide(color: colorNaranja.withOpacity(0.5))
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text("Evidencia Fotográfica:", style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _subiendoDatos ? null : _tomarFoto,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _imagenLocalRuta != null ? colorVerde.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: _imagenLocalRuta == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: colorFondo, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt_outlined, color: colorAcento, size: 28),
                                  ),
                                  const SizedBox(height: 12),
                                  Text("Tocar para tomar foto", style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 14)),
                                ],
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        File(_imagenLocalRuta!), 
                                        width: double.infinity, 
                                        fit: BoxFit.cover,
                                        opacity: const AlwaysStoppedAnimation(0.6),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: colorVerde, size: 20),
                                          const SizedBox(width: 8),
                                          Text("Foto capturada", style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                      onPressed: () => setState(() => _imagenLocalRuta = null),
                                    ),
                                  )
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorAcento,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: colorAcento.withOpacity(0.5),
                ),
                onPressed: _subiendoDatos ? null : _procesarDevolucion,
                child: _subiendoDatos 
                    ? const SizedBox(
                        height: 24, width: 24, 
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)
                      )
                    : Text("Confirmar Entrega", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
