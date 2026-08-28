import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../services/notificaciones_service.dart';

class BlogInternoScreen extends StatelessWidget {
  final UserModel usuario;

  const BlogInternoScreen({super.key, required this.usuario});

  static const _fondo = Color(0xFF050505);
  static const _tarjeta = Color(0xFF171717);
  static const _acento = Color(0xFF8B5CF6);

  bool get _esAdmin => usuario.rol == AppRoles.admin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BLOG SAUNA STILO',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
            ),
            Text(
              'Noticias y avances mes a mes',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              backgroundColor: _acento,
              foregroundColor: Colors.white,
              onPressed: () => _crearPublicacion(context),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('PUBLICAR'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('blog_publicaciones')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _acento));
          }
          final publicaciones = snapshot.data?.docs
                  .map(_Publicacion.fromDocument)
                  .where((publicacion) => _esAdmin || publicacion.publicada)
                  .toList(growable: true) ??
              <_Publicacion>[];
          publicaciones.sort((a, b) => b.mes.compareTo(a.mes));
          if (publicaciones.isEmpty) return _estadoVacio();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
            itemCount: publicaciones.length,
            itemBuilder: (context, index) {
              final publicacion = publicaciones[index];
              final mostrarMes = index == 0 ||
                  !_mismoMes(publicaciones[index - 1].mes, publicacion.mes);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mostrarMes) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(3, 18, 3, 10),
                      child: Text(
                        DateFormat('MMMM yyyy', 'es')
                            .format(publicacion.mes)
                            .toUpperCase(),
                        style: GoogleFonts.inter(
                          color: _acento,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                  _tarjetaPublicacion(context, publicacion),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _tarjetaPublicacion(BuildContext context, _Publicacion publicacion) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _tarjeta,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _abrirPublicacion(context, publicacion),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _acento.withOpacity(.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      publicacion.categoria.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC4B5FD),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!publicacion.publicada)
                    Text(
                      'BORRADOR',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                publicacion.titulo,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                publicacion.resumen,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white60, height: 1.45),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      publicacion.autor,
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: _acento, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 72, color: Colors.white24),
            const SizedBox(height: 18),
            Text(
              'Aún no hay publicaciones',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _esAdmin
                  ? 'Publica el primer comunicado o resumen del mes.'
                  : 'Aquí aparecerán noticias, avances y comunicados de la empresa.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirPublicacion(BuildContext context, _Publicacion publicacion) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 50),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              publicacion.categoria.toUpperCase(),
              style: GoogleFonts.inter(
                color: _acento,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              publicacion.titulo,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '${DateFormat('MMMM yyyy', 'es').format(publicacion.mes)} · ${publicacion.autor}',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
            const SizedBox(height: 24),
            Text(
              publicacion.contenido,
              style: GoogleFonts.inter(color: Colors.white70, height: 1.65, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearPublicacion(BuildContext context) async {
    final titulo = TextEditingController();
    final resumen = TextEditingController();
    final contenido = TextEditingController();
    final categoria = TextEditingController(text: 'Actualización mensual');
    DateTime mes = DateTime(DateTime.now().year, DateTime.now().month);
    bool guardando = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUEVA PUBLICACIÓN',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                _campo(titulo, 'Título'),
                const SizedBox(height: 12),
                _campo(categoria, 'Categoría'),
                const SizedBox(height: 12),
                _campo(resumen, 'Resumen corto', maxLines: 2),
                const SizedBox(height: 12),
                _campo(contenido, 'Contenido completo', maxLines: 7),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white.withOpacity(.04),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text('Mes de publicación', style: GoogleFonts.inter(color: Colors.white54)),
                  subtitle: Text(
                    DateFormat('MMMM yyyy', 'es').format(mes),
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  trailing: const Icon(Icons.calendar_month_rounded, color: _acento),
                  onTap: () async {
                    final elegido = await showDatePicker(
                      context: context,
                      initialDate: mes,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2036, 12, 31),
                    );
                    if (elegido != null) {
                      setModalState(() => mes = DateTime(elegido.year, elegido.month));
                    }
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _acento),
                    onPressed: guardando
                        ? null
                        : () async {
                            final tituloLimpio = titulo.text.trim();
                            final contenidoLimpio = contenido.text.trim();
                            if (tituloLimpio.isEmpty || contenidoLimpio.isEmpty) {
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(content: Text('Escribe el título y el contenido.')),
                              );
                              return;
                            }
                            setModalState(() => guardando = true);
                            try {
                              final db = FirebaseFirestore.instance;
                              final publicacionRef = db.collection('blog_publicaciones').doc();
                              final avisoRef = db.collection('notificaciones').doc();
                              final batch = db.batch();
                              batch.set(publicacionRef, {
                                'titulo': tituloLimpio,
                                'resumen': resumen.text.trim().isEmpty
                                    ? contenidoLimpio
                                    : resumen.text.trim(),
                                'contenido': contenidoLimpio,
                                'categoria': categoria.text.trim().isEmpty
                                    ? 'Actualización mensual'
                                    : categoria.text.trim(),
                                'mes': Timestamp.fromDate(mes),
                                'autorId': usuario.id,
                                'autorNombre': usuario.nombre,
                                'publicada': true,
                                'fechaPublicacion': FieldValue.serverTimestamp(),
                              });
                              batch.set(
                                avisoRef,
                                NotificacionesService.datosAviso(
                                  titulo: 'Nueva publicación',
                                  mensaje: tituloLimpio,
                                  tipo: 'blog',
                                  rolesDestinatarios: const ['todos'],
                                ),
                              );
                              await batch.commit();
                              if (modalContext.mounted) Navigator.pop(modalContext);
                            } catch (error) {
                              setModalState(() => guardando = false);
                              if (modalContext.mounted) {
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(content: Text('No se pudo publicar: $error')),
                                );
                              }
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_rounded),
                    label: const Text('PUBLICAR Y NOTIFICAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titulo.dispose();
    resumen.dispose();
    contenido.dispose();
    categoria.dispose();
  }

  Widget _campo(
    TextEditingController controller,
    String etiqueta, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }

  static bool _mismoMes(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}

class _Publicacion {
  final String id;
  final String titulo;
  final String resumen;
  final String contenido;
  final String categoria;
  final String autor;
  final DateTime mes;
  final bool publicada;

  const _Publicacion({
    required this.id,
    required this.titulo,
    required this.resumen,
    required this.contenido,
    required this.categoria,
    required this.autor,
    required this.mes,
    required this.publicada,
  });

  factory _Publicacion.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final mesRaw = data['mes'];
    final contenido = data['contenido']?.toString() ?? '';
    return _Publicacion(
      id: doc.id,
      titulo: data['titulo']?.toString() ?? 'Sin título',
      resumen: data['resumen']?.toString() ?? contenido,
      contenido: contenido,
      categoria: data['categoria']?.toString() ?? 'Comunicado',
      autor: data['autorNombre']?.toString() ?? 'Sauna Stilo',
      mes: mesRaw is Timestamp ? mesRaw.toDate() : DateTime.now(),
      publicada: data['publicada'] is bool ? data['publicada'] as bool : true,
    );
  }
}
