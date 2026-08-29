import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../services/media_upload_service.dart';
import '../services/notificaciones_service.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/audio_note_button.dart';
import 'proyecto_chat_screen.dart';

class MensajesEquipoScreen extends StatelessWidget {
  final UserModel usuario;

  const MensajesEquipoScreen({super.key, required this.usuario});

  static const _fondo = Color(0xFF050505);
  static const _acento = Color(0xFF70E1D0);

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final Query<Map<String, dynamic>> proyectos =
        usuario.rol == AppRoles.admin
        ? db.collection('proyectos')
        : db
              .collection('proyectos')
              .where('encargados', arrayContains: usuario.id);
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text(
          'MENSAJES',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _encabezado()),
          const SliverToBoxAdapter(child: _TituloSeccion('GRUPOS DE PROYECTO')),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: proyectos.snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 86,
                    child: Center(child: CircularProgressIndicator(color: _acento)),
                  );
                }
                if (docs.isEmpty) {
                  return const _Vacio('No tienes grupos de proyecto asignados.');
                }
                return SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 13),
                    itemBuilder: (context, index) {
                      final proyecto = Proyecto.fromFirestore(docs[index]);
                      return InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProyectoChatScreen(proyecto: proyecto),
                          ),
                        ),
                        child: SizedBox(
                          width: 82,
                          child: Column(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF70E1D0), Color(0xFFD6A85F)],
                                  ),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(
                                  Icons.groups_2_rounded,
                                  color: Colors.black,
                                  size: 31,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                proyecto.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: _TituloSeccion('EQUIPO SAUNA STILO')),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('usuarios').orderBy('nombre').snapshots(),
            builder: (context, snapshot) {
              final equipo = (snapshot.data?.docs ?? const [])
                  .where((doc) => doc.id != usuario.id)
                  .map(UserModel.fromFirestore)
                  .toList(growable: false);
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(color: _acento)),
                );
              }
              return SliverList.builder(
                itemCount: equipo.length,
                itemBuilder: (context, index) {
                  final persona = equipo[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    leading: CircleAvatar(
                      radius: 27,
                      backgroundColor: const Color(0xFF1E1E1E),
                      backgroundImage: persona.fotoUrl?.isNotEmpty == true
                          ? NetworkImage(persona.fotoUrl!)
                          : null,
                      child: persona.fotoUrl?.isNotEmpty == true
                          ? null
                          : Text(
                              persona.nombre.isEmpty
                                  ? 'S'
                                  : persona.nombre[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    title: Text(
                      persona.nombre,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      persona.rol.toUpperCase(),
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                    ),
                    trailing: const Icon(Icons.chat_bubble_rounded, color: _acento),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConversacionPrivadaScreen(
                          usuario: usuario,
                          contacto: persona,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_unread_chat_alt_rounded, color: _acento, size: 32),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Habla en privado o entra al grupo de tu proyecto. Envía texto, fotos, videos, archivos, audios y reuniones.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversacionPrivadaScreen extends StatefulWidget {
  final UserModel usuario;
  final UserModel contacto;

  const ConversacionPrivadaScreen({
    super.key,
    required this.usuario,
    required this.contacto,
  });

  @override
  State<ConversacionPrivadaScreen> createState() =>
      _ConversacionPrivadaScreenState();
}

class _ConversacionPrivadaScreenState
    extends State<ConversacionPrivadaScreen> {
  static const _fondo = Color(0xFF050505);
  static const _tarjeta = Color(0xFF171717);
  static const _acento = Color(0xFF70E1D0);
  final _texto = TextEditingController();
  final _media = MediaUploadService();
  final _adjuntos = <_Adjunto>[];
  bool _enviando = false;

  String get _conversationId {
    final ids = [widget.usuario.id, widget.contacto.id]..sort();
    return 'privado_${ids.join('_')}';
  }

  DocumentReference<Map<String, dynamic>> get _conversation =>
      FirebaseFirestore.instance.collection('conversaciones').doc(_conversationId);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _conversation.collection('mensajes');

  @override
  void initState() {
    super.initState();
    _prepararConversacion();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _prepararConversacion() {
    return _conversation.set({
      'participantes': [widget.usuario.id, widget.contacto.id],
      'nombres': {
        widget.usuario.id: widget.usuario.nombre,
        widget.contacto.id: widget.contacto.nombre,
      },
      'actualizadaEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _tarjeta,
              backgroundImage: widget.contacto.fotoUrl?.isNotEmpty == true
                  ? NetworkImage(widget.contacto.fotoUrl!)
                  : null,
              child: widget.contacto.fotoUrl?.isNotEmpty == true
                  ? null
                  : Text(widget.contacto.nombre.isEmpty ? 'S' : widget.contacto.nombre[0]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.contacto.nombre,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Llamada',
            onPressed: () => _iniciarReunion(soloAudio: true),
            icon: const Icon(Icons.call_rounded, color: _acento),
          ),
          IconButton(
            tooltip: 'Videollamada',
            onPressed: () => _iniciarReunion(soloAudio: false),
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFFD6A85F)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _listaMensajes()),
          if (_adjuntos.isNotEmpty) _vistaAdjuntos(),
          _compositor(),
        ],
      ),
    );
  }

  Widget _listaMensajes() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messages.orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _acento));
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Inicia la conversación con ${widget.contacto.nombre}.',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, index) => _burbuja(docs[index].data()),
        );
      },
    );
  }

  Widget _burbuja(Map<String, dynamic> data) {
    final propio = data['autorId'] == widget.usuario.id;
    final texto = data['texto']?.toString() ?? '';
    final audio = data['audioUrl']?.toString() ?? '';
    final reunion = data['reunionUrl']?.toString() ?? '';
    final archivos = data['archivos'] is Iterable
        ? (data['archivos'] as Iterable)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final fecha = data['fecha'] is Timestamp
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: propio ? const Color(0xFF18312D) : _tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: propio ? _acento.withOpacity(.25) : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (texto.isNotEmpty)
              Text(
                texto,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: data['sticker'] == true ? 34 : 14,
                  height: 1.35,
                ),
              ),
            ...archivos.map(_archivoMensaje),
            if (audio.isNotEmpty)
              AudioMessagePlayer(
                url: audio,
                durationSeconds: (data['duracionSegundos'] as num?)?.toInt() ?? 0,
                color: propio ? _acento : const Color(0xFFD6A85F),
              ),
            if (reunion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () => _abrir(reunion),
                  icon: Icon(data['tipo'] == 'llamada' ? Icons.call : Icons.videocam),
                  label: const Text('ENTRAR A LA REUNIÓN'),
                ),
              ),
            const SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(fecha),
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _archivoMensaje(Map<String, dynamic> archivo) {
    final url = archivo['url']?.toString() ?? '';
    final tipo = archivo['tipo']?.toString() ?? 'archivo';
    final nombre = archivo['nombre']?.toString() ?? 'Archivo';
    if (tipo == 'imagen') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url,
            width: 270,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 100,
              child: Center(child: Icon(Icons.broken_image_rounded)),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _abrir(url),
        icon: Icon(tipo == 'video' ? Icons.play_circle_fill_rounded : Icons.attach_file_rounded),
        label: Text(nombre, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _vistaAdjuntos() {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _adjuntos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) => Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _tarjeta,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _adjuntos[index].tipo == 'imagen'
                    ? Icons.image_rounded
                    : _adjuntos[index].tipo == 'video'
                    ? Icons.movie_rounded
                    : Icons.insert_drive_file_rounded,
                color: _acento,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _adjuntos[index].nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _adjuntos.removeAt(index)),
                child: const Icon(Icons.close, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compositor() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            PopupMenuButton<String>(
              color: _tarjeta,
              icon: const Icon(Icons.add_circle_rounded, color: _acento),
              onSelected: _seleccionarAdjunto,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'camara', child: Text('📷 Cámara')),
                PopupMenuItem(value: 'galeria', child: Text('🖼️ Fotos')),
                PopupMenuItem(value: 'video', child: Text('🎬 Video')),
                PopupMenuItem(value: 'archivo', child: Text('📎 Archivo')),
              ],
            ),
            IconButton(
              tooltip: 'Emojis y stickers',
              onPressed: _mostrarEmojis,
              icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFD6A85F)),
            ),
            Expanded(
              child: TextField(
                controller: _texto,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Mensaje…',
                  filled: true,
                  fillColor: Colors.white.withOpacity(.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(21),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            AudioNoteButton(color: _acento, onAudioReady: _enviarAudio),
            IconButton(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: _acento),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarAdjunto(String opcion) async {
    try {
      if (opcion == 'camara') {
        final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
        if (image != null) {
          _agregarXFile(image, 'imagen');
        }
        return;
      }
      if (opcion == 'galeria') {
        final images = await ImagePicker().pickMultiImage(imageQuality: 88);
        for (final image in images) {
          await _agregarXFile(image, 'imagen');
        }
        return;
      }
      if (opcion == 'video') {
        final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (video != null) await _agregarXFile(video, 'video');
        return;
      }
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      for (final file in result?.files ?? const <PlatformFile>[]) {
        if (file.bytes == null) continue;
        _adjuntos.add(
          _Adjunto(
            nombre: file.name,
            bytes: file.bytes!,
            tipo: _tipoDeNombre(file.name),
            mime: _mime(file.name),
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (_) {
      _aviso('No se pudo abrir ese archivo. Revisa los permisos.');
    }
  }

  Future<void> _agregarXFile(XFile file, String tipo) async {
    final bytes = await file.readAsBytes();
    _adjuntos.add(
      _Adjunto(nombre: file.name, bytes: bytes, tipo: tipo, mime: _mime(file.name)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _enviar() async {
    final limpio = _texto.text.trim();
    if (limpio.isEmpty && _adjuntos.isEmpty) return;
    setState(() => _enviando = true);
    final ref = _messages.doc();
    final archivos = <Map<String, dynamic>>[];
    try {
      for (var i = 0; i < _adjuntos.length; i++) {
        final item = _adjuntos[i];
        final upload = await _media.upload(
          bytes: item.bytes,
          fileName: item.nombre,
          contentType: item.mime,
          folder:
              'mensajes/$_conversationId/${ref.id}/${i}_${item.nombre}',
        );
        archivos.add({
          'url': upload.url,
          'ruta': upload.path,
          'tipo': item.tipo,
          'nombre': item.nombre,
        });
      }
      await ref.set({
        'autorId': widget.usuario.id,
        'autorNombre': widget.usuario.nombre,
        'texto': limpio,
        'archivos': archivos,
        'fecha': FieldValue.serverTimestamp(),
        'tipo': archivos.isEmpty ? 'texto' : 'multimedia',
      });
      await _actualizarYNotificar(
        archivos.isNotEmpty ? 'Te envió archivos multimedia.' : limpio,
      );
      _texto.clear();
      _adjuntos.clear();
    } catch (_) {
      _aviso('No se pudo enviar el mensaje. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarAudio(Uint8List wav, int seconds) async {
    final ref = _messages.doc();
    final upload = await _media.upload(
      bytes: wav,
      fileName: 'audio_${ref.id}.wav',
      contentType: 'audio/wav',
      folder: 'mensajes/$_conversationId/${ref.id}/audio.wav',
    );
    await ref.set({
      'autorId': widget.usuario.id,
      'autorNombre': widget.usuario.nombre,
      'texto': '',
      'audioUrl': upload.url,
      'audioRuta': upload.path,
      'duracionSegundos': seconds,
      'archivos': <Map<String, dynamic>>[],
      'fecha': FieldValue.serverTimestamp(),
      'tipo': 'audio',
    });
    await _actualizarYNotificar('Te envió una nota de voz.');
  }

  Future<void> _enviarSticker(String emoji) async {
    await _messages.add({
      'autorId': widget.usuario.id,
      'autorNombre': widget.usuario.nombre,
      'texto': emoji,
      'sticker': true,
      'archivos': <Map<String, dynamic>>[],
      'fecha': FieldValue.serverTimestamp(),
      'tipo': 'sticker',
    });
    await _actualizarYNotificar('Te envió $emoji');
  }

  Future<void> _iniciarReunion({required bool soloAudio}) async {
    final room = 'SaunaStilo-${_conversationId.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-')}-${DateFormat('yyyyMMdd').format(DateTime.now())}';
    final url = 'https://meet.jit.si/$room';
    await _messages.add({
      'autorId': widget.usuario.id,
      'autorNombre': widget.usuario.nombre,
      'texto': soloAudio ? 'Inició una llamada.' : 'Inició una videollamada.',
      'reunionUrl': url,
      'tipo': soloAudio ? 'llamada' : 'videollamada',
      'archivos': <Map<String, dynamic>>[],
      'fecha': FieldValue.serverTimestamp(),
    });
    await _actualizarYNotificar(
      soloAudio ? 'Te está llamando.' : 'Inició una videollamada contigo.',
    );
    await _abrir(url);
  }

  Future<void> _actualizarYNotificar(String resumen) async {
    await _conversation.set({
      'participantes': [widget.usuario.id, widget.contacto.id],
      'ultimoMensaje': resumen,
      'actualizadaEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('notificaciones').add(
      NotificacionesService.datosAviso(
        titulo: widget.usuario.nombre,
        mensaje: resumen,
        tipo: 'mensaje_privado',
        destinatarioId: widget.contacto.id,
      ),
    );
  }

  void _mostrarEmojis() {
    const emojis = ['👍', '❤️', '🔥', '👏', '✅', '💪', '🛠️', '♨️', '📸', '🚐', '🎉', '😂'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _tarjeta,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: emojis
                .map(
                  (emoji) => InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _enviarSticker(emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  static String _tipoDeNombre(String name) {
    final lower = name.toLowerCase();
    if (RegExp(r'\.(jpg|jpeg|png|webp|heic)$').hasMatch(lower)) return 'imagen';
    if (RegExp(r'\.(mp4|mov|m4v|webm)$').hasMatch(lower)) return 'video';
    return 'archivo';
  }

  static String _mime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

class _Adjunto {
  final String nombre;
  final Uint8List bytes;
  final String tipo;
  final String mime;

  const _Adjunto({
    required this.nombre,
    required this.bytes,
    required this.tipo,
    required this.mime,
  });
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 13),
    child: Text(
      texto,
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF121212),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(texto, style: GoogleFonts.inter(color: Colors.white38)),
  );
}
