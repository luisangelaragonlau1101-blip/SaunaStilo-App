import '../presentation/appearance.dart';
import '../widgets/inline_photo.dart';
import '../services/external_transfer.dart';
import '../widgets/protected_media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/actividad_model.dart';
import '../models/evidencia_actividad_model.dart';
import '../services/actividades_service.dart';

class ModalDetalleActividad extends StatefulWidget {
  final ActividadModel actividad;

  const ModalDetalleActividad({Key? key, required this.actividad})
      : super(key: key);

  @override
  State<ModalDetalleActividad> createState() =>
      _ModalDetalleActividadState();
}

class _ModalDetalleActividadState extends State<ModalDetalleActividad> {
  final TextEditingController _observacionesController =
      TextEditingController();
  final ActividadesService _actividadesService = ActividadesService();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _observacionesController.text = widget.actividad.observacionesAdmin;
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  void _agregarNotaRapida(String texto) {
    setState(() {
      if (_observacionesController.text.trim().isEmpty) {
        _observacionesController.text = texto;
      } else {
        _observacionesController.text =
            '${_observacionesController.text.trim()} | $texto';
      }
      _observacionesController.selection = TextSelection.collapsed(
        offset: _observacionesController.text.length,
      );
    });
  }

  void _mostrarImagenEnGrande(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InlinePhoto(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFDE21),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 240,
                    height: 180,
                    color: StiloColors.surface,
                    alignment: Alignment.center,
                    child: Text(
                      'No fue posible cargar esta imagen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: StiloColors.text.withValues(alpha: .70)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: StiloColors.background.withValues(alpha: .54),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'Cerrar',
                  icon: Icon(Icons.close, color: StiloColors.text),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirArchivo(String url) async {
    await showProtectedMedia(context, url);
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatearTamanio(int bytes) {
    if (bytes <= 0) return 'Tamaño no disponible';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final estaAtrasada = widget.actividad.estatus != 'completado' &&
        DateTime.now().isAfter(widget.actividad.fechaTermino);
    final textoEstatus = estaAtrasada
        ? 'ATRASADO'
        : widget.actividad.estatus.replaceAll('_', ' ').toUpperCase();
    final Color estatusColor = widget.actividad.estatus == 'completado'
        ? Colors.greenAccent
        : estaAtrasada
            ? Colors.redAccent
            : widget.actividad.estatus == 'en_progreso'
                ? Colors.cyanAccent
                : Colors.orangeAccent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
        left: 20,
        right: 20,
        top: 15,
      ),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: StiloColors.text.withValues(alpha: .24),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.actividad.titulo.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: StiloColors.text,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: estatusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: estatusColor.withOpacity(0.35)),
                ),
                child: Text(
                  textoEstatus,
                  style: GoogleFonts.inter(
                    color: estatusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDatosAsignacion(estaAtrasada),
                  Divider(color: StiloColors.text.withValues(alpha: .10), height: 30),
                  _buildAvancesEnVivo(),
                  Divider(color: StiloColors.text.withValues(alpha: .10), height: 30),
                  _buildEvidenciasEnVivo(),
                  Divider(color: StiloColors.text.withValues(alpha: .10), height: 30),
                  _buildComentarioLegacy(),
                  Divider(color: StiloColors.text.withValues(alpha: .10), height: 30),
                  _buildObservacionesAdmin(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFDE21),
                foregroundColor: StiloColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _guardando ? null : _guardarObservaciones,
              child: _guardando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: StiloColors.background,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'ACTUALIZAR OBSERVACIONES',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatosAsignacion(bool estaAtrasada) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              estaAtrasada ? Icons.error_outline : Icons.calendar_today,
              color: estaAtrasada ? Colors.redAccent : StiloColors.text.withValues(alpha: .54),
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                estaAtrasada
                    ? 'Venció el ${DateFormat('dd/MM/yyyy HH:mm').format(widget.actividad.fechaTermino)}'
                    : 'Fecha límite: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.actividad.fechaTermino)}',
                style: GoogleFonts.inter(
                  color: estaAtrasada ? Colors.redAccent : StiloColors.text.withValues(alpha: .70),
                  fontSize: 14,
                  fontWeight:
                      estaAtrasada ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        if (widget.actividad.descripcion.trim().isNotEmpty) ...[
          SizedBox(height: 14),
          _buildSectionTitle('TAREA ASIGNADA'),
          SizedBox(height: 8),
          Text(
            widget.actividad.descripcion.trim(),
            style: GoogleFonts.inter(
              color: StiloColors.text.withValues(alpha: .70),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvancesEnVivo() {
    return StreamBuilder<List<AvanceActividad>>(
      stream: _actividadesService.obtenerAvancesActividad(widget.actividad.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingSection('AVANCES DEL TRABAJADOR');
        }
        if (snapshot.hasError) {
          return _buildStreamError(
            'AVANCES DEL TRABAJADOR',
            'No se pudieron cargar los avances.',
          );
        }

        final avances = List<AvanceActividad>.from(snapshot.data ?? [])
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildSectionTitle('AVANCES DEL TRABAJADOR')),
                _buildLiveBadge(),
              ],
            ),
            SizedBox(height: 12),
            if (avances.isEmpty)
              _buildEmptyPanel(
                icon: Icons.timeline_outlined,
                text: 'El trabajador todavía no ha reportado avances.',
              )
            else
              ...List.generate(
                avances.length,
                (index) => _buildAvanceItem(
                  avances[index],
                  index == avances.length - 1,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAvanceItem(AvanceActividad avance, bool esUltimo) {
    final color = avance.esCierre ? Colors.greenAccent : Colors.cyanAccent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!esUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 4),
                      color: StiloColors.text.withValues(alpha: .12),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: StiloColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd/MM/yyyy · HH:mm').format(avance.fecha),
                          style: GoogleFonts.inter(
                            color: StiloColors.text.withValues(alpha: .54),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (avance.esCierre)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'FINALIZACIÓN',
                            style: GoogleFonts.inter(
                              color: Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    avance.comentario.trim().isEmpty
                        ? 'Avance sin comentario.'
                        : avance.comentario.trim(),
                    style: GoogleFonts.inter(
                      color: StiloColors.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        avance.cantidadEvidencias > 0
                            ? Icons.attach_file
                            : Icons.info_outline,
                        color: StiloColors.text.withValues(alpha: .38),
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        avance.cantidadEvidencias == 1
                            ? '1 evidencia adjunta'
                            : '${avance.cantidadEvidencias} evidencias adjuntas',
                        style: GoogleFonts.inter(
                          color: StiloColors.text.withValues(alpha: .38),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenciasEnVivo() {
    return StreamBuilder<List<EvidenciaActividad>>(
      stream:
          _actividadesService.obtenerEvidenciasActividad(widget.actividad.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingSection('EVIDENCIAS ADJUNTAS');
        }
        if (snapshot.hasError) {
          return _buildStreamError(
            'EVIDENCIAS ADJUNTAS',
            'No se pudieron cargar las evidencias.',
          );
        }

        final evidencias = snapshot.data ?? <EvidenciaActividad>[];
        final urlsNuevas = evidencias.map((e) => e.url).toSet();
        final fotosLegacy = widget.actividad.evidenciaFotos
            .where((url) => !urlsNuevas.contains(url))
            .toList();
        final imagenes = evidencias.where((e) => e.esImagen).toList();
        final archivos = evidencias.where((e) => !e.esImagen).toList();
        final total = evidencias.length + fotosLegacy.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSectionTitle('EVIDENCIAS ADJUNTAS ($total)'),
                ),
                _buildLiveBadge(),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Fotos y archivos enviados para comprobar el trabajo.',
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11),
            ),
            SizedBox(height: 12),
            if (total == 0)
              _buildEmptyPanel(
                icon: Icons.image_not_supported_outlined,
                text: 'El trabajador aún no ha subido evidencia.',
              )
            else ...[
              if (imagenes.isNotEmpty || fotosLegacy.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...imagenes.map(
                      (evidencia) => _buildMiniaturaImagen(
                        evidencia.url,
                        evidencia.nombre,
                      ),
                    ),
                    ...fotosLegacy.map(
                      (url) => _buildMiniaturaImagen(url, 'Fotografía'),
                    ),
                  ],
                ),
              if ((imagenes.isNotEmpty || fotosLegacy.isNotEmpty) &&
                  archivos.isNotEmpty)
                SizedBox(height: 14),
              if (archivos.isNotEmpty) ...archivos.map(_buildArchivoCard),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMiniaturaImagen(String url, String nombre) {
    return Semantics(
      button: true,
      label: 'Abrir $nombre',
      child: InkWell(
        onTap: () => _mostrarImagenEnGrande(context, url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: StiloColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StiloColors.text.withValues(alpha: .10)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InlinePhoto(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFDE21),
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.broken_image_outlined,
                  color: StiloColors.text.withValues(alpha: .38),
                  size: 32,
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: StiloColors.background.withValues(alpha: .54),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.zoom_in,
                    color: StiloColors.text,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivoCard(EvidenciaActividad evidencia) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StiloColors.text.withValues(alpha: .10)),
      ),
      child: ListTile(
        onTap: () => _abrirArchivo(evidencia.url),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Color(0xFFFFDE21).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.insert_drive_file_outlined,
            color: Color(0xFFFFDE21),
          ),
        ),
        title: Text(
          evidencia.nombre.trim().isEmpty ? 'Archivo adjunto' : evidencia.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: StiloColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatearTamanio(evidencia.tamanioBytes),
          style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11),
        ),
        trailing:
            Icon(Icons.open_in_new, color: StiloColors.text.withValues(alpha: .54), size: 20),
      ),
    );
  }

  Widget _buildComentarioLegacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COMENTARIO GENERAL DEL TRABAJADOR'),
        SizedBox(height: 8),
        Text(
          widget.actividad.comentariosTrabajador.trim().isEmpty
              ? 'Sin comentario general del operador.'
              : widget.actividad.comentariosTrabajador.trim(),
          style: GoogleFonts.inter(
            color: StiloColors.text.withValues(alpha: .70),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildObservacionesAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OBSERVACIONES Y NOTAS OPERATIVAS (ADMIN)',
          style: GoogleFonts.inter(
            color: Color(0xFFFFDE21),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip('Descuento por error', Colors.redAccent),
            _buildQuickChip('Multa de herramienta', Colors.orangeAccent),
            _buildQuickChip('Llamada de atención', Colors.yellow),
            _buildQuickChip('Incentivo económico', Colors.greenAccent),
            _buildQuickChip('Repetición del trabajo', Colors.greenAccent),
            _buildQuickChip('Suspensión', Colors.redAccent),
          ],
        ),
        SizedBox(height: 15),
        TextFormField(contextMenuBuilder: privacyTextMenu,
          controller: _observacionesController,
          maxLines: 3,
          style: GoogleFonts.inter(color: StiloColors.text),
          decoration: InputDecoration(
            hintText:
                'Escribe multas, suspensiones, observaciones o felicitaciones aquí...',
            hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 13),
            filled: true,
            fillColor: StiloColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String texto) {
    return Text(
      texto,
      style: GoogleFonts.inter(
        color: StiloColors.text.withValues(alpha: .54),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.greenAccent, size: 7),
          SizedBox(width: 5),
          Text(
            'EN VIVO',
            style: GoogleFonts.inter(
              color: Colors.greenAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(titulo),
        SizedBox(height: 12),
        Center(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(
              color: Color(0xFFFFDE21),
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamError(String titulo, String mensaje) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(titulo),
        SizedBox(height: 12),
        _buildEmptyPanel(icon: Icons.cloud_off_outlined, text: mensaje),
      ],
    );
  }

  Widget _buildEmptyPanel({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: StiloColors.text.withValues(alpha: .24), size: 32),
          SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, Color color) {
    return ActionChip(
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.4)),
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () => _agregarNotaRapida(label),
    );
  }

  Future<void> _guardarObservaciones() async {
    setState(() => _guardando = true);
    try {
      await _actividadesService.registrarObservacionesAdmin(
        widget.actividad.id,
        _observacionesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Observaciones actualizadas correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
