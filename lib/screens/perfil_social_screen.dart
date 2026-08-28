import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import '../services/social_service.dart';

class PerfilSocialScreen extends StatelessWidget {
  final UserModel usuarioActual;
  final String perfilId;

  const PerfilSocialScreen({
    super.key,
    required this.usuarioActual,
    required this.perfilId,
  });

  bool get _esPropio => usuarioActual.id == perfilId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(perfilId).snapshots(),
      builder: (context, perfilSnapshot) {
        final data = perfilSnapshot.data?.data();
        if (data == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final nombre = data['nombre']?.toString() ?? 'Usuario';
        final rol = data['rol']?.toString() ?? AppRoles.trabajador;
        final foto = data['fotoUrl']?.toString() ?? '';
        final cumpleanos = data['cumpleanos'] is Timestamp
            ? (data['cumpleanos'] as Timestamp).toDate()
            : null;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('PERFIL', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('actividades').snapshots(),
            builder: (context, actividadesSnapshot) {
              final actividades = actividadesSnapshot.data?.docs
                      .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
                      .where((actividad) => actividad.asignadoATrabajadorId == perfilId)
                      .toList(growable: false) ??
                  const <ActividadModel>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('publicaciones_sociales').snapshots(),
                builder: (context, publicacionesSnapshot) {
                  final posts = publicacionesSnapshot.data?.docs
                          .where((doc) => doc.data()['autorId'] == perfilId)
                          .toList(growable: true) ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  posts.sort((a, b) {
                    final af = a.data()['fecha'];
                    final bf = b.data()['fecha'];
                    final ad = af is Timestamp ? af.toDate() : DateTime(2000);
                    final bd = bf is Timestamp ? bf.toDate() : DateTime(2000);
                    return bd.compareTo(ad);
                  });
                  return _contenidoPerfil(
                    context: context,
                    nombre: nombre,
                    rol: rol,
                    foto: foto,
                    cumpleanos: cumpleanos,
                    actividades: actividades,
                    posts: posts,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _contenidoPerfil({
    required BuildContext context,
    required String nombre,
    required String rol,
    required String foto,
    required DateTime? cumpleanos,
    required List<ActividadModel> actividades,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('proyectos').snapshots(),
      builder: (context, proyectosSnapshot) {
        final proyectos = proyectosSnapshot.data?.docs.where((doc) {
              final data = doc.data();
              final encargados = data['encargados'] is Iterable
                  ? (data['encargados'] as Iterable)
                      .map((item) => item.toString())
                      .toList(growable: false)
                  : <String>[];
              return encargados.contains(perfilId) &&
                  (data['fecha_salida_instalacion'] != null ||
                      data['estatus']?.toString() == 'finalizado');
            }).toList(growable: false) ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
          builder: (context, clientesSnapshot) {
            final clientes = <String, Map<String, dynamic>>{
              for (final doc in clientesSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                doc.id: doc.data(),
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
              children: [
                _cabecera(context, nombre, rol, foto, cumpleanos),
                const SizedBox(height: 14),
                _metricas(actividades, posts.length, proyectos.length),
                const SizedBox(height: 20),
                _insignias(actividades, proyectos.length),
                const SizedBox(height: 22),
                _instalaciones(proyectos, clientes),
                const SizedBox(height: 20),
                _sugerencias(context, nombre),
                const SizedBox(height: 22),
                Text(
                  'AVANCES PUBLICADOS',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                if (posts.isEmpty)
                  _vacio('Aún no ha publicado avances.')
                else
                  ...posts.map(_postResumen),
              ],
            );
          },
        );
      },
    );
  }

  Widget _cabecera(
    BuildContext context,
    String nombre,
    String rol,
    String foto,
    DateTime? cumpleanos,
  ) {
    final social = SocialService();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: rol == AppRoles.admin
              ? const [Color(0xFF242424), Color(0xFF6D28D9)]
              : const [Color(0xFF111827), Color(0xFF0F766E)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white12,
            backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
            child: foto.isEmpty
                ? Text(
                    nombre.isEmpty ? 'U' : nombre[0].toUpperCase(),
                    style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            rol == AppRoles.admin ? 'ADMINISTRACIÓN SAUNA STILO' : rol.toUpperCase(),
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
          ),
          if (cumpleanos != null) ...[
            const SizedBox(height: 6),
            Text(
              '🎂 ${DateFormat('d MMMM', 'es').format(cumpleanos)}',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
            ),
          ],
          if (!_esPropio) ...[
            const SizedBox(height: 15),
            StreamBuilder<bool>(
              stream: social.siguiendo(seguidorId: usuarioActual.id, seguidoId: perfilId),
              builder: (context, snapshot) {
                final siguiendo = snapshot.data ?? false;
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: siguiendo ? Colors.white12 : Colors.white,
                    foregroundColor: siguiendo ? Colors.white : Colors.black,
                  ),
                  onPressed: () => social.alternarSeguimiento(
                    seguidor: usuarioActual,
                    seguidoId: perfilId,
                    seguidoNombre: nombre,
                    siguiendo: siguiendo,
                  ),
                  icon: Icon(siguiendo ? Icons.person_remove_rounded : Icons.person_add_rounded),
                  label: Text(siguiendo ? 'SIGUIENDO' : 'SEGUIR'),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricas(
    List<ActividadModel> actividades,
    int publicaciones,
    int instalaciones,
  ) {
    final completadas = actividades.where((a) => a.estatus == 'completado').length;
    final evidencias = actividades.fold<int>(0, (total, a) => total + a.totalEvidencias);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.35,
      children: [
        _metrica('TERMINADAS', completadas),
        _metrica('EVIDENCIAS', evidencias),
        _metrica('INSTALACIONES', instalaciones),
        _metrica('PUBLICACIONES', publicaciones),
      ],
    );
  }

  Widget _metrica(String titulo, int valor) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text('$valor', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ],
        ),
    );
  }

  Widget _insignias(List<ActividadModel> actividades, int instalaciones) {
    final completadas = actividades.where((item) => item.estatus == 'completado').toList();
    final evidencias = actividades.fold<int>(0, (total, item) => total + item.totalEvidencias);
    final puntuales = completadas.where((item) {
      return item.completadoEn != null &&
          !item.completadoEn!.isAfter(item.fechaTermino);
    }).length;
    final logros = <(String, IconData, Color)>[];
    if (completadas.isNotEmpty) {
      logros.add(('Primera misión', Icons.flag_rounded, const Color(0xFF00E676)));
    }
    if (completadas.length >= 5) {
      logros.add(('Cumplidor', Icons.task_alt_rounded, const Color(0xFF00B0FF)));
    }
    if (evidencias >= 10) {
      logros.add(('Evidencia impecable', Icons.verified_rounded, const Color(0xFF8B5CF6)));
    }
    if (puntuales >= 5) {
      logros.add(('Siempre a tiempo', Icons.timer_rounded, const Color(0xFFFF9800)));
    }
    if (instalaciones >= 1) {
      logros.add(('Instalador en campo', Icons.location_on_rounded, const Color(0xFF70E1D0)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOGROS E INSIGNIAS',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        if (logros.isEmpty)
          _vacio('Completa tareas con evidencia para desbloquear insignias.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: logros.map((logro) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: logro.$3.withOpacity(.13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: logro.$3.withOpacity(.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(logro.$2, color: logro.$3, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      logro.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
      ],
    );
  }

  Widget _instalaciones(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> proyectos,
    Map<String, Map<String, dynamic>> clientes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LUGARES E INSTALACIONES',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        if (proyectos.isEmpty)
          _vacio('Todavía no hay instalaciones registradas en este perfil.')
        else
          ...proyectos.take(8).map((doc) {
            final data = doc.data();
            final cliente = clientes[data['id_cliente']?.toString()] ?? const <String, dynamic>{};
            final fechaRaw = data['fecha_salida_instalacion'];
            final fecha = fechaRaw is Timestamp
                ? DateFormat('d MMM yyyy', 'es').format(fechaRaw.toDate())
                : 'Fecha por confirmar';
            final direccion = cliente['direccion']?.toString().trim() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF70E1D0).withOpacity(.18)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0x1F70E1D0),
                    child: Icon(Icons.location_on_rounded, color: Color(0xFF70E1D0)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['titulo']?.toString() ?? 'Instalación Sauna Stilo',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          direccion.isEmpty ? 'Ubicación interna del proyecto' : direccion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                        ),
                        Text(fecha, style: GoogleFonts.inter(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _sugerencias(BuildContext context, String nombrePerfil) {
    final ref = FirebaseFirestore.instance.collection('usuarios').doc(perfilId).collection('sugerencias');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SUGERENCIAS EN EL PERFIL',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            if (!_esPropio)
              IconButton(
                onPressed: () => _escribirSugerencia(context, ref, nombrePerfil),
                icon: const Icon(Icons.add_comment_rounded, color: Color(0xFF00E5FF)),
              ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snapshot) {
            final sugerencias = snapshot.data?.docs.toList(growable: true) ?? [];
            sugerencias.sort((a, b) {
              final af = a.data()['fecha'];
              final bf = b.data()['fecha'];
              return (bf is Timestamp ? bf.toDate() : DateTime(2000))
                  .compareTo(af is Timestamp ? af.toDate() : DateTime(2000));
            });
            if (sugerencias.isEmpty) return _vacio('Todavía no hay sugerencias.');
            return Column(
              children: sugerencias.take(3).map((doc) {
                final data = doc.data();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 18),
                  ),
                  title: Text(
                    data['autorNombre']?.toString() ?? 'Compañero',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    data['texto']?.toString() ?? '',
                    style: GoogleFonts.inter(color: Colors.white54, height: 1.35),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _escribirSugerencia(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> ref,
    String nombrePerfil,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: Text('Sugerencia para $nombrePerfil'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Escribe una sugerencia respetuosa y útil'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final texto = controller.text.trim();
              if (texto.isEmpty) return;
              final db = FirebaseFirestore.instance;
              final sugerenciaRef = ref.doc();
              final avisoRef = db.collection('notificaciones').doc();
              final batch = db.batch();
              batch.set(sugerenciaRef, {
                'autorId': usuarioActual.id,
                'autorNombre': usuarioActual.nombre,
                'texto': texto,
                'fecha': FieldValue.serverTimestamp(),
              });
              batch.set(
                avisoRef,
                NotificacionesService.datosAviso(
                  titulo: 'Nueva sugerencia en tu perfil',
                  mensaje: '${usuarioActual.nombre}: $texto',
                  tipo: 'social',
                  destinatarioId: perfilId,
                ),
              );
              await batch.commit();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Widget _postResumen(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final imagenes = data['imagenes'] is Iterable
        ? (data['imagenes'] as Iterable).map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          if (imagenes.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imagenes.first,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 62, height: 62),
              ),
            ),
          if (imagenes.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Text(
              data['texto']?.toString().isNotEmpty == true
                  ? data['texto'].toString()
                  : 'Avance fotográfico',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(texto, style: GoogleFonts.inter(color: Colors.white38)),
    );
  }
}
