import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/actividad_model.dart';
import '../models/evidencia_actividad_model.dart';
import '../services/actividades_service.dart';

class ModalDetalleActividad extends StatefulWidget {
  final ActividadModel actividad;

  const ModalDetalleActividad({super.key, required this.actividad});

  @override
  State<ModalDetalleActividad> createState() =>
      _ModalDetalleActividadState();
}

class _ModalDetalleActividadState extends State<ModalDetalleActividad> {
  final ActividadesService _actividadesService = ActividadesService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _comentarioController = TextEditingController();
  final List<ArchivoEvidenciaPendiente> _archivosPendientes = [];

  late String _estatusActual;
  bool _estaProcesando = false;
  bool _estaSeleccionando = false;

  bool get _estaBloqueada =>
      _estatusActual == 'completado' ||
      _estaProcesando ||
      _estaSeleccionando;

  String? get _trabajadorId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _estatusActual = widget.actividad.estatus;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.redAccent : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mensajeError(Object error) {
    final texto = error.toString();
    return texto.startsWith('Exception: ')
        ? texto.substring('Exception: '.length)
        : texto;
  }

  Future<void> _iniciarActividad() async {
    final trabajadorId = _trabajadorId;
    if (trabajadorId == null) {
      _mostrarMensaje(
        'Tu sesión terminó. Inicia sesión nuevamente para continuar.',
        esError: true,
      );
      return;
    }

    setState(() => _estaProcesando = true);
    try {
      await _actividadesService.iniciarActividad(
        actividadId: widget.actividad.id,
        trabajadorId: trabajadorId,
      );
      if (!mounted) return;
      setState(() => _estatusActual = 'en_progreso');
      _mostrarMensaje('Tarea iniciada. Ya puedes registrar tus avances.');
    } catch (error) {
      _mostrarMensaje(_mensajeError(error), esError: true);
    } finally {
      if (mounted) setState(() => _estaProcesando = false);
    }
  }

  Future<void> _seleccionarCamara() async {
    if (_estaBloqueada) return;
    try {
      final archivo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (archivo != null) await _agregarImagenes([archivo]);
    } catch (error) {
      _mostrarMensaje('No fue posible abrir la cámara: $error', esError: true);
    }
  }

  Future<void> _seleccionarFotos() async {
    if (_estaBloqueada) return;
    try {
      final archivos = await _imagePicker.pickMultiImage(imageQuality: 82);
      if (archivos.isNotEmpty) await _agregarImagenes(archivos);
    } catch (error) {
      _mostrarMensaje(
        'No fue posible seleccionar las fotos: $error',
        esError: true,
      );
    }
  }

  Future<void> _agregarImagenes(List<XFile> archivos) async {
    setState(() => _estaSeleccionando = true);
    try {
      final nuevos = <ArchivoEvidenciaPendiente>[];
      for (final archivo in archivos) {
        nuevos.add(
          ArchivoEvidenciaPendiente(
            nombre: archivo.name,
            tipoMime: _tipoMime(archivo.name, archivo.mimeType),
            tamanioBytes: await archivo.length(),
            lectorBytes: archivo.readAsBytes,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _archivosPendientes.addAll(nuevos));
    } catch (error) {
      _mostrarMensaje('No fue posible preparar las fotos: $error', esError: true);
    } finally {
      if (mounted) setState(() => _estaSeleccionando = false);
    }
  }

  Future<void> _seleccionarArchivos() async {
    if (_estaBloqueada) return;
    setState(() => _estaSeleccionando = true);
    try {
      final archivosSeleccionados = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (archivosSeleccionados.isEmpty) return;

      final nuevos = <ArchivoEvidenciaPendiente>[];
      for (final archivo in archivosSeleccionados) {
        nuevos.add(
          ArchivoEvidenciaPendiente(
            nombre: archivo.name,
            tipoMime: _tipoMime(archivo.name, null),
            tamanioBytes: await archivo.length(),
            lectorBytes: archivo.readAsBytes,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _archivosPendientes.addAll(nuevos));
    } catch (error) {
      _mostrarMensaje(
        'No fue posible seleccionar los archivos: $error',
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _estaSeleccionando = false);
    }
  }

  String _tipoMime(String nombre, String? tipoDetectado) {
    if (tipoDetectado != null && tipoDetectado.trim().isNotEmpty) {
      return tipoDetectado;
    }
    final extension = nombre.split('.').last.toLowerCase();
    const tipos = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
    };
    return tipos[extension] ?? 'application/octet-stream';
  }

  Future<void> _registrarAvance() async {
    await _guardarReporte(esCierre: false, evidenciasExistentes: const []);
  }

  Future<void> _guardarReporte({
    required bool esCierre,
    required List<EvidenciaActividad> evidenciasExistentes,
  }) async {
    final comentario = _comentarioController.text.trim();
    if (comentario.isEmpty) {
      _mostrarMensaje(
        esCierre
            ? 'Escribe el reporte final antes de terminar la tarea.'
            : 'Escribe qué avance realizaste antes de guardarlo.',
        esError: true,
      );
      return;
    }

    final trabajadorId = _trabajadorId;
    if (trabajadorId == null) {
      _mostrarMensaje(
        'Tu sesión terminó. Inicia sesión nuevamente para continuar.',
        esError: true,
      );
      return;
    }

    if (esCierre &&
        evidenciasExistentes.isEmpty &&
        widget.actividad.totalEvidencias == 0 &&
        _archivosPendientes.isEmpty) {
      _mostrarMensaje(
        'La evidencia es obligatoria. Agrega al menos una foto o archivo antes de finalizar.',
        esError: true,
      );
      return;
    }

    setState(() => _estaProcesando = true);
    try {
      await _actividadesService.registrarAvance(
        actividadId: widget.actividad.id,
        trabajadorId: trabajadorId,
        comentario: comentario,
        archivos: List<ArchivoEvidenciaPendiente>.from(_archivosPendientes),
        esCierre: esCierre,
      );

      if (!mounted) return;
      setState(() {
        _archivosPendientes.clear();
        _comentarioController.clear();
        if (esCierre) _estatusActual = 'completado';
      });
      _mostrarMensaje(
        esCierre
            ? 'Tarea terminada con evidencia.'
            : 'Avance registrado correctamente.',
      );
      if (esCierre && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _mostrarMensaje(_mensajeError(error), esError: true);
    } finally {
      if (mounted) setState(() => _estaProcesando = false);
    }
  }

  Future<void> _abrirUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return;
      }
    } catch (_) {
      // El mensaje común de abajo mantiene la experiencia consistente.
    }
    if (mounted) {
      _mostrarMensaje('No fue posible abrir esta evidencia.', esError: true);
    }
  }

  String _formatearTamanio(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AvanceActividad>>(
      stream: _actividadesService.obtenerAvancesActividad(widget.actividad.id),
      builder: (context, avancesSnapshot) {
        final avances = avancesSnapshot.data ?? const <AvanceActividad>[];
        return StreamBuilder<List<EvidenciaActividad>>(
          stream: _actividadesService.obtenerEvidenciasActividad(
            widget.actividad.id,
          ),
          builder: (context, evidenciasSnapshot) {
            final evidencias =
                evidenciasSnapshot.data ?? const <EvidenciaActividad>[];
            return _construirModal(
              context,
              avances: avances,
              evidencias: evidencias,
              cargandoHistorial:
                  avancesSnapshot.connectionState == ConnectionState.waiting ||
                  evidenciasSnapshot.connectionState == ConnectionState.waiting,
              errorHistorial:
                  avancesSnapshot.hasError || evidenciasSnapshot.hasError,
            );
          },
        );
      },
    );
  }

  Widget _construirModal(
    BuildContext context, {
    required List<AvanceActividad> avances,
    required List<EvidenciaActividad> evidencias,
    required bool cargandoHistorial,
    required bool errorHistorial,
  }) {
    final estaAtrasada = _estatusActual != 'completado' &&
        DateTime.now().isAfter(widget.actividad.fechaTermino);
    final evidenciaAnterior = widget.actividad.evidenciaFotos
        .where(
          (url) => !evidencias.any((evidencia) => evidencia.url == url),
        )
        .toList(growable: false);
    final puedeReportar = _estatusActual == 'en_progreso' && !_estaBloqueada;
    final colorEstatus = switch (_estatusActual) {
      'completado' => Colors.tealAccent,
      'en_progreso' when estaAtrasada => Colors.redAccent,
      'en_progreso' => Colors.cyanAccent,
      _ when estaAtrasada => Colors.redAccent,
      _ => const Color(0xFFFFDE21),
    };
    final textoEstatus = switch (_estatusActual) {
      'completado' => 'COMPLETADA',
      _ when estaAtrasada => 'ATRASADA',
      'en_progreso' => 'EN PROGRESO',
      _ => 'PENDIENTE',
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.actividad.titulo.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorEstatus.withValues(alpha: 0.6)),
                ),
                child: Text(
                  textoEstatus,
                  style: GoogleFonts.inter(
                    color: colorEstatus,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                estaAtrasada ? Icons.notification_important : Icons.timer,
                color: colorEstatus,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${estaAtrasada ? 'Venció' : 'Límite'}: '
                  '${DateFormat('dd MMM, yyyy - HH:mm').format(widget.actividad.fechaTermino)}',
                  style: GoogleFonts.inter(
                    color: colorEstatus.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight:
                        estaAtrasada ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          if (estaAtrasada && _estatusActual != 'completado') ...[
            const SizedBox(height: 8),
            Text(
              'La fecha límite pasó, pero todavía puedes entregar tu evidencia.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
            ),
          ],
          const Divider(color: Colors.white10, height: 26),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etiqueta('INSTRUCCIONES'),
                  const SizedBox(height: 8),
                  Text(
                    widget.actividad.descripcion,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (widget.actividad.observacionesAdmin.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                          left: BorderSide(color: Colors.cyanAccent, width: 4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOTA DEL ADMINISTRADOR',
                            style: GoogleFonts.inter(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.actividad.observacionesAdmin,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _construirFormularioReporte(puedeReportar),
                  const SizedBox(height: 26),
                  _construirHistorial(
                    avances: avances,
                    evidencias: evidencias,
                    cargando: cargandoHistorial,
                    tieneError: errorHistorial,
                  ),
                  if (evidenciaAnterior.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _etiqueta(
                      'EVIDENCIA ANTERIOR (${evidenciaAnterior.length})',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: evidenciaAnterior.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final url = evidenciaAnterior[index];
                          return InkWell(
                            onTap: () => _abrirUrl(url),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _archivoFallback(
                                  nombre: 'Foto anterior',
                                  icono: Icons.image_not_supported_outlined,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _construirAccionPrincipal(evidencias),
        ],
      ),
    );
  }

  Widget _construirFormularioReporte(bool puedeReportar) {
    final habilitado = puedeReportar && !_estaProcesando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('REPORTAR AVANCE Y EVIDENCIA'),
        const SizedBox(height: 7),
        Text(
          _estatusActual == 'pendiente'
              ? 'Inicia la tarea para registrar avances.'
              : _estatusActual == 'completado'
                  ? 'Esta tarea ya fue finalizada.'
                  : 'Describe lo realizado. Puedes adjuntar todas las fotos y archivos que necesites.',
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _comentarioController,
          enabled: habilitado,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ejemplo: Instalé la estructura y validé las medidas…',
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _botonAdjunto(
              icono: Icons.camera_alt_outlined,
              texto: 'Cámara',
              onPressed: habilitado ? _seleccionarCamara : null,
            ),
            _botonAdjunto(
              icono: Icons.photo_library_outlined,
              texto: 'Varias fotos',
              onPressed: habilitado ? _seleccionarFotos : null,
            ),
            _botonAdjunto(
              icono: Icons.attach_file,
              texto: 'Archivos',
              onPressed: habilitado ? _seleccionarArchivos : null,
            ),
          ],
        ),
        if (_estaSeleccionando) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            color: Color(0xFFFFDE21),
            backgroundColor: Colors.white10,
          ),
        ],
        if (_archivosPendientes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'LISTOS PARA SUBIR (${_archivosPendientes.length})',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: habilitado
                    ? () => setState(() => _archivosPendientes.clear())
                    : null,
                child: const Text('Quitar todos'),
              ),
            ],
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _archivosPendientes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final archivo = _archivosPendientes[index];
              final esImagen = archivo.tipoMime.startsWith('image/');
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: esImagen
                          ? _iconoArchivo(icono: Icons.image_outlined)
                          : _iconoArchivo(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            archivo.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatearTamanio(archivo.tamanioBytes),
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      onPressed: habilitado
                          ? () => setState(
                                () => _archivosPendientes.removeAt(index),
                              )
                          : null,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                habilitado && _comentarioController.text.trim().isNotEmpty
                    ? _registrarAvance
                    : null,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _estaProcesando ? 'GUARDANDO…' : 'REGISTRAR AVANCE',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFDE21),
              side: const BorderSide(color: Color(0xFFFFDE21)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirHistorial({
    required List<AvanceActividad> avances,
    required List<EvidenciaActividad> evidencias,
    required bool cargando,
    required bool tieneError,
  }) {
    if (cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(color: Color(0xFFFFDE21)),
        ),
      );
    }
    if (tieneError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No se pudo cargar el historial. Intenta abrir la tarea nuevamente.',
          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }

    final evidenciasSinAvance = evidencias
        .where(
          (evidencia) =>
              evidencia.avanceId.isEmpty ||
              !avances.any((avance) => avance.id == evidencia.avanceId),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('HISTORIAL DE AVANCES (${avances.length})'),
        const SizedBox(height: 10),
        if (avances.isEmpty && evidencias.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Aún no se han registrado avances.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          )
        else ...[
          ...avances.map((avance) {
            final adjuntos = evidencias
                .where((evidencia) => evidencia.avanceId == avance.id)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tarjetaAvance(avance, adjuntos),
            );
          }),
          if (evidenciasSinAvance.isNotEmpty)
            _tarjetaEvidenciasSueltas(evidenciasSinAvance),
        ],
      ],
    );
  }

  Widget _tarjetaAvance(
    AvanceActividad avance,
    List<EvidenciaActividad> adjuntos,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: avance.esCierre
              ? Colors.tealAccent.withValues(alpha: 0.35)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                avance.esCierre ? Icons.verified_outlined : Icons.update,
                color: avance.esCierre
                    ? Colors.tealAccent
                    : const Color(0xFFFFDE21),
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  avance.esCierre ? 'ENTREGA FINAL' : 'AVANCE',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM, HH:mm').format(avance.fecha),
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            avance.comentario,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (adjuntos.isNotEmpty) ...[
            const SizedBox(height: 10),
            _rejillaEvidencias(adjuntos),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaEvidenciasSueltas(List<EvidenciaActividad> evidencias) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OTRAS EVIDENCIAS',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _rejillaEvidencias(evidencias),
        ],
      ),
    );
  }

  Widget _rejillaEvidencias(List<EvidenciaActividad> evidencias) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: evidencias.map((evidencia) {
        return Tooltip(
          message: evidencia.nombre,
          child: InkWell(
            onTap: () => _abrirUrl(evidencia.url),
            borderRadius: BorderRadius.circular(9),
            child: evidencia.esImagen
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      evidencia.url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _archivoFallback(
                        nombre: evidencia.nombre,
                        icono: Icons.broken_image_outlined,
                      ),
                    ),
                  )
                : _archivoFallback(
                    nombre: evidencia.nombre,
                    icono: Icons.insert_drive_file_outlined,
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _archivoFallback({required String nombre, required IconData icono}) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: Colors.white60, size: 25),
          const SizedBox(height: 4),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _iconoArchivo({IconData icono = Icons.insert_drive_file_outlined}) {
    return Container(
      width: 48,
      height: 48,
      color: Colors.black26,
      alignment: Alignment.center,
      child: Icon(
        icono,
        color: Colors.white60,
      ),
    );
  }

  Widget _botonAdjunto({
    required IconData icono,
    required String texto,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _construirAccionPrincipal(List<EvidenciaActividad> evidencias) {
    if (_estaProcesando || _estaSeleccionando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: CircularProgressIndicator(color: Color(0xFFFFDE21)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: switch (_estatusActual) {
          'pendiente' => _iniciarActividad,
          'en_progreso' => () => _guardarReporte(
                esCierre: true,
                evidenciasExistentes: evidencias,
              ),
          _ => null,
        },
        icon: Icon(
          _estatusActual == 'pendiente'
              ? Icons.play_arrow_rounded
              : _estatusActual == 'en_progreso'
                  ? Icons.task_alt
                  : Icons.verified,
        ),
        label: Text(
          switch (_estatusActual) {
            'pendiente' => 'INICIAR TAREA',
            'en_progreso' => 'FINALIZAR CON EVIDENCIA',
            _ => 'TAREA FINALIZADA',
          },
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _estatusActual == 'pendiente'
              ? const Color(0xFF1E3A8A)
              : const Color(0xFF0F766E),
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white30,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
