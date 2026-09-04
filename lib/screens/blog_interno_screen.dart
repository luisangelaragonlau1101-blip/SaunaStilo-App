µ®•z∫ËØ
‚∂)‡≤÷ßu™›¢Îi∫–k¢Gß¶*^import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/historia_social_model.dart';
import '../models/user_model.dart';
import '../services/social_service.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/audio_note_button.dart';
import 'notificaciones_screen.dart';
import 'perfil_social_screen.dart';
import 'perfiles_equipo_screen.dart';

class BlogInternoScreen extends StatefulWidget {
  final UserModel usuario;

  const BlogInternoScreen({super.key, required this.usuario});

  @override
  State<BlogInternoScreen> createState() => _BlogInternoScreenState();
}

class _BlogInternoScreenState extends State<BlogInternoScreen> {
  static const _fondo = Color(0xFF000000);
  static const _linea = Color(0xFF262626);
  static const _superficie = Color(0xFF121212);
  static const _rosa = Color(0xFFFF2D7A);
  static const _naranja = Color(0xFFFF8A3D);
  static const _morado = Color(0xFF8B5CF6);
  final SocialService _social = SocialService();
  Timer? _relojHistorias;

  @override
  void initState() {
    super.initState();
    _relojHistorias = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relojHistorias?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        title: Text(
          'SAUNA STILO',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva publicaci√≥n',
            onPressed: _crearPublicacion,
            icon: const Icon(Icons.add_box_outlined, size: 27),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => NotificacionesScreen(usuario: widget.usuario),
              ),
            ),
            icon: const Icon(Icons.favorite_border_rounded, size: 27),
          ),
          IconButton(
            tooltip: 'Equipo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    PerfilesEquipoScreen(usuarioActual: widget.usuario),
              ),
            ),
            icon: const Icon(Icons.people_outline_rounded, size: 27),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _linea),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _social.publicaciones(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return _errorCarga(
              _mensajeError(snapshot.error, lectura: true),
            );
          }
          final posts = snapshot.data?.docs
                  .where((doc) => doc.data()['estado'] != 'subiendo')
                  .toList(growable: true) ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          posts.sort((a, b) => _fecha(b.data()).compareTo(_fecha(a.data())));

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: _superficie,
            onRefresh: () async =>
                Future<void>.delayed(const Duration(milliseconds: 450)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 34),
              children: [
                _historiasEquipo(),
                const Divider(height: 1, color: _linea),
                if (posts.isEmpty) _estadoVacio() else ...posts.map(_publicacion),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _historiasEquipo() {
    return StreamBuilder<List<HistoriaSocialModel>>(
      stream: _social.historiasVigentes(),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final historias = snapshot.data
                ?.where((historia) => historia.estaVigente(ahora))
                .toList(growable: false) ??
            const <HistoriaSocialModel>[];
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            itemCount: historias.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              if (index == 0) return _botonCrearHistoria();
              final historia = historias[index - 1];
              return InkWell(
                onTap: () => _abrirHistorias(historias, index - 1),
                borderRadius: BorderRadius.circular(45),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 69,
                            height: 69,
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_morado, _rosa, _naranja],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: _fondo,
                                shape: BoxShape.circle,
                              ),
                              child: _avatar(
                                nombre: historia.autorNombre,
                                foto: historia.autorFotoUrl,
                                radio: 30,
                              ),
                            ),
                          ),
                          if (historia.texto.isNotEmpty)
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: _morado,
                                child: Icon(
                                  Icons.notes_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _primerNombre(historia.autorNombre),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _botonCrearHistoria() {
    return InkWell(
      onTap: _crearHistoria,
      borderRadius: BorderRadius.circular(45),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 69,
                  height: 69,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _avatar(
                    nombre: widget.usuario.nombre,
                    foto: widget.usuario.fotoUrl ?? '',
                    radio: 30,
                  ),
                ),
                const Positioned(
                  right: -1,
                  bottom: -1,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Color(0xFF1689FF),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tu historia',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearHistoria() async {
    final texto = TextEditingController();
    XFile? imagen;
    bool publicando = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    IconButton(
                      onPressed: publicando
                          ? null
                          : () => Navigator.pop(modalContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Nueva historia o nota',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: publicando
                          ? null
                          : () async {
                              if (texto.text.trim().isEmpty && imagen == null) {
                                _snack(
                                  modalContext,
                                  'Escribe una nota o agrega una fotograf√≠a.',
                                );
                                return;
                              }
                              setModalState(() => publicando = true);
                              try {
                                await _social.crearHistoria(
                                  autor: widget.usuario,
                                  texto: texto.text,
                                  imagen: imagen,
                                );
                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (mounted) {
                                  _snack(
                                    context,
                                    'Historia compartida por 24 horas.',
                                  );
                                }
                              } catch (error) {
                                if (modalContext.mounted) {
                                  setModalState(() => publicando = false);
                                  _snack(
                                    modalContext,
                                    error is ArgumentError
                                        ? error.message.toString()
                                        : _mensajeError(error),
                                  );
                                }
                              }
                            },
                      child: Text(
                        'COMPARTIR',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF5BA8FF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: _linea),
                TextField(
                  controller: texto,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 400,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Escribe una nota para el equipo‚Ä¶',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    counterStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                if (imagen != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<Widget>(
                    future: _preview(imagen!),
                    builder: (_, preview) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: 4 / 5,
                            child: preview.data ??
                                const ColoredBox(color: _superficie),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                            ),
                            onPressed: publicando
                                ? null
                                : () => setModalState(() => imagen = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _linea),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: const Icon(Icons.photo_camera_outlined),
                          title: const Text('C√°mara'),
                          onTap: publicando
                              ? null
                              : () => _elegirFotoHistoria(
                                    modalContext: modalContext,
                                    source: ImageSource.camera,
                                    onSelected: (foto) => setModalState(
                                      () => imagen = foto,
                                    ),
                                  ),
                        ),
                      ),
                      Container(width: 1, height: 46, color: _linea),
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Galer√≠a'),
                          onTap: publicando
                              ? null
                              : () => _elegirFotoHistoria(
                                    modalContext: modalContext,
                                    source: ImageSource.gallery,
                                    onSelected: (foto) => setModalState(
                                      () => imagen = foto,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (publicando) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(
                    color: Colors.white,
                    backgroundColor: _linea,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compartiendo con el equipo‚Ä¶',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    texto.dispose();
  }

  Future<void> _elegirFotoHistoria({
    required BuildContext modalContext,
    required ImageSource source,
    required ValueChanged<XFile> onSelected,
  }) async {
    try {
      final foto = await ImagePicker().pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1800,
        requestFullMetadata: false,
      );
      if (foto != null && modalContext.mounted) onSelected(foto);
    } catch (error) {
      if (modalContext.mounted) {
        _snack(
          modalContext,
          source == ImageSource.camera
              ? 'No se pudo abrir la c√°mara. Revisa su permiso.'
              : 'No se pudo abrir la galer√≠a. Revisa su permiso.',
        );
      }
    }
  }

  void _abrirHistorias(
    List<HistoriaSocialModel> historias,
    int indiceInicial,
  ) {
    final vigentes = historias
        .where((historia) => historia.estaVigente(DateTime.now()))
        .toList(growable: false);
    if (vigentes.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _VisorHistoriasScreen(
          historias: vigentes,
          indiceInicial: indiceInicial.clamp(0, vigentes.length - 1).toInt(),
          usuario: widget.usuario,
          social: _social,
        ),
      ),
    );
  }

  Widget _publicacion(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final autorId = data['autorId']?.toString() ?? '';
    final nombre = data['autorNombre']?.toString() ?? 'Usuario';
    final rol = data['autorRol']?.toString() ?? AppRoles.trabajador;
    final foto = data['autorFotoUrl']?.toString() ?? '';
    final texto = data['texto']?.toString() ?? '';
    final imagenes = data['imagenes'] is Iterable
        ? (data['imagenes'] as Iterable)
            .map((e) => e.toString())
            .where((url) => url.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final videos = data['videos'] is Iterable
        ? (data['videos'] as Iterable)
            .map((e) => e.toString())
            .where((url) => url.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final likes = data['likesPor'] is Iterable
        ? (data['likesPor'] as Iterable)
            .map((e) => e.toString())
            .toList(growable: false)
        : const <String>[];
    final comentarios = data['comentariosCount'] is num
        ? (data['comentariosCount'] as num).toInt()
        : 0;
    final yaLeGusta = likes.contains(widget.usuario.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 9),
          child: Row(
            children: [
              InkWell(
                onTap: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 43,
                  height: 43,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_morado, _rosa, _naranja],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: _fondo,
                      shape: BoxShape.circle,
                    ),
                    child: _avatar(nombre: nombre, foto: foto, radio: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (rol == AppRoles.admin) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF1689FF),
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rol == AppRoles.admin
                            ? 'Administraci√≥n ¬∑ Sauna Stilo'
                            : 'Avance del equipo',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ver perfil',
                onPressed: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        if (imagenes.isNotEmpty)
          _GaleriaPost(imagenes: imagenes, onOpen: _abrirFoto),
        if (videos.isNotEmpty) _GaleriaVideosPost(videos: videos),
        if (imagenes.isEmpty && videos.isEmpty && texto.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.all(27),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF171717), Color(0xFF080808)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Me gusta',
                onPressed: () =>
                    _alternarMeGusta(doc.id, autorId, yaLeGusta),
                icon: Icon(
                  yaLeGusta
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: yaLeGusta ? _rosa : Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                tooltip: 'Comentar',
                onPressed: () => _abrirComentarios(doc.id, autorId),
                icon: const Icon(
                  Icons.mode_comment_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                tooltip: 'Enviar sugerencia',
                onPressed: () => _abrirComentarios(doc.id, autorId),
                icon: const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Ver perfil',
                onPressed: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (likes.isNotEmpty)
                Text(
                  likes.length == 1 ? '1 Me gusta' : '${likes.length} Me gusta',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (likes.isNotEmpty) const SizedBox(height: 7),
              if (texto.isNotEmpty &&
                  (imagenes.isNotEmpty || videos.isNotEmpty))
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$nombre  ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: texto),
                    ],
                  ),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              if (comentarios > 0) ...[
                const SizedBox(height: 7),
                InkWell(
                  onTap: () => _abrirComentarios(doc.id, autorId),
                  child: Text(
                    'Ver ${comentarios == 1 ? 'el comentario' : 'los $comentarios comentarios'}',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                DateFormat('d MMMM ¬∑ HH:mm', 'es').format(_fecha(data)),
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _linea),
      ],
    );
  }

  Future<void> _crearPublicacion() async {
    final texto = TextEditingController();
    final imagenes = <XFile>[];
    final videos = <XFile>[];
    bool publicando = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    IconButton(
                      onPressed: publicando
                          ? null
                          : () => Navigator.pop(modalContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        widget.usuario.rol == AppRoles.admin
                            ? 'Nuevo comunicado'
                            : 'Nuevo avance',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: publicando
                          ? null
                          : () => _publicarDesdeModal(
                                modalContext: modalContext,
                                setModalState: setModalState,
                                texto: texto.text,
                                imagenes: imagenes,
                                videos: videos,
                                onStart: () => publicando = true,
                                onError: () => publicando = false,
                              ),
                      child: Text(
                        'PUBLICAR',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF5BA8FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: _linea),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(
                      nombre: widget.usuario.nombre,
                      foto: widget.usuario.fotoUrl ?? '',
                      radio: 22,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: TextField(
                        controller: texto,
                        minLines: 4,
                        maxLines: 8,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Comparte un avance con el equipo‚Ä¶',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                if (imagenes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imagenes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => FutureBuilder<Widget>(
                        future: _preview(imagenes[index]),
                        builder: (_, preview) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: SizedBox(
                                width: 108,
                                height: 108,
                                child: preview.data ??
                                    const ColoredBox(color: _superficie),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: InkWell(
                                onTap: publicando
                                    ? null
                                    : () => setModalState(
                                          () => imagenes.removeAt(index),
                                        ),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (videos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: videos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => Container(
                        width: 190,
                        padding: const EdgeInsets.fromLTRB(11, 8, 5, 8),
                        decoration: BoxDecoration(
                          color: _superficie,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _linea),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                videos[index].name.isEmpty
                                    ? 'Video ${index + 1}'
                                    : videos[index].name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar video',
                              onPressed: publicando
                                  ? null
                                  : () => setModalState(
                                        () => videos.removeAt(index),
                                      ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _linea),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                        ),
                        title: const Text('Tomar fotograf√≠a'),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                        onTap: publicando
                            ? null
                            : () async {
                                final foto = await ImagePicker().pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 82,
                                  requestFullMetadata: false,
                                );
                                if (foto != null) {
                                  setModalState(() => imagenes.add(foto));
                                }
                              },
                      ),
                      const Divider(height: 1, indent: 56, color: _linea),
                      ListTile(
                        leading: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                        ),
                        title: const Text('Elegir fotos de la galer√≠a'),
                        subtitle: const Text(
                          'Puedes seleccionar varias',
                          style: TextStyle(color: Colors.white38),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                        onTap: publicando
                            ? null
                            : () async {
                                final fotos =
                                    await ImagePicker().pickMultiImage(
                                  imageQuality: 82,
                                  requestFullMetadata: false,
                                );
                                if (fotos.isNotEmpty) {
                                  setModalState(() => imagenes.addAll(fotos));
                                }
                              },
                      ),
                      const Divider(height: 1, indent: 56, color: _linea),
                      ListTile(
                        leading: const Icon(
                          Icons.videocam_outlined,
                          color: Colors.white,
                        ),
                        title: const Text('Grabar video'),
                        subtitle: const Text(
                          'Hasta 50 MB por video',
                          style: TextStyle(color: Colors.white38),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                        onTap: publicando
                            ? null
                            : () => _seleccionarVideo(
                                  source: ImageSource.camera,
                                  modalContext: modalContext,
                                  setModalState: setModalState,
                                  videos: videos,
                                ),
                      ),
                      const Divider(height: 1, indent: 56, color: _linea),
                      ListTile(
                        leading: const Icon(
                          Icons.video_library_outlined,
                          color: Colors.white,
                        ),
                        title: const Text('Elegir video de la galer√≠a'),
                        subtitle: const Text(
                          'Puedes agregar m√°s de uno',
                          style: TextStyle(color: Colors.white38),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                        onTap: publicando
                            ? null
                            : () => _seleccionarVideo(
                                  source: ImageSource.gallery,
                                  modalContext: modalContext,
                                  setModalState: setModalState,
                                  videos: videos,
                                ),
                      ),
                    ],
                  ),
                ),
                if (publicando) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(
                    color: Colors.white,
                    backgroundColor: _linea,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Publicando contenido‚Ä¶',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    texto.dispose();
  }

  Future<void> _publicarDesdeModal({
    required BuildContext modalContext,
    required StateSetter setModalState,
    required String texto,
    required List<XFile> imagenes,
    required List<XFile> videos,
    required VoidCallback onStart,
    required VoidCallback onError,
  }) async {
    if (texto.trim().isEmpty && imagenes.isEmpty && videos.isEmpty) {
      _snack(
        modalContext,
        'Escribe algo o agrega por lo menos una foto o un video.',
      );
      return;
    }
    setModalState(onStart);
    try {
      await _social.crearPublicacion(
        autor: widget.usuario,
        texto: texto,
        imagenes: imagenes,
        videos: videos,
        tipo: widget.usuario.rol == AppRoles.admin
            ? 'comunicado'
            : 'avance',
      );
      if (modalContext.mounted) Navigator.pop(modalContext);
      if (mounted) _snack(context, 'Publicaci√≥n compartida con el equipo.');
    } catch (error) {
      if (modalContext.mounted) {
        setModalState(onError);
        _snack(modalContext, _mensajeError(error));
      }
    }
  }

  Future<void> _seleccionarVideo({
    required ImageSource source,
    required BuildContext modalContext,
    required StateSetter setModalState,
    required List<XFile> videos,
  }) async {
    try {
      final video = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );
      if (video == null) return;
      if (await video.length() > 50 * 1024 * 1024) {
        if (modalContext.mounted) {
          _snack(modalContext, 'El video debe pesar menos de 50 MB.');
        }
        return;
      }
      if (modalContext.mounted) {
        setModalState(() => videos.add(video));
      }
    } catch (_) {
      if (modalContext.mounted) {
        _snack(
          modalContext,
          'No se pudo abrir el video. Revisa los permisos de c√°mara y fotos.',
        );
      }
    }
  }

  Future<void> _alternarMeGusta(
    String publicacionId,
    String autorPublicacionId,
    bool yaLeGusta,
  ) async {
    try {
      await _social.alternarMeGusta(
        publicacionId: publicacionId,
        usuario: widget.usuario,
        autorPublicacionId: autorPublicacionId,
        yaLeGusta: yaLeGusta,
      );
    } catch (error) {
      if (mounted) _snack(context, _mensajeError(error));
    }
  }

  void _abrirComentarios(
    String publicacionId,
    String autorPublicacionId,
  ) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(modalContext).size.height * .82,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comentarios',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(modalContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _linea),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _social.comentarios(publicacionId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _errorCarga(_mensajeError(snapshot.error));
                    }
                    final comentarios =
                        snapshot.data?.docs.toList(growable: true) ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    comentarios.sort(
                      (a, b) =>
                          _fecha(a.data()).compareTo(_fecha(b.data())),
                    );
                    if (comentarios.isEmpty) {
                      return Center(
                        child: Text(
                          'Todav√≠a no hay comentarios.\nInicia la conversaci√≥n.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            height: 1.5,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                      itemCount: comentarios.length,
                      itemBuilder: (_, index) {
                        final data = comentarios[index].data();
                        final autor =
                            data['autorNombre']?.toString() ?? 'Usuario';
                        final foto = data['autorFotoUrl']?.toString() ?? '';
                        final textoComentario =
                            data['texto']?.toString() ?? '';
                        final audioUrl =
                            data['audioUrl']?.toString() ?? '';
                        final duracion = data['duracionSegundos'] is num
                            ? (data['duracionSegundos'] as num).toInt()
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _avatar(
                                nombre: autor,
                                foto: foto,
                                radio: 19,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '$autor  ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (textoComentario.isNotEmpty)
                                            TextSpan(text: textoComentario),
                                        ],
                                      ),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (audioUrl.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 7),
                                        child: AudioMessagePlayer(
                                          url: audioUrl,
                                          durationSeconds: duracion,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'd MMM ¬∑ HH:mm',
                                        'es',
                                      ).format(_fecha(data)),
                                      style: GoogleFonts.inter(
                                        color: Colors.white38,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: _linea),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
                  child: Row(
                    children: [
                      _avatar(
                        nombre: widget.usuario.nombre,
                        foto: widget.usuario.fotoUrl ?? '',
                        radio: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Agrega un comentario‚Ä¶',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                            ),
                            filled: true,
                            fillColor: _superficie,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      AudioNoteButton(
                        onAudioReady: (wav, duracion) async {
                          try {
                            await _social.comentarAudio(
                              publicacionId: publicacionId,
                              autorPublicacionId: autorPublicacionId,
                              autorComentario: widget.usuario,
                              wav: wav,
                              duracionSegundos: duracion,
                            );
                          } catch (error) {
                            if (modalContext.mounted) {
                              _snack(modalContext, _mensajeError(error));
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Enviar',
                        onPressed: () async {
                          final texto = controller.text.trim();
                          if (texto.isEmpty) return;
                          controller.clear();
                          try {
                            await _social.comentar(
                              publicacionId: publicacionId,
                              autorPublicacionId: autorPublicacionId,
                              autorComentario: widget.usuario,
                              texto: texto,
                            );
                          } catch (error) {
                            if (modalContext.mounted) {
                              _snack(modalContext, _mensajeError(error));
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF5BA8FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _avatar({
    required String nombre,
    required String foto,
    required double radio,
  }) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: const Color(0xFF262626),
      backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
      child: foto.isEmpty
          ? Text(
              nombre.trim().isEmpty
                  ? 'S'
                  : nombre.trim().characters.first.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Future<Widget> _preview(XFile imagen) async {
    return Image.memory(
      await imagen.readAsBytes(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white38,
      ),
    );
  }

  void _abrirPerfil(String autorId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PerfilSocialScreen(
          usuarioActual: widget.usuario,
          perfilId: autorId,
        ),
      ),
    );
  }

  void _abrirFoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Iconµ®•z∫ËØ
‚∂)‡≤÷ßu™›¢Îi∫–k¢Gß¶*^s.broken_image_outlined,
                      color: Colors.white38,
                      size: 70,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 78, horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Comparte el trabajo de hoy',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Publica fotos, videos, avances y comentarios para mantener conectado a todo el equipo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _crearPublicacion,
            child: const Text('CREAR PRIMERA PUBLICACI√ìN'),
          ),
        ],
      ),
    );
  }

  Widget _errorCarga(String mensaje) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 16),
            Text(
              'No pudimos abrir la comunidad',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mensajeError(Object? error, {bool lectura = false}) {
    if (error is ArgumentError || error is StateError) {
      return error
          .toString()
          .replaceFirst(RegExp(r'^(Invalid argument\(s\)?:|Bad state:)\s*'), '');
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return lectura
          ? 'Tu sesi√≥n todav√≠a no tiene permiso para abrir la red social.'
          : 'Tu sesi√≥n todav√≠a no tiene permiso para publicar. La configuraci√≥n de acceso debe actualizarse.';
    }
    if (error is FirebaseException &&
        (error.code == 'unauthenticated' ||
            error.code == 'user-token-expired')) {
      return 'Tu sesi√≥n venci√≥. Cierra sesi√≥n y vuelve a entrar.';
    }
    return 'Revisa tu conexi√≥n e int√©ntalo nuevamente.';
  }

  void _snack(BuildContext target, String mensaje) {
    ScaffoldMessenger.of(target)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF262626),
        ),
      );
  }

  static String _primerNombre(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return 'Equipo';
    return limpio.split(RegExp(r'\s+')).first;
  }

  static DateTime _fecha(Map<String, dynamic> data) {
    final value = data['fecha'];
    return value is Timestamp ? value.toDate() : DateTime.now();
  }
}

class _VisorHistoriasScreen extends StatefulWidget {
  final List<HistoriaSocialModel> historias;
  final int indiceInicial;
  final UserModel usuario;
  final SocialService social;

  const _VisorHistoriasScreen({
    required this.historias,
    required this.indiceInicial,
    required this.usuario,
    required this.social,
  });

  @override
  State<_VisorHistoriasScreen> createState() => _VisorHistoriasScreenState();
}

class _VisorHistoriasScreenState extends State<_VisorHistoriasScreen> {
  late final PageController _paginas;
  late List<HistoriaSocialModel> _historias;
  late int _indice;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    _historias = List<HistoriaSocialModel>.from(widget.historias);
    _indice = widget.indiceInicial;
    _paginas = PageController(initialPage: _indice);
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _paginas,
            itemCount: _historias.length,
            onPageChanged: (value) => setState(() => _indice = value),
            itemBuilder: (_, index) => _contenido(_historias[index]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      _historias.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= _indice
                                ? Colors.white
                                : Colors.white30,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _avatarHistoria(_historias[_indice]),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _historias[_indice].autorNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                shadows: const [Shadow(blurRadius: 8)],
                              ),
                            ),
                            Text(
                              '${_tiempo(_historias[_indice].creadaEn)} ¬∑ desaparece en ${_restante(_historias[_indice].expiraEn)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10.5,
                                shadows: const [Shadow(blurRadius: 8)],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_puedeEliminar(_historias[_indice]))
                        IconButton(
                          tooltip: 'Eliminar historia',
                          onPressed: _eliminando ? null : _confirmarEliminar,
                          icon: _eliminando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                ),
                        ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
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

  Widget _contenido(HistoriaSocialModel historia) {
    final tieneImagen = historia.imagenUrl.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tieneImagen)
          Image.network(
            historia.imagenUrl,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF171717),
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5B247A), Color(0xFF1B1331), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .38, 1],
            ),
          ),
        ),
        if (historia.texto.isNotEmpty)
          Align(
            alignment: tieneImagen ? Alignment.bottomCenter : Alignment.center,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  26,
                  120,
                  26,
                  tieneImagen ? 62 : 110,
                ),
                child: Text(
                  historia.texto,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: tieneImagen ? 22 : 28,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarHistoria(HistoriaSocialModel historia) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFF262626),
      backgroundImage: historia.autorFotoUrl.isNotEmpty
          ? NetworkImage(historia.autorFotoUrl)
          : null,
      child: historia.autorFotoUrl.isEmpty
          ? Text(
              historia.autorNombre.trim().isEmpty
                  ? 'S'
                  : historia.autorNombre.trim().characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  bool _puedeEliminar(HistoriaSocialModel historia) =>
      widget.usuario.rol == AppRoles.admin ||
      historia.autorId == widget.usuario.id;

  Future<void> _confirmarEliminar() async {
    final historia = _historias[_indice];
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('¬øEliminar esta historia?'),
        content: const Text('Dejar√° de aparecer inmediatamente para el equipo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _eliminando = true);
    try {
      await widget.social.eliminarHistoria(
        historia: historia,
        solicitante: widget.usuario,
      );
      if (!mounted) return;
      _historias.removeAt(_indice);
      if (_historias.isEmpty) {
        Navigator.pop(context);
        return;
      }
      if (_indice >= _historias.length) _indice = _historias.length - 1;
      setState(() => _eliminando = false);
      _paginas.jumpToPage(_indice);
    } catch (_) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la historia.')),
      );
    }
  }

  static String _tiempo(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 1) return 'ahora';
    if (diferencia.inHours < 1) return 'hace ${diferencia.inMinutes} min';
    return 'hace ${diferencia.inHours} h';
  }

  static String _restante(DateTime expiraEn) {
    final diferencia = expiraEn.difference(DateTime.now());
    if (diferencia.inMinutes <= 1) return '1 min';
    if (diferencia.inHours < 1) return '${diferencia.inMinutes} min';
    return '${diferencia.inHours} h';
  }
}

class _GaleriaPost extends StatefulWidget {
  final List<String> imagenes;
  final ValueChanged<String> onOpen;

  const _GaleriaPost({
    required this.imagenes,
    required this.onOpen,
  });

  @override
  State<_GaleriaPost> createState() => _GaleriaPostState();
}

class _GaleriaPostState extends State<_GaleriaPost> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.imagenes.length,
            onPageChanged: (value) => setState(() => _pagina = value),
            itemBuilder: (_, index) => GestureDetector(
              onDoubleTap: () => widget.onOpen(widget.imagenes[index]),
              child: Image.network(
                widget.imagenes[index],
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF121212),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.imagenes.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_pagina + 1}/${widget.imagenes.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (widget.imagenes.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imagenes.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _pagina ? 7 : 5,
                    height: index == _pagina ? 7 : 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _pagina
                          ? const Color(0xFF1689FF)
                          : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GaleriaVideosPost extends StatelessWidget {
  final List<String> videos;

  const _GaleriaVideosPost({required this.videos});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < videos.length; index++) ...[
          if (index > 0) const SizedBox(height: 2),
          _VideoPost(
            key: ValueKey<String>(videos[index]),
            url: videos[index],
          ),
        ],
      ],
    );
  }
}

class _VideoPost extends StatefulWidget {
  final String url;

  const _VideoPost({super.key, required this.url});

  @override
  State<_VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<_VideoPost> {
  late final VideoPlayerController _controller;
  late final Future<void> _inicializacion;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _inicializacion = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _inicializacion,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Color(0xFF121212),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No se pudo reproducir el video',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Color(0xFF121212),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final aspectRatio = _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9;
        return ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_controller),
                Center(
                  child: IconButton.filled(
                    tooltip: _controller.value.isPlaying
                        ? 'Pausar video'
                        : 'Reproducir video',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(.58),
                      minimumSize: const Size.square(58),
                    ),
                    onPressed: () async {
                      if (_controller.value.isPlaying) {
                        await _controller.pause();
                      } else {
                        await _controller.play();
                      }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 33,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFFFF2D7A),
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.only(top: 10),
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
