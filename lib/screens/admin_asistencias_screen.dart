import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/asistencia_model.dart';
import '../services/asistencia_service.dart';
import '../models/user_model.dart';

// PARA EL PDF
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminAsistenciasScreen extends StatefulWidget {
  final String nombreAdmin;

  const AdminAsistenciasScreen({Key? key, required this.nombreAdmin}) : super(key: key);

  @override
  State<AdminAsistenciasScreen> createState() => _AdminAsistenciasScreenState();
}

class _AdminAsistenciasScreenState extends State<AdminAsistenciasScreen> {
  final AsistenciaService _asistenciaService = AsistenciaService();
  DateTime _fechaSeleccionada = DateTime.now();

  final Color bgDark = const Color(0xFF09090B);
  final Color cardDark = const Color(0xFF18181B);
  final Color primaryPurple = const Color(0xFF8B5CF6);
  final Color textMuted = const Color(0xFFA1A1AA);

  // Para el Cacheee
  final Map<String, UserModel> _usuariosCache = {};

  Future<UserModel?> _obtenerTrabajador(String id) async {
    if (_usuariosCache.containsKey(id)) return _usuariosCache[id];
    
    final snap = await FirebaseFirestore.instance.collection('usuarios').doc(id).get();
    if (snap.exists) {
      final user = UserModel.fromFirestore(snap);
      _usuariosCache[id] = user;
      return user;
    }
    return null;
  }

  Future<void> _editarHoraGeneral(BuildContext context, AsistenciaModel asistencia, String campoFirestore, String titulo, DateTime? horaReferenciaInicial) async {
    DateTime horaReferencia = horaReferenciaInicial ?? DateTime.now();

    TimeOfDay? horaElegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(horaReferencia),
      helpText: "EDITAR $titulo".toUpperCase(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: cardDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (horaElegida != null) {
      DateTime fechaBase = asistencia.fecha;
      DateTime nuevaFechaHora = DateTime(
          fechaBase.year,
          fechaBase.month,
          fechaBase.day,
          horaElegida.hour,
          horaElegida.minute
      );

      String horaFormateada = DateFormat('HH:mm').format(nuevaFechaHora);
      String firmaAdmin = '--> $titulo modificada a $horaFormateada por ${widget.nombreAdmin} el ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';

      await FirebaseFirestore.instance.collection('asistencias').doc(asistencia.id).update({
        campoFirestore: Timestamp.fromDate(nuevaFechaHora),
        'historialModificaciones': FieldValue.arrayUnion([firmaAdmin]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$titulo actualizada correctamente", style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _aprobarSolicitudComida(BuildContext context, AsistenciaModel asistencia) async {
    try {
      DateTime ahora = DateTime.now();
      String horaFormateada = DateFormat('HH:mm').format(ahora);
      String firmaAdmin = 'Solicitud de comida aprobada por ${widget.nombreAdmin} el ${DateFormat('dd/MM HH:mm').format(ahora)}';

      await FirebaseFirestore.instance.collection('asistencias').doc(asistencia.id).update({
        'estatusComida': 'comiendo',
        'salidaComidaReal': Timestamp.fromDate(ahora),
        'historialModificaciones': FieldValue.arrayUnion([firmaAdmin]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Comida aprobada a las $horaFormateada", style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al aprobar: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- MÉTODO MAESTRO PARA ASIGNAR O QUITAR MÚLTIPLES BONOS O MULTAS ---
  Future<void> _mostrarDialogoFinanzas(BuildContext context, AsistenciaModel asistencia, bool esBono) async {
    List<Map<String, dynamic>> itemsActuales = List<Map<String, dynamic>>.from(
      esBono ? (asistencia.listaBonos ?? []) : (asistencia.listaMultas ?? [])
    );
    
    TextEditingController montoController = TextEditingController();
    TextEditingController motivoController = TextEditingController();

    String titulo = esBono ? "Gestión de Bonos" : "Gestión de Multas";
    IconData icono = esBono ? Icons.monetization_on_rounded : Icons.money_off_rounded;
    Color colorFondo = esBono ? Colors.greenAccent : Colors.redAccent;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
            title: Row(
              children: [
                Icon(icono, color: colorFondo),
                const SizedBox(width: 10),
                Text(titulo, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LISTA DE ITEMS YA EXISTENTES ---
                    if (itemsActuales.isNotEmpty) ...[
                      Text("Registros actuales:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      ...itemsActuales.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("\$${(item['monto'] as num).toStringAsFixed(2)}", style: GoogleFonts.inter(color: colorFondo, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(item['motivo'], style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                tooltip: "Eliminar registro",
                                onPressed: () {
                                  setStateDialog(() {
                                    itemsActuales.removeAt(idx);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                    ],

                    // --- FORMULARIO PARA AÑADIR UNO NUEVO ---
                    Text("Añadir nuevo registro:", style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: "Monto (\$)",
                        labelStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.white54),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorFondo)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: motivoController,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Motivo / Justificación",
                        labelStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.notes_rounded, color: Colors.white54),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorFondo)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorFondo.withOpacity(0.2),
                          foregroundColor: colorFondo,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: () {
                          double m = double.tryParse(montoController.text) ?? 0.0;
                          if (m > 0 && motivoController.text.trim().isNotEmpty) {
                            setStateDialog(() {
                              itemsActuales.add({'monto': m, 'motivo': motivoController.text.trim()});
                              montoController.clear();
                              motivoController.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text("Agregar a la lista", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancelar", style: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorFondo.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  String accion = esBono ? "Bonos modificados" : "Multas modificadas";
                  String firmaAdmin = '${esBono ? '💰' : '⚠️'} $accion por ${widget.nombreAdmin} el ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';

                  try {
                    await FirebaseFirestore.instance.collection('asistencias').doc(asistencia.id).update({
                      esBono ? 'listaBonos' : 'listaMultas': itemsActuales,
                      'historialModificaciones': FieldValue.arrayUnion([firmaAdmin]),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Registros actualizados", style: GoogleFonts.inter()),
                          backgroundColor: colorFondo.withOpacity(0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error al guardar finanzas: $e");
                  }
                },
                child: Text("Guardar Todo", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _gestionarJustificacionDia(BuildContext context, AsistenciaModel asistencia, bool aprobar) async {
    String accion = aprobar ? "Aprobar Incapacidad" : "Rechazar Justificación";
    String mensaje = aprobar 
        ? "¿Deseas marcar este día como Incapacidad Pagada? Se le pagará el día completo sin afectar sus métricas."
        : "¿Deseas rechazar esta justificación médica? Se mantendrá el registro como Falta.";

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        title: Row(
          children: [
            Icon(aprobar ? Icons.check_circle_rounded : Icons.cancel_rounded, color: aprobar ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(accion, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(mensaje, style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text("Cancelar", style: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: aprobar ? Colors.green.shade600 : Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true), 
            child: Text(aprobar ? "Sí, Aprobar" : "Sí, Rechazar", style: GoogleFonts.inter(fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirmar == true) {
      String estadoNuevo = aprobar ? 'incapacidad_pagada' : 'falta';
      String estadoJust = aprobar ? 'aprobada' : 'rechazada';
      String firmaAdmin = '${aprobar ? 'Incapacidad pagada aprobada' : 'Justificación rechazada'} por ${widget.nombreAdmin} el ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';
      
      try {
        await FirebaseFirestore.instance.collection('asistencias').doc(asistencia.id).update({
          'estatus': estadoNuevo,
          'estatusJustificacion': estadoJust,
          'historialModificaciones': FieldValue.arrayUnion([firmaAdmin]),
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(aprobar ? "¡Incapacidad aprobada y guardada!" : "Justificación rechazada", style: GoogleFonts.inter()), 
              backgroundColor: aprobar ? Colors.green.shade700 : textMuted,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
        }
      } catch (e) {
        debugPrint("Error al gestionar justificación: $e");
      }
    }
  }

  Future<void> _mostrarModalIncapacidad() async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => Center(child: CircularProgressIndicator(color: primaryPurple))
    );

    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios').get();
      List<UserModel> trabajadores = snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
      String trabajadorSeleccionado = trabajadores.isNotEmpty ? trabajadores.first.id : '';

      if (context.mounted) Navigator.pop(context);

      if (trabajadores.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay trabajadores registrados')));
        }
        return;
      }

      DateTimeRange? rangoFechas;
      TextEditingController motivoController = TextEditingController(text: 'Incapacidad por accidente de trabajo');

      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: cardDark,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateModal) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medical_services_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 12),
                        Text("Registrar Incapacidad", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: trabajadorSeleccionado,
                      dropdownColor: bgDark,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Trabajador",
                        labelStyle: GoogleFonts.inter(color: textMuted),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: trabajadores.map((u) => DropdownMenuItem(value: u.id, child: Text(u.nombre))).toList(),
                      onChanged: (val) => setStateModal(() => trabajadorSeleccionado = val!),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), minimumSize: const Size(double.infinity, 50)),
                      icon: const Icon(Icons.date_range_rounded, color: Colors.white),
                      label: Text(
                        rangoFechas == null 
                            ? "Seleccionar Rango de Fechas" 
                            : "${DateFormat('dd/MM/yyyy').format(rangoFechas!.start)} al ${DateFormat('dd/MM/yyyy').format(rangoFechas!.end)}",
                        style: GoogleFonts.inter(color: Colors.white)
                      ),
                      onPressed: () async {
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: primaryPurple, onPrimary: Colors.white, surface: cardDark)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setStateModal(() => rangoFechas = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: motivoController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Motivo / Justificación",
                        labelStyle: GoogleFonts.inter(color: textMuted),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: rangoFechas == null ? null : () async {
                          final batch = FirebaseFirestore.instance.batch();
                          DateTime current = rangoFechas!.start;
                          
                          String firmaAdmin = 'Incapacidad registrada por ${widget.nombreAdmin} el ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';

                          UserModel trabajadorActual = trabajadores.firstWhere((t) => t.id == trabajadorSeleccionado);
                          bool trabajaSabs = trabajadorActual.trabajaSabados ?? false;

                          while (!current.isAfter(rangoFechas!.end)) {
                            bool esDomingo = current.weekday == DateTime.sunday;
                            bool esSabadoLibre = current.weekday == DateTime.saturday && !trabajaSabs;

                            if (!esDomingo && !esSabadoLibre) {
                              String docId = "${trabajadorSeleccionado}_${DateFormat('yyyyMMdd').format(current)}";
                              DocumentReference docRef = FirebaseFirestore.instance.collection('asistencias').doc(docId);
                              
                              batch.set(docRef, {
                                'id': docId,
                                'trabajadorId': trabajadorSeleccionado,
                                'fecha': Timestamp.fromDate(current),
                                'estatus': 'incapacidad_pagada', 
                                'estatusJustificacion': 'aprobada',
                                'motivoFalta': motivoController.text,
                                'historialModificaciones': FieldValue.arrayUnion([firmaAdmin]),
                              }, SetOptions(merge: true));
                            }
                            
                            current = current.add(const Duration(days: 1));
                          }

                          await batch.commit();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incapacidad registrada correctamente.'), backgroundColor: Colors.green));
                          }
                        },
                        child: Text('GUARDAR INCAPACIDAD', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context); 
      debugPrint("Error: $e");
    }
  }

  Widget _buildBotonHora({
    required BuildContext context,
    required AsistenciaModel asistencia,
    required IconData icono,
    required String titulo,
    required String campoFirestore,
    required DateTime? hora,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editarHoraGeneral(context, asistencia, campoFirestore, titulo, hora),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: textMuted, size: 16),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo.toUpperCase(), style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                    Text(
                      hora != null ? DateFormat('HH:mm').format(hora) : '--:--',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.edit_rounded, color: primaryPurple.withOpacity(0.8), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoHora({
    required IconData icono,
    required String titulo,
    required DateTime? hora,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: Colors.white70, size: 14),
          ),
          const SizedBox(width: 6), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo, 
                  style: GoogleFonts.inter(color: textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hora != null ? DateFormat('HH:mm').format(hora) : '--:--',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime inicioDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day).subtract(const Duration(hours: 2));
    DateTime finDia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Asistencias", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            Text("Panel de Administración", style: GoogleFonts.inter(color: primaryPurple, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: false,
        actions: [ 
          IconButton(
            icon: const Icon(Icons.medical_services_rounded, color: Colors.redAccent),
            tooltip: 'Registrar Incapacidad',
            onPressed: () => _mostrarModalIncapacidad(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF8B5CF6)),
            onPressed: () => _mostrarModalExportarNomina(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: InkWell(
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaSeleccionada,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: primaryPurple,
                          onPrimary: Colors.white,
                          surface: cardDark,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) setState(() => _fechaSeleccionada = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cardDark, const Color(0xFF27272A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: primaryPurple, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, d MMM yyyy', 'es').format(_fechaSeleccionada).toUpperCase(),
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('asistencias')
                  .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
                  .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryPurple));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_rounded, size: 48, color: textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text("No hay registros para este día", style: GoogleFonts.inter(color: textMuted, fontSize: 15)),
                      ],
                    )
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    AsistenciaModel asistencia = AsistenciaModel.fromFirestore(docs[index]);

                    return FutureBuilder<UserModel?>(
                      future: _obtenerTrabajador(asistencia.trabajadorId), 
                      builder: (context, userSnap) {
                        
                        UserModel? trabajador = userSnap.data;
                        String nombreTrabajador = trabajador?.nombre ?? 'Cargando...';
                        String? fotoUrl = trabajador?.fotoUrl;
                        String iniciales = nombreTrabajador.length > 1 ? nombreTrabajador.substring(0, 2).toUpperCase() : '?';

                        bool tieneComida = asistencia.salidaComidaSolicitada != null || 
                                           asistencia.salidaComidaReal != null || 
                                           (asistencia.estatusComida != 'ninguna' && asistencia.estatusComida.isNotEmpty);
                        bool solicitudPendiente = asistencia.estatusComida.toUpperCase() == 'PENDIENTE_APROBACION';

                        // --- CÁLCULO DE MÚLTIPLES BONOS Y MULTAS ---
                        double bonoTotal = (asistencia.listaBonos ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                        double multaTotal = (asistencia.listaMultas ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                        
                        bool tieneBono = bonoTotal > 0;
                        bool tieneMulta = multaTotal > 0;
                        
                        // Modificado para mostrar el monto al lado del motivo en la UI
                        String motivosBono = (asistencia.listaBonos ?? []).map((e) => '+\$${(e['monto'] as num? ?? 0.0).toStringAsFixed(2)}: ${e['motivo']}').where((e) => e.isNotEmpty).join(' • ');
                        String motivosMulta = (asistencia.listaMultas ?? []).map((e) => '-\$${(e['monto'] as num? ?? 0.0).toStringAsFixed(2)}: ${e['motivo']}').where((e) => e.isNotEmpty).join(' • ');

                        return GestureDetector(
                          onTap: () {
                            if (trabajador != null) {
                              _mostrarHistorialTrabajador(context, trabajador);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cargando datos... intenta de nuevo')),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                              ],
                              border: Border.all(color: Colors.white.withOpacity(0.03)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: primaryPurple.withOpacity(0.2),
                                      backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) 
                                          ? NetworkImage(fotoUrl) 
                                          : null,
                                      child: (fotoUrl == null || fotoUrl.isEmpty)
                                          ? Text(iniciales, style: GoogleFonts.montserrat(color: primaryPurple, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nombreTrabajador, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 2),
                                          Text("ID: ${asistencia.trabajadorId.substring(0, 6)}...", style: GoogleFonts.inter(color: textMuted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.15) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.15) : Colors.orange.withOpacity(0.15)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.3) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.3) : Colors.orange.withOpacity(0.3))),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            asistencia.estatus == 'a_tiempo' ? Icons.check_circle_rounded : (asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.schedule_rounded), 
                                            color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                            size: 12
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            asistencia.estatus == 'incapacidad_pagada' ? 'INCAPACIDAD' : asistencia.estatus.toUpperCase(), 
                                            style: GoogleFonts.inter(
                                              color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: Colors.white10, height: 1, thickness: 1),
                                ),
                                
                                // --- ENTRADA, SALIDA O INCAPACIDAD ---
                                if (asistencia.estatus == 'incapacidad_pagada' || asistencia.estatus == 'falta') ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: asistencia.estatus == 'incapacidad_pagada' 
                                          ? Colors.blueAccent.withOpacity(0.05) 
                                          : Colors.redAccent.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: asistencia.estatus == 'incapacidad_pagada' 
                                            ? Colors.blueAccent.withOpacity(0.3) 
                                            : Colors.redAccent.withOpacity(0.3)
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.warning_rounded, 
                                              color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                              size: 20
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                asistencia.estatus == 'incapacidad_pagada' ? "RECUPERACIÓN / INCAPACIDAD PAGADA" : "FALTA / AUSENCIA",
                                                style: GoogleFonts.inter(
                                                  color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                                  fontWeight: FontWeight.bold, 
                                                  fontSize: 13
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (asistencia.motivoFalta != null && asistencia.motivoFalta!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            "Motivo: ${asistencia.motivoFalta}",
                                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                        
                                        // --- BOTÓN PARA VER LA EVIDENCIA ---
                                        if (asistencia.evidenciaJustificacionUrl != null && asistencia.evidenciaJustificacionUrl!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent).withOpacity(0.2),
                                                foregroundColor: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              onPressed: () => _mostrarEvidenciaDialog(context, asistencia.evidenciaJustificacionUrl!),
                                              icon: const Icon(Icons.image_rounded, size: 16),
                                              label: Text("Ver Evidencia Médica", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          ),
                                        ],

                                        // --- BOTONES PARA APROBAR / RECHAZAR LA JUSTIFICACIÓN ---
                                        if (asistencia.estatus == 'falta') ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green.withOpacity(0.15),
                                                    foregroundColor: Colors.greenAccent,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  onPressed: () => _gestionarJustificacionDia(context, asistencia, true),
                                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                                  label: Text("Aprobar", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.white.withOpacity(0.05),
                                                    foregroundColor: Colors.white70,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  onPressed: () => _gestionarJustificacionDia(context, asistencia, false),
                                                  icon: const Icon(Icons.cancel_rounded, size: 16),
                                                  label: Text("Rechazar", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // --- ENTRADA Y SALIDA NORMALES ---
                                  Row(
                                    children: [
                                      _buildBotonHora(context: context, asistencia: asistencia, icono: Icons.login_rounded, titulo: "Entrada", campoFirestore: "horaEntrada", hora: asistencia.horaEntrada),
                                      const SizedBox(width: 12),
                                      _buildBotonHora(context: context, asistencia: asistencia, icono: Icons.logout_rounded, titulo: "Salida", campoFirestore: "horaSalida", hora: asistencia.horaSalida),
                                    ],
                                  ),
                                ],

                                // --- LÓGICA DE BONO MULTIPLES ---
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: tieneBono ? Colors.greenAccent.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tieneBono ? Colors.greenAccent.withOpacity(0.5) : Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.monetization_on_rounded, color: tieneBono ? Colors.greenAccent : textMuted, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(tieneBono ? "Bonos extra asignados" : "Asignar Bonos", style: GoogleFonts.inter(color: tieneBono ? Colors.white : textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  if (tieneBono && motivosBono.isNotEmpty)
                                                    Text(motivosBono, style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (tieneBono)
                                            Text("+\$${bonoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _mostrarDialogoFinanzas(context, asistencia, true),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: tieneBono ? Colors.greenAccent.withOpacity(0.2) : primaryPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                              child: Icon(Icons.edit_rounded, color: tieneBono ? Colors.greenAccent : primaryPurple, size: 16),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),

                                // --- LÓGICA DE MULTA MÚLTIPLES ---
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: tieneMulta ? Colors.redAccent.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tieneMulta ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.money_off_rounded, color: tieneMulta ? Colors.redAccent : textMuted, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(tieneMulta ? "Multas / Penalizaciones" : "Asignar Multa", style: GoogleFonts.inter(color: tieneMulta ? Colors.white : textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  if (tieneMulta && motivosMulta.isNotEmpty)
                                                    Text(motivosMulta, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (tieneMulta)
                                            Text("-\$${multaTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _mostrarDialogoFinanzas(context, asistencia, false),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: tieneMulta ? Colors.redAccent.withOpacity(0.2) : primaryPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                              child: Icon(Icons.edit_rounded, color: tieneMulta ? Colors.redAccent : primaryPurple, size: 16),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),

                                // --- LÓGICA DE VISIBILIDAD DE COMIDA ---
                                if (tieneComida) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(Icons.fastfood_rounded, color: solicitudPendiente ? Colors.orangeAccent : Colors.white70, size: 18),
                                                  const SizedBox(width: 8),
                                                  Expanded( 
                                                    child: Text(
                                                      "Horario de Comida", 
                                                      style: GoogleFonts.inter(color: solicitudPendiente ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (solicitudPendiente) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                                                child: Text("NUEVA SOLICITUD", style: GoogleFonts.inter(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            _buildInfoHora(icono: Icons.access_time_rounded, titulo: "Solicitó", hora: asistencia.salidaComidaSolicitada),
                                            _buildInfoHora(icono: Icons.restaurant_rounded, titulo: "Salió", hora: asistencia.salidaComidaReal),
                                            _buildInfoHora(icono: Icons.assignment_return_rounded, titulo: "Regresó", hora: asistencia.regresoComidaReal),
                                          ],
                                        ),
                                        if (solicitudPendiente) ...[
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 45,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _aprobarSolicitudComida(context, asistencia),
                                              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                              label: Text("Aprobar Salida", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                elevation: 0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                // --- HISTORIAL DE MODIFICACIONES ---
                                if (asistencia.historialModificaciones != null && asistencia.historialModificaciones!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: cardDark,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                                          title: Row(
                                            children: [
                                              Icon(Icons.history_edu_rounded, color: primaryPurple),
                                              const SizedBox(width: 10),
                                              Text("Historial de Cambios", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: asistencia.historialModificaciones!.length,
                                              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                              itemBuilder: (context, index) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                  child: Text(asistencia.historialModificaciones![index], style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4)),
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text("Cerrar", style: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        )
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.manage_history_rounded, color: textMuted, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Ver modificaciones (${asistencia.historialModificaciones!.length})", 
                                          style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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

  // --- EVIDENCIA ---
  void _mostrarEvidenciaDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: cardDark,
                      child: Center(child: CircularProgressIndicator(color: primaryPurple)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(20)),
                    child: Center(child: Text("Imagen no disponible", style: GoogleFonts.inter(color: textMuted))),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HISTORIAL DEL TRABAJADOR CON FILTRO SEMANAL Y TOTAL DE PAGO ---
  void _mostrarHistorialTrabajador(BuildContext context, UserModel trabajador) {
    String trabajadorId = trabajador.id;
    String nombreTrabajador = trabajador.nombre;

    double sueldoBase = trabajador.sueldoBaseSemanal ?? 0.0;
    bool trabajaSabados = trabajador.trabajaSabados ?? false;
    double horasPorDia = 8.0; 

    try {
      if (trabajador.horaEntrada != null && trabajador.horaSalida != null) {
        DateTime entrada = DateFormat('HH:mm').parse(trabajador.horaEntrada!);
        DateTime salida = DateFormat('HH:mm').parse(trabajador.horaSalida!);
        horasPorDia = salida.difference(entrada).inMinutes / 60.0;
        if (horasPorDia < 0) horasPorDia += 24.0; 
      }
    } catch (e) {
      debugPrint("Error parseando horario para costo por hora: $e");
    }

    int diasBase = trabajaSabados ? 6 : 5;
    double horasBaseSemana = diasBase * horasPorDia;
    double precioPorHora = horasBaseSemana > 0 ? sueldoBase / horasBaseSemana : 0.0;

    DateTime semanaSeleccionada = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: bgDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            DateTime inicioSemana = semanaSeleccionada.subtract(Duration(days: semanaSeleccionada.weekday - 1));
            inicioSemana = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
            DateTime finSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

            void _cambiarSemana(int offset) {
              setStateModal(() {
                semanaSeleccionada = semanaSeleccionada.add(Duration(days: 7 * offset));
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85, 
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: primaryPurple.withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(Icons.history_rounded, color: primaryPurple, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text("Historial de $nombreTrabajador", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- SELECTOR DE SEMANA ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _cambiarSemana(-1),
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: cardDark),
                          ),
                          Column(
                            children: [
                              Text(
                                "SEMANA DEL",
                                style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              Text(
                                "${DateFormat('d MMM', 'es').format(inicioSemana)} - ${DateFormat('d MMM yyyy', 'es').format(finSemana)}".toUpperCase(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _cambiarSemana(1),
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: cardDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- LISTA Y CÁLCULOS ---
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('asistencias')
                            .where('trabajadorId', isEqualTo: trabajadorId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryPurple));
                          }

                          var allDocs = snapshot.data?.docs ?? [];
                          
                          var docsSemana = allDocs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            if (data['fecha'] == null) return false;
                            DateTime fecha = (data['fecha'] as Timestamp).toDate();
                            return fecha.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) && 
                                   fecha.isBefore(finSemana.add(const Duration(seconds: 1)));
                          }).toList();

                          docsSemana.sort((a, b) {
                            Timestamp tA = (a.data() as Map)['fecha'] ?? Timestamp.now();
                            Timestamp tB = (b.data() as Map)['fecha'] ?? Timestamp.now();
                            return tB.compareTo(tA); 
                          });

                          Duration totalHorasSemana = Duration.zero;
                          int diasConRetardo = 0; 
                          double totalBonosSemana = 0.0;
                          double totalMultasSemana = 0.0;
                          
                          for (var doc in docsSemana) {
                            AsistenciaModel asis = AsistenciaModel.fromFirestore(doc);
                            
                            // CÁLCULO DE MÚLTIPLES BONOS Y MULTAS
                            if (asis.listaBonos != null) {
                              for(var b in asis.listaBonos!) {
                                totalBonosSemana += (b['monto'] as num? ?? 0.0).toDouble();
                              }
                            }
                            if (asis.listaMultas != null) {
                              for(var m in asis.listaMultas!) {
                                totalMultasSemana += (m['monto'] as num? ?? 0.0).toDouble();
                              }
                            }

                            // --- LÓGICA INCAPACIDAD ---
                            if (asis.estatus == 'incapacidad_pagada') {
                              int horas = horasPorDia.toInt();
                              int minutos = ((horasPorDia - horas) * 60).toInt();
                              totalHorasSemana += Duration(hours: horas, minutes: minutos);
                              continue;
                            }

                            if (asis.fecha != null && asis.horaEntrada != null && asis.horaSalida != null) {
                              
                              DateTime entradaReal = asis.horaEntrada!;

                              if (asis.estatus.toLowerCase() == 'retardo') {
                                diasConRetardo++;
                                entradaReal = DateTime(
                                  entradaReal.year,
                                  entradaReal.month,
                                  entradaReal.day,
                                  entradaReal.hour + 1, 
                                  0, 
                                );
                              }
                              
                              Duration horasDelDia = asis.horaSalida!.difference(entradaReal);
                              if (horasDelDia.isNegative) horasDelDia = Duration.zero; 

                              totalHorasSemana += horasDelDia;
                            }
                          }
                          
                          int horas = totalHorasSemana.inHours;
                          int minutos = totalHorasSemana.inMinutes.remainder(60);
                          
                          // --- CÁLCULO DE NÓMINA ---
                          double horasPagables = totalHorasSemana.inMinutes / 60.0;
                          double pagoTotal = (horasPagables * precioPorHora) + totalBonosSemana - totalMultasSemana;

                          if (pagoTotal < 0) pagoTotal = 0.0;

                          return Column(
                            children: [
                              // --- TARJETA RESUMEN DE HORAS Y PAGO ---
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryPurple.withOpacity(0.2), cardDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: primaryPurple.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("TOTAL TRABAJADO", style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${horas}h ${minutos}m",
                                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (diasConRetardo > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                "-$diasConRetardo HR\nPOR RETARDO",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(color: Colors.white10, height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("PAGO ESTIMADO", style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                "\$${pagoTotal.toStringAsFixed(2)}",
                                                style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text("Base: \$${sueldoBase.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text("Hora: \$${precioPorHora.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                              if (totalBonosSemana > 0) ...[
                                                const SizedBox(height: 2),
                                                Text("Bonos: +\$${totalBonosSemana.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                              if (totalMultasSemana > 0) ...[
                                                const SizedBox(height: 2),
                                                Text("Multas: -\$${totalMultasSemana.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (docsSemana.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Text("Sin registros para esta semana.", style: GoogleFonts.inter(color: textMuted)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    itemCount: docsSemana.length,
                                    itemBuilder: (context, index) {
                                      AsistenciaModel asistencia = AsistenciaModel.fromFirestore(docsSemana[index]);
                                      
                                      bool tieneComida = asistencia.salidaComidaSolicitada != null || 
                                                         asistencia.salidaComidaReal != null || 
                                                         (asistencia.estatusComida != 'ninguna' && asistencia.estatusComida.isNotEmpty);

                                      bool solicitudPendiente = asistencia.estatusComida.toUpperCase() == 'PENDIENTE_APROBACION';
                                      
                                      double bonoTotal = (asistencia.listaBonos ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      double multaTotal = (asistencia.listaMultas ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      bool tieneBono = bonoTotal > 0;
                                      bool tieneMulta = multaTotal > 0;
                                      
                                      // Modificado para mostrar el monto al lado del motivo en la UI
                                      String motivosBono = (asistencia.listaBonos ?? []).map((e) => '+\$${(e['monto'] as num? ?? 0.0).toStringAsFixed(2)}: ${e['motivo']}').where((e) => e.isNotEmpty).join(' • ');
                                      String motivosMulta = (asistencia.listaMultas ?? []).map((e) => '-\$${(e['monto'] as num? ?? 0.0).toStringAsFixed(2)}: ${e['motivo']}').where((e) => e.isNotEmpty).join(' • ');

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cardDark,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    DateFormat('EEEE, d MMM yyyy', 'es').format(asistencia.fecha ?? DateTime.now()).toUpperCase(), 
                                                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.15) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.15) : Colors.orange.withOpacity(0.15)),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.3) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.3) : Colors.orange.withOpacity(0.3))),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        asistencia.estatus == 'a_tiempo' ? Icons.check_circle_rounded : (asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.schedule_rounded), 
                                                        color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                                        size: 12
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        asistencia.estatus == 'incapacidad_pagada' ? 'INCAPACIDAD' : asistencia.estatus.toUpperCase(), 
                                                        style: GoogleFonts.inter(
                                                          color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                                          fontSize: 10, 
                                                          fontWeight: FontWeight.bold
                                                        )
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              child: Divider(color: Colors.white10, height: 1, thickness: 1),
                                            ),
                                            
                                            // --- ENTRADA, SALIDA O INCAPACIDAD ---
                                            if (asistencia.estatus == 'incapacidad_pagada' || asistencia.estatus == 'falta') ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: asistencia.estatus == 'incapacidad_pagada' 
                                                      ? Colors.blueAccent.withOpacity(0.05) 
                                                      : Colors.redAccent.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: asistencia.estatus == 'incapacidad_pagada' 
                                                        ? Colors.blueAccent.withOpacity(0.3) 
                                                        : Colors.redAccent.withOpacity(0.3)
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.warning_rounded, 
                                                          color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                                          size: 20
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            asistencia.estatus == 'incapacidad_pagada' ? "RECUPERACIÓN / INCAPACIDAD PAGADA" : "FALTA / AUSENCIA",
                                                            style: GoogleFonts.inter(
                                                              color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                                              fontWeight: FontWeight.bold, 
                                                              fontSize: 13
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (asistencia.motivoFalta != null && asistencia.motivoFalta!.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Motivo: ${asistencia.motivoFalta}",
                                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                                      ),
                                                    ],
                                                    
                                                    // --- BOTÓN PARA VER LA EVIDENCIA ---
                                                    if (asistencia.evidenciaJustificacionUrl != null && asistencia.evidenciaJustificacionUrl!.isNotEmpty) ...[
                                                      const SizedBox(height: 12),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton.icon(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent).withOpacity(0.2),
                                                            foregroundColor: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent,
                                                            elevation: 0,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                          ),
                                                          onPressed: () => _mostrarEvidenciaDialog(context, asistencia.evidenciaJustificacionUrl!),
                                                          icon: const Icon(Icons.image_rounded, size: 16),
                                                          label: Text("Ver Evidencia Médica", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              // --- ENTRADA Y SALIDA NORMALES ---
                                              Row(
                                                children: [
                                                  _buildBotonHora(context: context, asistencia: asistencia, icono: Icons.login_rounded, titulo: "Entrada", campoFirestore: "horaEntrada", hora: asistencia.horaEntrada),
                                                  const SizedBox(width: 12),
                                                  _buildBotonHora(context: context, asistencia: asistencia, icono: Icons.logout_rounded, titulo: "Salida", campoFirestore: "horaSalida", hora: asistencia.horaSalida),
                                                ],
                                              ),
                                            ],

                                            // --- LÓGICA DE BONOS MÚLTIPLES ---
                                            if (tieneBono) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.greenAccent.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.monetization_on_rounded, color: Colors.greenAccent, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Bonos extra asignados", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                                if (motivosBono.isNotEmpty)
                                                                  Text(motivosBono, style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text("+\$${bonoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- LÓGICA DE MULTAS MÚLTIPLES ---
                                            if (tieneMulta) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.money_off_rounded, color: Colors.redAccent, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Multas / Penalizaciones", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                                if (motivosMulta.isNotEmpty)
                                                                  Text(motivosMulta, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text("-\$${multaTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- LÓGICA DE VISIBILIDAD DE COMIDA ---
                                            if (tieneComida) ...[
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.fastfood_rounded, color: solicitudPendiente ? Colors.orangeAccent : Colors.white70, size: 18),
                                                              const SizedBox(width: 8),
                                                              Expanded( 
                                                                child: Text(
                                                                  "Horario de Comida", 
                                                                  style: GoogleFonts.inter(color: solicitudPendiente ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (solicitudPendiente) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                                                            child: Text("NUEVA SOLICITUD", style: GoogleFonts.inter(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        _buildInfoHora(icono: Icons.access_time_rounded, titulo: "Solicitó", hora: asistencia.salidaComidaSolicitada),
                                                        _buildInfoHora(icono: Icons.restaurant_rounded, titulo: "Salió", hora: asistencia.salidaComidaReal),
                                                        _buildInfoHora(icono: Icons.assignment_return_rounded, titulo: "Regresó", hora: asistencia.regresoComidaReal),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- HISTORIAL DE MODIFICACIONES ---
                                            if (asistencia.historialModificaciones != null && asistencia.historialModificaciones!.isNotEmpty) ...[
                                              const SizedBox(height: 16),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: cardDark,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                                                      title: Row(
                                                        children: [
                                                          Icon(Icons.history_edu_rounded, color: primaryPurple),
                                                          const SizedBox(width: 10),
                                                          Text("Historial de Cambios", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                      content: SizedBox(
                                                        width: double.maxFinite,
                                                        child: ListView.separated(
                                                          shrinkWrap: true,
                                                          itemCount: asistencia.historialModificaciones!.length,
                                                          separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                                          itemBuilder: (context, index) {
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                              child: Text(asistencia.historialModificaciones![index], style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4)),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text("Cerrar", style: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.bold)),
                                                        )
                                                      ],
                                                    )
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.manage_history_rounded, color: textMuted, size: 16),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "Ver modificaciones (${asistencia.historialModificaciones!.length})", 
                                                      style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )
                            ],
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

  void _mostrarModalExportarNomina() async {
    String tipoPeriodo = 'semanal'; 
    DateTime fechaReferencia = DateTime.now();
    String trabajadorSeleccionado = 'todos';
    List<UserModel> todosLosTrabajadores = [];
    bool isLoadingUsuarios = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            if (isLoadingUsuarios) {
              FirebaseFirestore.instance.collection('usuarios').get().then((snap) {
                todosLosTrabajadores = snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
                setStateModal(() => isLoadingUsuarios = false);
              });
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.request_page_rounded, color: primaryPurple, size: 28),
                      const SizedBox(width: 12),
                      Text("Exportar Nómina", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    value: tipoPeriodo,
                    dropdownColor: bgDark,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Tipo de Período",
                      labelStyle: GoogleFonts.inter(color: textMuted),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'semanal', child: Text("Semanal")),
                      DropdownMenuItem(value: 'mensual', child: Text("Mensual")),
                    ],
                    onChanged: (val) => setStateModal(() => tipoPeriodo = val!),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: fechaReferencia,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setStateModal(() => fechaReferencia = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tipoPeriodo == 'semanal' ? "Semana del:" : "Mes del:", style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd MMMM yyyy', 'es').format(fechaReferencia).toUpperCase(), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Icon(Icons.calendar_month_rounded, color: primaryPurple),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  isLoadingUsuarios
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: trabajadorSeleccionado,
                        dropdownColor: bgDark,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Trabajador",
                          labelStyle: GoogleFonts.inter(color: textMuted),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'todos', child: Text("Todos los trabajadores")),
                          ...todosLosTrabajadores.map((u) => DropdownMenuItem(value: u.id, child: Text(u.nombre))).toList(),
                        ],
                        onChanged: (val) => setStateModal(() => trabajadorSeleccionado = val!),
                      ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _generarDescargarReporteNomina(tipoPeriodo, fechaReferencia, trabajadorSeleccionado);
                      },
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text('GENERAR REPORTE', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generarDescargarReporteNomina(String tipoPeriodo, DateTime fechaRef, String trabajadorId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: primaryPurple)));

    try {
      DateTime inicio;
      DateTime fin;

      if (tipoPeriodo == 'semanal') {
        inicio = fechaRef.subtract(Duration(days: fechaRef.weekday - 1));
        inicio = DateTime(inicio.year, inicio.month, inicio.day);
        fin = inicio.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else {
        inicio = DateTime(fechaRef.year, fechaRef.month, 1);
        fin = DateTime(fechaRef.year, fechaRef.month + 1, 0, 23, 59, 59);
      }

      Query query = FirebaseFirestore.instance.collection('asistencias')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(fin));
      
      if (trabajadorId != 'todos') {
        query = query.where('trabajadorId', isEqualTo: trabajadorId);
      }

      final snap = await query.get();
      List<AsistenciaModel> asistencias = snap.docs.map((d) => AsistenciaModel.fromFirestore(d)).toList();

      if (asistencias.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay registros en este período.')));
        return;
      }

      Map<String, List<AsistenciaModel>> agrupadas = {};
      for (var a in asistencias) {
        agrupadas.putIfAbsent(a.trabajadorId, () => []).add(a);
      }

      List<Map<String, dynamic>> datosTabla = [];
      double granTotalNomina = 0.0;
      double granTotalBonos = 0.0;
      double granTotalMultas = 0.0;
      double granTotalIncapacidad = 0.0; 

      for (var workerId in agrupadas.keys) {
        UserModel? trabajador = await _obtenerTrabajador(workerId);
        if (trabajador == null) continue; 

        Map<String, dynamic> calculos = _calcularDatosNominaReutilizable(agrupadas[workerId]!, trabajador);
        datosTabla.add(calculos);

        granTotalNomina += (calculos['pagoTotal'] as double);
        granTotalBonos += (calculos['bonos'] as double);
        granTotalMultas += (calculos['multas'] as double);
        granTotalIncapacidad += (calculos['pagoIncapacidad'] as double);
      }

      final pdf = pw.Document();
      String tituloPeriodo = tipoPeriodo == 'semanal' 
          ? "Semana del ${DateFormat('dd MMM', 'es').format(inicio)} al ${DateFormat('dd MMM yyyy', 'es').format(fin)}"
          : "Mes de ${DateFormat('MMMM yyyy', 'es').format(inicio).toUpperCase()}";

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SAUNASTILO NÓMINA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#090909"))),
                pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.Text(tituloPeriodo, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            pw.Divider(color: PdfColor.fromHex("#8B5CF6")),
            pw.SizedBox(height: 15),

            pw.Row(
              children: [
                _buildDashboardCardPdf('TRABS.', '${datosTabla.length}', PdfColor.fromHex("#34D399")),
                pw.SizedBox(width: 5),
                _buildDashboardCardPdf('INCAPACIDAD', '\$${granTotalIncapacidad.toStringAsFixed(2)}', PdfColor.fromHex("#3B82F6")),
                pw.SizedBox(width: 5),
                _buildDashboardCardPdf('BONOS', '\$${granTotalBonos.toStringAsFixed(2)}', PdfColor.fromHex("#F59E0B")),
                pw.SizedBox(width: 5),
                _buildDashboardCardPdf('MULTAS', '-\$${granTotalMultas.toStringAsFixed(2)}', PdfColor.fromHex("#EF4444")),
                pw.SizedBox(width: 5),
                _buildDashboardCardPdf('NÓMINA', '\$${granTotalNomina.toStringAsFixed(2)}', PdfColor.fromHex("#8B5CF6")),
              ]
            ),
            pw.SizedBox(height: 25),

            pw.Center(
              child: pw.Text('DESGLOSE POR TRABAJADOR', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.0), // Trabajador
                1: pw.FlexColumnWidth(1.0), // Horas
                2: pw.FlexColumnWidth(1.2), // Incapacidad
                3: pw.FlexColumnWidth(0.8), // Retardos
                4: pw.FlexColumnWidth(1.2), // Bonos
                5: pw.FlexColumnWidth(2.0), // Motivo Bonos
                6: pw.FlexColumnWidth(1.2), // Multas
                7: pw.FlexColumnWidth(2.0), // Motivo Multas
                8: pw.FlexColumnWidth(1.5), // Total 
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['TRAB.', 'HRS', 'INCAP.', 'RET.', 'BONOS', 'MOTIVO B.', 'MULTAS', 'MOTIVO M.', 'TOTAL'].map((h) => 
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7), textAlign: pw.TextAlign.center))
                  ).toList(),
                ),
                ...datosTabla.map((r) {
                  return pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['nombre'], style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${r['horasNormales'].toStringAsFixed(1)}h', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$${r['pagoIncapacidad'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex("#3B82F6")), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${r['retardos']}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$${r['bonos'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['motivosBonos'] ?? '', style: const pw.TextStyle(fontSize: 7))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-\$${r['multas'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex("#EF4444")), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['motivosMultas'] ?? '', style: const pw.TextStyle(fontSize: 7))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$${r['pagoTotal'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ]);
                }).toList(),
              ],
            ),
          ]);
        },
      ));

      final output = await getTemporaryDirectory();
      String prefix = 'Nomina_${tipoPeriodo}_${DateTime.now().millisecondsSinceEpoch}';
      String pdfPath = "${output.path}/$prefix.pdf";
      String csvPath = "${output.path}/$prefix.csv";

      await File(pdfPath).writeAsBytes(await pdf.save());

      List<List<dynamic>> csvData = [['TRABAJADOR', 'HORAS_NORMALES', 'HRS_INCAPACIDAD', 'PAGO_INCAPACIDAD', 'RETARDOS', 'BONOS', 'MOTIVOS_BONOS', 'MULTAS', 'MOTIVOS_MULTAS', 'TOTAL_A_PAGAR']];
      for (var r in datosTabla) {
        csvData.add([r['nombre'], r['horasNormales'].toStringAsFixed(2), r['horasIncapacidad'].toStringAsFixed(2), r['pagoIncapacidad'], r['retardos'], r['bonos'], r['motivosBonos'], r['multas'], r['motivosMultas'], r['pagoTotal']]);
      }
      await File(csvPath).writeAsString(const ListToCsvConverter().convert(csvData));

      if (mounted) Navigator.pop(context); 

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: cardDark,
            title: const Text('Nómina generada', style: TextStyle(color: Colors.white)),
            content: const Text('¿Qué formato deseas enviar?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(pdfPath, mimeType: 'application/pdf')], text: 'Reporte de Nómina ($tipoPeriodo)');            
                },
                child: const Text('PDF', style: TextStyle(color: Colors.purpleAccent)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(csvPath, mimeType: 'text/csv')], text: 'Reporte CSV');              
                },
                child: const Text('Excel/CSV', style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error generando nómina: $e");
    }
  }

  Map<String, dynamic> _calcularDatosNominaReutilizable(List<AsistenciaModel> asistenciasDelPeriodo, UserModel trabajador) {
    double sueldoBase = trabajador.sueldoBaseSemanal ?? 0.0;
    bool trabajaSabados = trabajador.trabajaSabados ?? false;
    double horasPorDia = 8.0; 

    try {
      if (trabajador.horaEntrada != null && trabajador.horaSalida != null) {
        DateTime entrada = DateFormat('HH:mm').parse(trabajador.horaEntrada!);
        DateTime salida = DateFormat('HH:mm').parse(trabajador.horaSalida!);
        horasPorDia = salida.difference(entrada).inMinutes / 60.0;
        if (horasPorDia < 0) horasPorDia += 24.0; 
      }
    } catch (e) {
      debugPrint("Error parseando horario: $e");
    }

    int diasBase = trabajaSabados ? 6 : 5;
    double horasBaseSemana = diasBase * horasPorDia;
    double precioPorHora = horasBaseSemana > 0 ? sueldoBase / horasBaseSemana : 0.0;

    Duration totalHoras = Duration.zero;
    Duration totalHorasIncapacidad = Duration.zero; 
    int diasConRetardo = 0; 
    double totalBonos = 0.0;
    double totalMultas = 0.0;
    
    // LISTAS PARA ALMACENAR EL DESGLOSE DE BONOS Y MULTAS
    List<String> listaMotivosBonos = [];
    List<String> listaMotivosMultas = [];
    
    for (var asis in asistenciasDelPeriodo) {
      
      // ACUMULAR MÚLTIPLES BONOS Y SUS MOTIVOS
      if (asis.listaBonos != null) {
        for(var b in asis.listaBonos!) {
          double monto = (b['monto'] as num? ?? 0.0).toDouble();
          if (monto > 0) {
            totalBonos += monto;
            String mot = b['motivo']?.toString().trim() ?? '';
            if (mot.isNotEmpty) listaMotivosBonos.add('+\$${monto.toStringAsFixed(2)}: $mot'); // AÑADE EL MONTO AQUÍ
          }
        }
      }
      
      // ACUMULAR MÚLTIPLES MULTAS Y SUS MOTIVOS
      if (asis.listaMultas != null) {
        for(var m in asis.listaMultas!) {
          double monto = (m['monto'] as num? ?? 0.0).toDouble();
          if (monto > 0) {
            totalMultas += monto;
            String mot = m['motivo']?.toString().trim() ?? '';
            if (mot.isNotEmpty) listaMotivosMultas.add('-\$${monto.toStringAsFixed(2)}: $mot'); // AÑADE EL MONTO AQUÍ
          }
        }
      }

      // --- 1. LÓGICA DE INCAPACIDAD PAGADA ---
      if (asis.estatus == 'incapacidad_pagada') {
        if (asis.fecha != null) {
          bool esDomingo = asis.fecha!.weekday == DateTime.sunday;
          bool esSabadoLibre = asis.fecha!.weekday == DateTime.saturday && !trabajaSabados;

          if (!esDomingo && !esSabadoLibre) {
            int horas = horasPorDia.toInt();
            int minutos = ((horasPorDia - horas) * 60).toInt();
            Duration horasIncap = Duration(hours: horas, minutes: minutos);
            
            totalHoras += horasIncap;
            totalHorasIncapacidad += horasIncap; 
          }
        }
        continue;
      }

      // --- 2. LÓGICA NORMAL DE ENTRADA Y SALIDA ---
      if (asis.fecha != null && asis.horaEntrada != null && asis.horaSalida != null) {
        DateTime entradaReal = asis.horaEntrada!;

        if (asis.estatus.toLowerCase() == 'retardo') {
          diasConRetardo++;
          entradaReal = DateTime(entradaReal.year, entradaReal.month, entradaReal.day, entradaReal.hour + 1, 0);
        }
        
        Duration horasDelDia = asis.horaSalida!.difference(entradaReal);
        if (horasDelDia.isNegative) horasDelDia = Duration.zero; 
        totalHoras += horasDelDia;
      }
    }
    
    double horasPagables = totalHoras.inMinutes / 60.0;
    double horasIncapPagables = totalHorasIncapacidad.inMinutes / 60.0;

    double pagoTotal = (horasPagables * precioPorHora) + totalBonos - totalMultas;
    double pagoIncapacidad = horasIncapPagables * precioPorHora; 

    if (pagoTotal < 0) pagoTotal = 0.0;

    return {
      'nombre': trabajador.nombre,
      'horasNormales': horasPagables - horasIncapPagables, 
      'horasIncapacidad': horasIncapPagables,
      'pagoIncapacidad': pagoIncapacidad,
      'retardos': diasConRetardo,
      'bonos': totalBonos,
      'motivosBonos': listaMotivosBonos.join('\n'), // UNE CON SALTOS DE LÍNEA
      'multas': totalMultas,
      'motivosMultas': listaMotivosMultas.join('\n'), // UNE CON SALTOS DE LÍNEA
      'pagoTotal': pagoTotal,
    };
  }

  pw.Widget _buildDashboardCardPdf(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 5),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}