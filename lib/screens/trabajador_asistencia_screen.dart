import '../widgets/jornada_compacta.dart';
import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';
import '../services/asistencia_service.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';


class TrabajadorAsistenciaScreen extends StatefulWidget {
  final UserModel trabajador;

  const TrabajadorAsistenciaScreen({Key? key, required this.trabajador}) : super(key: key);

  @override
  State<TrabajadorAsistenciaScreen> createState() => _TrabajadorAsistenciaScreenState();
}

class _TrabajadorAsistenciaScreenState extends State<TrabajadorAsistenciaScreen> {
  final AsistenciaService _asistenciaService = AsistenciaService();
  late final Stream<Map<String, dynamic>> _jornada = _asistenciaService.gateway.watchDay(widget.trabajador.id);
  final TextEditingController _motivoFaltaController = TextEditingController();

  XFile? _evidenciaFile;
  Uint8List? _evidenciaBytes;
  bool _isEnviandoJustificacion = false;

  String _formatearHoraEmpresa(DateTime? hora) => hora == null ? '--:--'
      : DateFormat('HH:mm').format(hora.toUtc().subtract(const Duration(hours: 6)));

  Future<void> _seleccionarFoto(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _evidenciaBytes = bytes;
        _evidenciaFile = image;
      });
    }
  }

  void _mostrarOpcionesEvidencia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: StiloColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: StiloColors.text),
              title: Text('Tomar Foto', style: GoogleFonts.inter(color: StiloColors.text)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: StiloColors.text),
              title: Text('Elegir de la Galería', style: GoogleFonts.inter(color: StiloColors.text)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _verImagenCompleta() {
    if (_evidenciaFile == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_evidenciaBytes!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: StiloColors.text, size: 30),
                style: IconButton.styleFrom(backgroundColor: StiloColors.background.withValues(alpha: .54)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _motivoFaltaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final ahora = AttendanceGatewayService.today;

    return Scaffold(
      backgroundColor: StiloColors.background,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        title: Text("Mi Panel de Asistencia", style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: IconThemeData(color: StiloColors.text),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: Color(0xFF00B0FF)),
            onPressed: () => _mostrarMiHistorial(context),
            tooltip: 'Ver mi historial',
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _jornada,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(CompanyLearningService.message(snapshot.error!)), TextButton(onPressed: AttendanceGatewayService.refresh, child: Text('Actualizar jornada'))])));
          AsistenciaModel? asistencia;
          final data = snapshot.data?['data'] as Map<String, dynamic>?;
          if (data != null && data.isNotEmpty) {
            asistencia = AsistenciaModel.fromData(snapshot.data!['asistenciaId'] as String, data);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                JornadaCompacta(usuario: widget.trabajador, service: _asistenciaService),
                const SizedBox(height: 20),

                // --- 4. APARTADO DE JUSTIFICACIÓN DE FALTAS ---
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: StiloColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: StiloColors.text.withOpacity(0.08), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("JUSTIFICAR FALTA / RETARDO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.redAccent, letterSpacing: 1)),
                      SizedBox(height: 14),

                      if (asistencia?.estatusJustificacion != null && asistencia!.estatusJustificacion != 'ninguna') ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: asistencia.estatusJustificacion == 'aprobada'
                                ? Colors.greenAccent.withOpacity(0.1)
                                : asistencia.estatusJustificacion == 'rechazada'
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.orangeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: asistencia.estatusJustificacion == 'aprobada'
                                  ? Colors.greenAccent.withOpacity(0.3)
                                  : asistencia.estatusJustificacion == 'rechazada'
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.orangeAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    asistencia.estatusJustificacion == 'aprobada'
                                        ? Icons.check_circle_rounded
                                        : asistencia.estatusJustificacion == 'rechazada'
                                            ? Icons.cancel_rounded
                                            : Icons.hourglass_top_rounded,
                                    color: asistencia.estatusJustificacion == 'aprobada'
                                        ? Colors.greenAccent
                                        : asistencia.estatusJustificacion == 'rechazada'
                                            ? Colors.redAccent
                                            : Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "ESTATUS: ${asistencia.estatusJustificacion.replaceAll('_', ' ').toUpperCase()}",
                                    style: GoogleFonts.inter(
                                      color: asistencia.estatusJustificacion == 'aprobada'
                                          ? Colors.greenAccent
                                          : asistencia.estatusJustificacion == 'rechazada'
                                              ? Colors.redAccent
                                              : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Text("Tu motivo:", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12)),
                              SizedBox(height: 2),
                              Text(asistencia.motivoFalta ?? 'Sin motivo especificado', style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14)),

                              if (asistencia.observacionesAdmin != null && asistencia.observacionesAdmin.isNotEmpty) ...[
                                SizedBox(height: 10),
                                Text("Nota del administrador:", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12)),
                                SizedBox(height: 2),
                                Text(asistencia.observacionesAdmin, style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                              ],

                              if (asistencia.evidenciaJustificacionUrl != null && asistencia.evidenciaJustificacionUrl!.isNotEmpty) ...[
                                SizedBox(height: 12),
                                Text("Evidencia enviada:", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12)),
                                SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    asistencia.evidenciaJustificacionUrl!,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Text("No se pudo cargar la imagen", style: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        TextField(contextMenuBuilder: privacyTextMenu,
                          controller: _motivoFaltaController,
                          style: GoogleFonts.inter(color: StiloColors.text),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: "Escribe el motivo de tu falta o retardo...",
                            hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38)),
                            filled: true,
                            fillColor: StiloColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        SizedBox(height: 16),

                        if (_evidenciaFile != null) ...[
                          Text("Evidencia adjuntada (toca para ver):", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12)),
                          SizedBox(height: 8),
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _verImagenCompleta,
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 2),
                                    image: DecorationImage(
                                      image: MemoryImage(_evidenciaBytes!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _evidenciaFile = null),
                                  child: Container(
                                  padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: StiloColors.background.withValues(alpha: .87),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close_rounded, color: StiloColors.text, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                        ] else ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StiloColors.text.withValues(alpha: .10),
                              foregroundColor: StiloColors.text,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _mostrarOpcionesEvidencia,
                            icon: Icon(Icons.add_a_photo_rounded, size: 20),
                            label: Text("Adjuntar Evidencia", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(height: 16),
                        ],

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: StiloColors.text,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isEnviandoJustificacion ? null : () async {
                            if (_motivoFaltaController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Por favor escribe el motivo"), backgroundColor: Colors.redAccent));
                              return;
                            }
                            if (_evidenciaFile == null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falta adjuntar una foto de evidencia"), backgroundColor: Colors.redAccent));
                              return;
                            }

                            setState(() => _isEnviandoJustificacion = true);

                            try {
                              await _asistenciaService.enviarJustificacion(
                                trabajadorId: widget.trabajador.id,
                                fechaAsistencia: ahora,
                                motivo: _motivoFaltaController.text,
                                evidenciaUrl: _evidenciaFile!.path,
                              );

                              _motivoFaltaController.clear();
                              setState(() {
                                _evidenciaFile = null; _evidenciaBytes = null;
                                _isEnviandoJustificacion = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Justificación enviada para revisión"), backgroundColor: Colors.green)
                              );
                            } catch (e) {
                              setState(() => _isEnviandoJustificacion = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error al enviar: $e"), backgroundColor: Colors.redAccent)
                              );
                            }
                          },
                          icon: _isEnviandoJustificacion
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: StiloColors.text, strokeWidth: 2))
                            : Icon(Icons.send_rounded, size: 20),
                          label: Text("Enviar Justificación", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

 void _mostrarMiHistorial(BuildContext context) {
    final Color bgDark = StiloColors.surface;
    final Color cardDark = StiloColors.surface;
    final Color primaryPurple = StiloColors.accent;
    final Color textMuted = Color(0xFFA1A1AA);

    // --- CÁLCULO DEL PAGO BASE ---
    double sueldoBase = widget.trabajador.sueldoBaseSemanal ?? 0.0;
    bool trabajaSabados = widget.trabajador.trabajaSabados ?? false;
    double horasPorDia = 8.0;

    try {
      if (widget.trabajador.horaEntrada != null && widget.trabajador.horaSalida != null) {
        DateTime entrada = DateFormat('HH:mm').parse(widget.trabajador.horaEntrada!);
        DateTime salida = DateFormat('HH:mm').parse(widget.trabajador.horaSalida!);
        horasPorDia = salida.difference(entrada).inMinutes / 60.0;
        if (horasPorDia < 0) horasPorDia += 24.0;
      }
    } catch (e) {
      debugPrint("Error parseando horario: $e");
    }

    int diasBase = trabajaSabados ? 6 : 5;
    double horasBaseSemana = diasBase * horasPorDia;
    double precioPorHora = horasBaseSemana > 0 ? sueldoBase / horasBaseSemana : 0.0;

    DateTime semanaSeleccionada = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: bgDark,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {

            DateTime inicioSemana = semanaSeleccionada.subtract(Duration(days: semanaSeleccionada.weekday - 1));
            inicioSemana = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
            DateTime finSemana = inicioSemana.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

            void _cambiarSemana(int offset) {
              setStateModal(() {
                semanaSeleccionada = semanaSeleccionada.add(Duration(days: 7 * offset));
              });
            }

            // Widget para Entrada/Salida (Solo lectura)
            Widget _buildReadonlyHoraBox({required IconData icono, required String titulo, required DateTime? hora}) {
              return Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: StiloColors.text.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icono, color: textMuted, size: 16),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo.toUpperCase(), style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            _formatearHoraEmpresa(hora),
                            style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              );
            }

            // Widget para los detalles de la hora de comida
            Widget _buildInfoHora({required IconData icono, required String titulo, required DateTime? hora}) {
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: StiloColors.text.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icono, color: StiloColors.text.withValues(alpha: .70), size: 14),
                    ),
                    SizedBox(width: 6),
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
                            _formatearHoraEmpresa(hora),
                            style: GoogleFonts.inter(color: StiloColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    SizedBox(height: 12),
                    Container(width: 50, height: 6, decoration: BoxDecoration(color: StiloColors.text.withValues(alpha: .24), borderRadius: BorderRadius.circular(10))),
                    SizedBox(height: 24),

                    // --- CABECERA ---
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(color: primaryPurple.withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(Icons.history_rounded, color: primaryPurple, size: 24),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text("Mi Historial y Nómina", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: StiloColors.text)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // --- SELECTOR DE SEMANA ---
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _cambiarSemana(-1),
                            icon: Icon(Icons.chevron_left_rounded, color: StiloColors.text),
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
                                style: GoogleFonts.inter(color: StiloColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _cambiarSemana(1),
                            icon: Icon(Icons.chevron_right_rounded, color: StiloColors.text),
                            style: IconButton.styleFrom(backgroundColor: cardDark),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // --- LISTA Y CÁLCULOS ---
                    Expanded(
                      child: StreamBuilder<List<AsistenciaModel>>(
                        stream: _asistenciaService.gateway.watchHistory(widget.trabajador.id, inicioSemana, finSemana),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryPurple));
                          if (snapshot.hasError) return Center(child: Text(CompanyLearningService.message(snapshot.error!)));
                          final docsSemana = [...snapshot.data ?? <AsistenciaModel>[]]..sort((a, b) => b.fecha.compareTo(a.fecha));

                          Duration totalHorasSemana = Duration.zero;
                          int diasConRetardo = 0;
                          double totalBonosSemana = 0.0;
                          double totalMultasSemana = 0.0;

                          for (var doc in docsSemana) {
                            AsistenciaModel asis = doc;

                            // Acumular los bonos y multas de la semana
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

                            // --- LÓGICA DE INCAPACIDAD ---
                            if (asis.estatus == 'incapacidad_pagada') {
                              int horas = horasPorDia.toInt();
                              int minutos = ((horasPorDia - horas) * 60).toInt();
                              totalHorasSemana += Duration(hours: horas, minutes: minutos);
                              continue;
                            }

                            if (asis.fecha != null && asis.horaEntrada != null && asis.horaSalida != null) {

                              DateTime entradaReal = asis.horaEntrada!;

                              // 1. Lógica de Retardo: Redondear a la siguiente hora
                              if (asis.estatus.toLowerCase() == 'retardo') {
                                diasConRetardo++;

                                // RETARDOS
                                entradaReal = DateTime(
                                  entradaReal.year,
                                  entradaReal.month,
                                  entradaReal.day,
                                  entradaReal.hour + 1, // Brinca a la siguiente hora
                                  0, // Minutos en 0
                                );
                              }

                              // 2. Tiempo total del día (usando la entrada penalizada si hubo retardo)
                              Duration horasDelDia = asis.horaSalida!.difference(entradaReal);

                              // Evitamos números negativos si por alguna razón salió antes de la hora castigada
                              if (horasDelDia.isNegative) horasDelDia = Duration.zero;

                              totalHorasSemana += horasDelDia;
                            }
                          }

                          int horas = totalHorasSemana.inHours;
                          int minutos = totalHorasSemana.inMinutes.remainder(60);

                          // --- 4. CÁLCULO DE NÓMINA ---

                          // Las horas totales ya traen el castigo aplicado desde el cálculo diario
                          double horasPagables = totalHorasSemana.inMinutes / 60.0;

                          // Calculamos el pago final, sumamos bonos ganados y restamos multas
                          double pagoTotal = (horasPagables * precioPorHora) + totalBonosSemana - totalMultasSemana;

                          // Protección de negocio: evitar saldos negativos
                          if (pagoTotal < 0) pagoTotal = 0.0;

                          return Column(
                            children: [
                              // --- TARJETA RESUMEN DE NÓMINA ---
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
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
                                              SizedBox(height: 4),
                                              Text(
                                                "${horas}h ${minutos}m",
                                                style: GoogleFonts.montserrat(color: StiloColors.text, fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (diasConRetardo > 0)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(color: StiloColors.text.withValues(alpha: .10), height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("PAGO ESTIMADO", style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                              SizedBox(height: 4),
                                              Text(
                                                "\$${pagoTotal.toStringAsFixed(2)}",
                                                style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text("Base: \$${sueldoBase.toStringAsFixed(2)}", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 11)),
                                              SizedBox(height: 2),
                                              Text("Hora: \$${precioPorHora.toStringAsFixed(2)}", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 11)),
                                              if (totalBonosSemana > 0) ...[
                                                SizedBox(height: 2),
                                                Text("Bonos: +\$${totalBonosSemana.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                              if (totalMultasSemana > 0) ...[
                                                SizedBox(height: 2),
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
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    itemCount: docsSemana.length,
                                    itemBuilder: (context, index) {
                                      AsistenciaModel asistencia = docsSemana[index];

                                      bool tieneComida = asistencia.salidaComidaSolicitada != null ||
                                                         asistencia.salidaComidaReal != null ||
                                                         (asistencia.estatusComida != 'ninguna' && asistencia.estatusComida.isNotEmpty);

                                      bool solicitudPendiente = asistencia.estatusComida.toUpperCase() == 'PENDIENTE_APROBACION';

                                      double bonoTotal = (asistencia.listaBonos ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      double multaTotal = (asistencia.listaMultas ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      bool tieneBono = bonoTotal > 0;
                                      bool tieneMulta = multaTotal > 0;
                                      String motivosBono = (asistencia.listaBonos ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');
                                      String motivosMulta = (asistencia.listaMultas ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');

                                      return Container(
                                        margin: EdgeInsets.only(bottom: 16),
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cardDark,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: StiloColors.text.withOpacity(0.03)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // --- FECHA Y ESTATUS GENERAL ---
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    DateFormat('EEEE, d MMM yyyy', 'es').format(asistencia.fecha ?? DateTime.now()).toUpperCase(),
                                                    style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 14)
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                                      SizedBox(width: 4),
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
                                            Padding(
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              child: Divider(color: StiloColors.text.withValues(alpha: .10), height: 1, thickness: 1),
                                            ),

                                            // --- ENTRADA, SALIDA O INCAPACIDAD/FALTA (VISUAL TRABAJADOR) ---
                                            if (asistencia.estatus == 'incapacidad_pagada' || asistencia.estatus == 'falta') ...[
                                              Container(
                                                width: double.infinity,
                                                padding: EdgeInsets.all(16),
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
                                                        SizedBox(width: 8),
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
                                                      SizedBox(height: 8),
                                                      Text(
                                                        "Motivo de ausencia: ${asistencia.motivoFalta}",
                                                        style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 12),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),

                                              // Estatus de justificación si es que el trabajador mandó una
                                              if (asistencia.estatus == 'falta' && asistencia.estatusJustificacion != 'ninguna' && asistencia.estatusJustificacion != 'sin_enviar') ...[
                                                SizedBox(height: 12),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: asistencia.estatusJustificacion == 'aprobada'
                                                        ? Colors.greenAccent.withOpacity(0.1)
                                                        : asistencia.estatusJustificacion == 'rechazada'
                                                            ? Colors.redAccent.withOpacity(0.1)
                                                            : Colors.orangeAccent.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: asistencia.estatusJustificacion == 'aprobada'
                                                          ? Colors.greenAccent.withOpacity(0.5)
                                                          : asistencia.estatusJustificacion == 'rechazada'
                                                              ? Colors.redAccent.withOpacity(0.5)
                                                              : Colors.orangeAccent.withOpacity(0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        asistencia.estatusJustificacion == 'aprobada'
                                                            ? Icons.check_circle_rounded
                                                            : asistencia.estatusJustificacion == 'rechazada'
                                                                ? Icons.cancel_rounded
                                                                : Icons.hourglass_top_rounded,
                                                        color: asistencia.estatusJustificacion == 'aprobada'
                                                            ? Colors.greenAccent
                                                            : asistencia.estatusJustificacion == 'rechazada'
                                                                ? Colors.redAccent
                                                                : Colors.orangeAccent,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "Estado de justificación: ${asistencia.estatusJustificacion.replaceAll('_', ' ').toUpperCase()}",
                                                          style: GoogleFonts.inter(
                                                            color: StiloColors.text,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ] else ...[
                                              // --- ENTRADA Y SALIDA NORMALES (SOLO LECTURA) ---
                                              Row(
                                                children: [
                                                  _buildReadonlyHoraBox(icono: Icons.login_rounded, titulo: "Entrada", hora: asistencia.horaEntrada),
                                                  SizedBox(width: 12),
                                                  _buildReadonlyHoraBox(icono: Icons.logout_rounded, titulo: "Salida", hora: asistencia.horaSalida),
                                                ],
                                              ),
                                            ],

                                            // --- BONOS ---
                                            if (tieneBono) ...[
                                              SizedBox(height: 12),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                                          Icon(Icons.monetization_on_rounded, color: Colors.greenAccent, size: 20),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Bonos extra asignados", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
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

                                            // --- MULTAS ---
                                            if (tieneMulta) ...[
                                              SizedBox(height: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                                          Icon(Icons.money_off_rounded, color: Colors.redAccent, size: 20),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Multas / Penalizaciones", style: GoogleFonts.inter(color: StiloColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
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

                                            // --- HORARIO DE COMIDA ---
                                            if (tieneComida) ...[
                                              SizedBox(height: 16),
                                              Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.05) : StiloColors.text.withOpacity(0.02),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.5) : StiloColors.text.withOpacity(0.05)),
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
                                                              Icon(Icons.fastfood_rounded, color: solicitudPendiente ? Colors.orangeAccent : StiloColors.text.withValues(alpha: .70), size: 18),
                                                              SizedBox(width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  "Horario de Comida",
                                                                  style: GoogleFonts.inter(color: solicitudPendiente ? Colors.orangeAccent : StiloColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (solicitudPendiente) ...[
                                                          SizedBox(width: 8),
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                                                            child: Text("NUEVA SOLICITUD", style: GoogleFonts.inter(color: StiloColors.background, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    SizedBox(height: 16),
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
                                              SizedBox(height: 16),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: cardDark,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: StiloColors.text.withOpacity(0.05))),
                                                      title: Row(
                                                        children: [
                                                          Icon(Icons.history_edu_rounded, color: primaryPurple),
                                                          SizedBox(width: 10),
                                                          Expanded(
                                                            child: Text(
                                                              "Notas del Administrador",
                                                              style: GoogleFonts.montserrat(color: StiloColors.text, fontSize: 16, fontWeight: FontWeight.bold),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      content: SizedBox(
                                                        width: double.maxFinite,
                                                        child: ListView.separated(
                                                          shrinkWrap: true,
                                                          itemCount: asistencia.historialModificaciones!.length,
                                                          separatorBuilder: (context, index) => Divider(color: StiloColors.text.withValues(alpha: .10)),
                                                          itemBuilder: (context, index) {
                                                            return Padding(
                                                              padding: EdgeInsets.symmetric(vertical: 8.0),
                                                              child: Text(asistencia.historialModificaciones![index], style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 13, height: 1.4)),
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
                                                    SizedBox(width: 6),
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
}
