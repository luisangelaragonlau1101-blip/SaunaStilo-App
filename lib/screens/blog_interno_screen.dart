import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
            tooltip: 'Nueva publicación',
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
      builder: (context, snapshot) {
        final equipo = snapshot.data?.docs.toList(growable: true) ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        equipo.sort((a, b) {
          if (a.id == widget.usuario.id) return -1;
          if (b.id == widget.usuario.id) return 1;
          return (a.data()['nombre']?.toString() ?? '')
              .compareTo(b.data()['nombre']?.toString() ?? '');
        });
        final visibles = equipo.take(18).toList(growable: false);
        return SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            itemCount: visibles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final persona = visibles[index];
              final data = persona.data();
              final nombre = data['nombre']?.toString().trim() ?? 'Equipo';
              final foto = data['fotoUrl']?.toString() ?? '';
              final esActual = persona.id == widget.usuario.id;
              return InkWell(
                onTap: esActual
                    ? _crearPublicacion
                    : () => _abrirPerfil(persona.id),
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
                                nombre: nombre,
                                foto: foto,
                                radio: 30,
                              ),
                            ),
                          ),
                          if (esActual)
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
                        esActual ? 'Tu avance' : _primerNombre(nombre),
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
                            ? 'Administración · Sauna Stilo'
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
          _GaleriaPost(imagenes: imagenes, onOpen: _abrirFoto)
        else if (texto.isNotEmpty)
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
              if (texto.isNotEmpty && imagenes.isNotEmpty)
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
                DateFormat('d MMMM · HH:mm', 'es').format(_fecha(data)),
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
                          hintText: 'Comparte un avance con el equipo…',
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
                        title: const Text('Tomar fotografía'),
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
                        title: const Text('Elegir fotos de la galería'),
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
                    'Publicando fotografías…',
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
    required VoidCallback onStart,
    required VoidCallback onError,
  }) async {
    if (texto.trim().isEmpty && imagenes.isEmpty) {
      _snack(
        modalContext,
        'Escribe algo o agrega por lo menos una fotografía.',
      );
      return;
    }
    setModalState(onStart);
    try {
      await _social.crearPublicacion(
        autor: widget.usuario,
        texto: texto,
        imagenes: imagenes,
        tipo: widget.usuario.rol == AppRoles.admin
            ? 'comunicado'
            : 'avance',
      );
      if (modalContext.mounted) Navigator.pop(modalContext);
      if (mounted) _snack(context, 'Publicación compartida con el equipo.');
    } catch (error) {
      setModalState(onError);
      if (modalContext.mounted) {
        _snack(modalContext, _mensajeError(error));
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
                          'Todavía no hay comentarios.\\nInicia la conversación.',
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
                                        'd MMM · HH:mm',
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
                            hintText: 'Agrega un comentario…',
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
                      Icons.broken_image_outlined,
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
            'Publica fotografías, avances y comentarios para mantener conectado a todo el equipo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _crearPublicacion,
            child: const Text('CREAR PRIMERA PUBLICACIÓN'),
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
    if (error is FirebaseException && error.code == 'permission-denied') {
      return lectura
          ? 'Tu sesión todavía no tiene permiso para abrir la red social.'
          : 'Tu sesión todavía no tiene permiso para publicar. La configuración de acceso debe actualizarse.';
    }
    if (error is FirebaseException &&
        (error.code == 'unauthenticated' ||
            error.code == 'user-token-expired')) {
      return 'Tu sesión venció. Cierra sesión y vuelve a entrar.';
    }
    return 'Revisa tu conexión e inténtalo nuevamente.';
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
    return limpio.split(RegExp(r'\\s+')).first;
  }

  static DateTime _fecha(Map<String, dynamic> data) {
    final value = data['fecha'];
    return value is Timestamp ? value.toDate() : DateTime.now();
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
