import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../services/social_service.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/audio_note_button.dart';
import 'perfil_social_screen.dart';
import 'perfiles_equipo_screen.dart';

class BlogInternoScreen extends StatefulWidget {
  final UserModel usuario;
  const BlogInternoScreen({super.key, required this.usuario});

  @override
  State<BlogInternoScreen> createState() => _BlogInternoScreenState();
}

class _BlogInternoScreenState extends State<BlogInternoScreen> {
  static const _fondo = Color(0xFF050505);
  static const _tarjeta = Color(0xFF151515);
  static const _acento = Color(0xFF00E5FF);
  final SocialService _social = SocialService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COMUNIDAD', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
            Text('La red interna de Sauna Stilo', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mi perfil',
            onPressed: () => _abrirPerfil(widget.usuario.id),
            icon: const Icon(Icons.account_circle_rounded),
          ),
          IconButton(
            tooltip: 'Equipo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PerfilesEquipoScreen(usuarioActual: widget.usuario)),
            ),
            icon: const Icon(Icons.groups_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _acento,
        foregroundColor: Colors.black,
        onPressed: _crearPublicacion,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(
          widget.usuario.rol == AppRoles.admin ? 'COMUNICADO' : 'PUBLICAR AVANCE',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _social.publicaciones(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _acento));
          }
          if (snapshot.hasError) {
            return _errorCarga(
              'No se pudo abrir la comunidad. Revisa tu conexión y vuelve a intentarlo.',
            );
          }
          final posts = snapshot.data?.docs.toList(growable: true) ?? [];
          posts.sort((a, b) => _fecha(b.data()).compareTo(_fecha(a.data())));
          return RefreshIndicator(
            onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 450)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
              children: [
                _encabezadoComunidad(),
                const SizedBox(height: 14),
                if (posts.isEmpty) _estadoVacio() else ...posts.map(_tarjetaPost),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _encabezadoComunidad() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: _acento, size: 46),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRABAJO CONECTADO',
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comparte avances, fotografías y sugerencias con todo el equipo.',
                  style: GoogleFonts.inter(color: Colors.white60, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPost(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final autorId = data['autorId']?.toString() ?? '';
    final nombre = data['autorNombre']?.toString() ?? 'Usuario';
    final rol = data['autorRol']?.toString() ?? AppRoles.trabajador;
    final foto = data['autorFotoUrl']?.toString() ?? '';
    final texto = data['texto']?.toString() ?? '';
    final imagenes = data['imagenes'] is Iterable
        ? (data['imagenes'] as Iterable).map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final likes = data['likesPor'] is Iterable
        ? (data['likesPor'] as Iterable).map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final comentarios = data['comentariosCount'] is num ? (data['comentariosCount'] as num).toInt() : 0;
    final yaLeGusta = likes.contains(widget.usuario.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _tarjeta,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: rol == AppRoles.admin ? const Color(0xFF8B5CF6).withOpacity(.45) : Colors.white10,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InkWell(
                  onTap: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: rol == AppRoles.admin ? const Color(0xFF8B5CF6) : const Color(0xFF0F766E),
                    backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                    child: foto.isEmpty ? Text(nombre.isEmpty ? 'U' : nombre[0].toUpperCase()) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: autorId.isEmpty ? null : () => _abrirPerfil(autorId),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(
                          '${rol == AppRoles.admin ? 'ADMINISTRACIÓN' : 'AVANCE'} · ${DateFormat('dd MMM · HH:mm', 'es').format(_fecha(data))}',
                          style: GoogleFonts.inter(
                            color: rol == AppRoles.admin ? const Color(0xFFC4B5FD) : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (texto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
              child: Text(texto, style: GoogleFonts.inter(color: Colors.white.withOpacity(.9), height: 1.5)),
            ),
          if (imagenes.isNotEmpty)
            SizedBox(
              height: 330,
              child: PageView.builder(
                itemCount: imagenes.length,
                itemBuilder: (_, index) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imagenes[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 60),
                      ),
                    ),
                    if (imagenes.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text('${index + 1}/${imagenes.length}'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _social.alternarMeGusta(
                    publicacionId: doc.id,
                    usuario: widget.usuario,
                    autorPublicacionId: autorId,
                    yaLeGusta: yaLeGusta,
                  ),
                  icon: Icon(
                    yaLeGusta ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: yaLeGusta ? const Color(0xFFFF3399) : Colors.white54,
                  ),
                  label: Text('${likes.length}', style: const TextStyle(color: Colors.white54)),
                ),
                TextButton.icon(
                  onPressed: () => _abrirComentarios(doc.id, autorId),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: _acento),
                  label: Text('$comentarios sugerencias', style: const TextStyle(color: Colors.white54)),
                ),
                const Spacer(),
                if (autorId.isNotEmpty)
                  IconButton(
                    tooltip: 'Ver perfil',
                    onPressed: () => _abrirPerfil(autorId),
                    icon: const Icon(Icons.person_outline_rounded, color: Colors.white38),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _crearPublicacion() async {
    final texto = TextEditingController();
    final imagenes = <XFile>[];
    bool publicando = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.usuario.rol == AppRoles.admin ? 'NUEVO COMUNICADO' : 'PUBLICAR MI AVANCE',
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: texto,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '¿Qué avance, noticia o sugerencia quieres compartir?',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: publicando
                            ? null
                            : () async {
                                final foto = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 82);
                                if (foto != null) setModalState(() => imagenes.add(foto));
                              },
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('CÁMARA'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: publicando
                            ? null
                            : () async {
                                final fotos = await ImagePicker().pickMultiImage(imageQuality: 82);
                                if (fotos.isNotEmpty) setModalState(() => imagenes.addAll(fotos));
                              },
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('GALERÍA'),
                      ),
                    ),
                  ],
                ),
                if (imagenes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imagenes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => FutureBuilder<Widget>(
                        future: _preview(imagenes[index]),
                        builder: (_, snapshot) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 82,
                                height: 82,
                                child: snapshot.data ?? const ColoredBox(color: Colors.white10),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: InkWell(
                                onTap: () => setModalState(() => imagenes.removeAt(index)),
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black87,
                                  child: Icon(Icons.close_rounded, size: 14),
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
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _acento, foregroundColor: Colors.black),
                    onPressed: publicando
                        ? null
                        : () async {
                            setModalState(() => publicando = true);
                            try {
                              await _social.crearPublicacion(
                                autor: widget.usuario,
                                texto: texto.text,
                                imagenes: imagenes,
                                tipo: widget.usuario.rol == AppRoles.admin ? 'comunicado' : 'avance',
                              );
                              if (modalContext.mounted) Navigator.pop(modalContext);
                            } catch (error) {
                              setModalState(() => publicando = false);
                              if (modalContext.mounted) {
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(content: Text('No se pudo publicar: $error')),
                                );
                              }
                            }
                          },
                    icon: publicando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('PUBLICAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    texto.dispose();
  }

  Future<Widget> _preview(XFile imagen) async {
    final bytes = await imagen.readAsBytes();
    return Image.memory(bytes, fit: BoxFit.cover);
  }

  void _abrirPerfil(String autorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilSocialScreen(usuarioActual: widget.usuario, perfilId: autorId),
      ),
    );
  }

  void _abrirComentarios(String publicacionId, String autorPublicacionId) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(modalContext).size.height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 10, 10),
                child: Row(
                  children: [
                    Text('COMENTARIOS Y SUGERENCIAS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(modalContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _social.comentarios(publicacionId),
                  builder: (context, snapshot) {
                    final comentarios = snapshot.data?.docs.toList(growable: true) ?? [];
                    comentarios.sort((a, b) => _fecha(a.data()).compareTo(_fecha(b.data())));
                    if (comentarios.isEmpty) {
                      return Center(
                        child: Text('Sé el primero en dejar una sugerencia.', style: GoogleFonts.inter(color: Colors.white38)),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comentarios.length,
                      itemBuilder: (_, index) {
                        final data = comentarios[index].data();
                        final autor = data['autorNombre']?.toString() ?? 'Usuario';
                        final textoComentario = data['texto']?.toString() ?? '';
                        final audioUrl = data['audioUrl']?.toString() ?? '';
                        final duracion = data['duracionSegundos'] is num
                            ? (data['duracionSegundos'] as num).toInt()
                            : 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0F766E),
                            child: Text(autor.isEmpty ? 'U' : autor[0].toUpperCase()),
                          ),
                          title: Text(
                            autor,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (textoComentario.isNotEmpty)
                                  Text(
                                    textoComentario,
                                    style: GoogleFonts.inter(
                                      color: Colors.white60,
                                      height: 1.35,
                                    ),
                                  ),
                                if (audioUrl.isNotEmpty)
                                  AudioMessagePlayer(
                                    url: audioUrl,
                                    durationSeconds: duracion,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Escribe un comentario o sugerencia',
                            filled: true,
                            fillColor: Colors.white.withOpacity(.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AudioNoteButton(
                        onAudioReady: (wav, duracion) async {
                          await _social.comentarAudio(
                            publicacionId: publicacionId,
                            autorPublicacionId: autorPublicacionId,
                            autorComentario: widget.usuario,
                            wav: wav,
                            duracionSegundos: duracion,
                          );
                        },
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: _acento, foregroundColor: Colors.black),
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
                          } catch (_) {
                            if (!modalContext.mounted) return;
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo enviar el comentario. Intenta de nuevo.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
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

  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Comienza la conversación',
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            'Publica el primer avance, fotografía o comunicado del equipo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _errorCarga(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 56),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _fecha(Map<String, dynamic> data) {
    final value = data['fecha'];
    return value is Timestamp ? value.toDate() : DateTime.now();
  }
}
