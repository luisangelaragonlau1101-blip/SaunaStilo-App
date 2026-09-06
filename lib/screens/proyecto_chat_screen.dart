import '../widgets/shared_media_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../services/proyecto_chat_service.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/audio_note_button.dart';
import '../widgets/dictado_button.dart';

class ProyectoChatScreen extends StatefulWidget {
  final Proyecto proyecto;

  const ProyectoChatScreen({super.key, required this.proyecto});

  @override
  State<ProyectoChatScreen> createState() => _ProyectoChatScreenState();
}

class _ProyectoChatScreenState extends State<ProyectoChatScreen> {
  static const _fondo = Color(0xFF070706);
  static const _tarjeta = Color(0xFF171715);
  static const _acento = Color(0xFFB82B55);
  final _controller = TextEditingController();
  final _chat = ProyectoChatService();
  final _picker = ImagePicker();
  final List<XFile> _imagenes = [];
  UserModel? _usuario;
  bool _cargandoUsuario = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _cargandoUsuario = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _usuario = doc.exists ? UserModel.fromFirestore(doc) : null;
        _cargandoUsuario = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoUsuario = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.proyecto.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              'CHAT Y AVANCES DEL PROYECTO',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 9, letterSpacing: .8),
            ),
          ],
        ),
        actions: [
          DictadoButton(controller: _controller, enabled: !_enviando),
          IconButton(
            tooltip: 'Llamada grupal',
            onPressed: _usuario == null ? null : () => _iniciarReunion(soloAudio: true),
            icon: const Icon(Icons.call_rounded, color: Color(0xFFB7FF2A)),
          ),
          IconButton(
            tooltip: 'Videollamada grupal',
            onPressed: _usuario == null ? null : () => _iniciarReunion(soloAudio: false),
            icon: const Icon(Icons.videocam_rounded, color: _acento),
          ),
        ],
      ),
      body: _cargandoUsuario
          ? const Center(child: CircularProgressIndicator(color: _acento))
          : _usuario == null
              ? _errorUsuario()
              : Column(
                  children: [
                    _cabecera(),
                    Expanded(child: _mensajes()),
                    if (_imagenes.isNotEmpty) _previewImagenes(),
                    _compositor(),
                  ],
                ),
    );
  }

  Widget _cabecera() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 5, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF271F13), Color(0xFF10100F)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _acento.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_2_rounded, color: _acento, size: 31),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aquí queda el historial completo de la instalación: mensajes, fotos, audios y reuniones del equipo.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajes() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chat.mensajes(widget.proyecto.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _acento));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudo abrir el chat. Revisa tu conexión.',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          );
        }
        final mensajes = snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (mensajes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Todavía no hay avances. Comparte el primer mensaje, fotografía o audio de este proyecto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white38, height: 1.45),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          itemCount: mensajes.length,
          itemBuilder: (_, index) => _mensaje(mensajes[index]),
        );
      },
    );
  }

  Widget _mensaje(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final propio = data['autorId']?.toString() == _usuario!.id;
    final nombre = data['autorNombre']?.toString() ?? 'Equipo';
    final texto = data['texto']?.toString() ?? '';
    final audioUrl = data['audioUrl']?.toString() ?? '';
    final reunionUrl = data['reunionUrl']?.toString() ?? '';
    final imagenes = data['imagenes'] is Iterable
        ? (data['imagenes'] as Iterable).map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final likes = data['likesPor'] is Iterable
        ? (data['likesPor'] as Iterable).map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final leGusta = likes.contains(_usuario!.id);
    final fecha = data['fecha'] is Timestamp ? (data['fecha'] as Timestamp).toDate() : DateTime.now();
    final duracion = data['duracionSegundos'] is num
        ? (data['duracionSegundos'] as num).toInt()
        : 0;
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: propio ? const Color(0xFF21332E) : _tarjeta,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: propio ? const Color(0xFFB7FF2A).withOpacity(.24) : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: GoogleFonts.inter(color: propio ? const Color(0xFFB7FF2A) : _acento, fontWeight: FontWeight.w800, fontSize: 11),
            ),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(texto, style: GoogleFonts.inter(color: Colors.white.withOpacity(.88), height: 1.35)),
              SharedMediaCard(text: texto),
            ],
            if (imagenes.isNotEmpty) ...[
              const SizedBox(height: 9),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagenes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.network(
                      imagenes[index],
                      width: 190,
                      height: 170,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 190,
                        child: Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              AudioMessagePlayer(url: audioUrl, durationSeconds: duracion, color: propio ? const Color(0xFFB7FF2A) : _acento),
            ],
            if (reunionUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _abrirUrl(reunionUrl),
                icon: Icon(data['tipo'] == 'llamada' ? Icons.call_rounded : Icons.videocam_rounded),
                label: const Text('ENTRAR A LA REUNIÓN'),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('dd MMM · HH:mm', 'es').format(fecha), style: GoogleFonts.inter(color: Colors.white30, fontSize: 9)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _chat.alternarMeGusta(
                    proyectoId: widget.proyecto.id,
                    mensajeId: doc.id,
                    usuarioId: _usuario!.id,
                    activo: leGusta,
                  ),
                  child: Row(
                    children: [
                      Icon(leGusta ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: leGusta ? Colors.pinkAccent : Colors.white30, size: 16),
                      const SizedBox(width: 3),
                      Text('${likes.length}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewImagenes() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemCount: _imagenes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) => Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<Widget>(
                future: _preview(_imagenes[index]),
                builder: (_, snapshot) => SizedBox(
                  width: 64,
                  height: 64,
                  child: snapshot.data ?? const ColoredBox(color: Colors.white10),
                ),
              ),
            ),
            Positioned(
              right: 1,
              top: 1,
              child: InkWell(
                onTap: () => setState(() => _imagenes.removeAt(index)),
                child: const CircleAvatar(radius: 10, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compositor() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
        decoration: const BoxDecoration(color: Color(0xFF10100F), border: Border(top: BorderSide(color: Colors.white10))),
        child: Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Agregar evidencia',
              color: _tarjeta,
              icon: const Icon(Icons.add_circle_rounded, color: _acento),
              onSelected: (v) { if (v == 'enlace') { addSharedLink(context, _controller); } else { _seleccionarImagen(v); } },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'enlace', child: ListTile(leading: Icon(Icons.movie_filter_outlined), title: Text('Reel o canción'))),
                PopupMenuItem(value: 'camara', child: ListTile(leading: Icon(Icons.photo_camera_rounded), title: Text('Tomar foto'))),
                PopupMenuItem(value: 'galeria', child: ListTile(leading: Icon(Icons.photo_library_rounded), title: Text('Elegir fotografías'))),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe un avance del proyecto',
                  filled: true,
                  fillColor: Colors.white.withOpacity(.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            AudioNoteButton(
              color: const Color(0xFFB7FF2A),
              onAudioReady: (wav, duracion) => _chat.enviarAudio(
                proyecto: widget.proyecto,
                autor: _usuario!,
                wav: wav,
                duracionSegundos: duracion,
              ),
            ),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _acento, foregroundColor: Colors.black),
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagen(String origen) async {
    if (origen == 'camara') {
      final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
      if (foto != null && mounted) setState(() => _imagenes.add(foto));
      return;
    }
    final fotos = await _picker.pickMultiImage(imageQuality: 82);
    if (fotos.isNotEmpty && mounted) setState(() => _imagenes.addAll(fotos));
  }

  Future<Widget> _preview(XFile imagen) async =>
      Image.memory(await imagen.readAsBytes(), fit: BoxFit.cover);

  Future<void> _enviar() async {
    if (_controller.text.trim().isEmpty && _imagenes.isEmpty) return;
    setState(() => _enviando = true);
    final imagenes = List<XFile>.from(_imagenes);
    final texto = _controller.text;
    try {
      await _chat.enviarMensaje(
        proyecto: widget.proyecto,
        autor: _usuario!,
        texto: texto,
        imagenes: imagenes,
      );
      if (!mounted) return;
      _controller.clear();
      setState(_imagenes.clear);
    } catch (_) {
      _mensajeError('No se pudo enviar el avance. Revisa la conexión o los permisos de fotos.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _iniciarReunion({required bool soloAudio}) async {
    final room = 'SaunaStiloProyecto${widget.proyecto.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';
    final url = soloAudio
        ? 'https://meet.jit.si/$room#config.startWithVideoMuted=true'
        : 'https://meet.jit.si/$room';
    try {
      await _chat.anunciarReunion(
        proyecto: widget.proyecto,
        autor: _usuario!,
        url: url,
        soloAudio: soloAudio,
      );
      await _abrirUrl(url);
    } catch (_) {
      _mensajeError('No se pudo iniciar la reunión. Intenta nuevamente.');
    }
  }

  Future<void> _abrirUrl(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(uri)) _mensajeError('No se pudo abrir la reunión.');
    }
  }

  Widget _errorUsuario() {
    return Center(
      child: Text(
        'No pudimos identificar tu perfil. Cierra sesión y vuelve a entrar.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white54),
      ),
    );
  }

  void _mensajeError(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}
