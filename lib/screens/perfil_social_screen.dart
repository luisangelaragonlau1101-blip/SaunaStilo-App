import '../widgets/inline_photo.dart';
import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'configuracion_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import '../services/social_service.dart';
import '../widgets/team_profile_details.dart';
import '../widgets/profile_networks.dart';
import '../widgets/stilo_orbit.dart';

class PerfilSocialScreen extends StatelessWidget {
  final UserModel usuarioActual;
  final String perfilId;

  PerfilSocialScreen({
    super.key,
    required this.usuarioActual,
    required this.perfilId,
  });

  bool get _esPropio => usuarioActual.id == perfilId;

  @override
  Widget build(BuildContext context) {
    if (_esPropio) return ConfiguracionScreen(usuario: usuarioActual);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(perfilId).snapshots(),
      builder: (context, perfilSnapshot) {
        if (perfilSnapshot.hasError) return Scaffold(body: Center(child: Text('No se pudo cargar el perfil. Revisa conexión y permisos.')));
        if (perfilSnapshot.hasData && !perfilSnapshot.data!.exists) return Scaffold(body: Center(child: Text('Este perfil ya no está disponible.')));
        final data = perfilSnapshot.data?.data();
        if (data == null) {
          return Scaffold(
            backgroundColor: StiloColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final nombre = data['nombre']?.toString() ?? 'Usuario';
        final rol = data['rol']?.toString() ?? AppRoles.trabajador;
        final foto = data['fotoUrl']?.toString() ?? '';
        final cumpleanos = data['cumpleanos'] is Timestamp
            ? (data['cumpleanos'] as Timestamp).toDate()
            : null;
        final puedeVerOperacion =
            usuarioActual.rol == AppRoles.admin || _esPropio;
        final actividadesQuery = puedeVerOperacion
            ? FirebaseFirestore.instance
                  .collection('actividades')
                  .where('asignadoATrabajadorId', isEqualTo: perfilId)
            : null;
        return Scaffold(
          backgroundColor: StiloColors.background,
          appBar: AppBar(
            backgroundColor: StiloColors.background,
            title: Text('PERFIL', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: actividadesQuery?.snapshots(),
            builder: (context, actividadesSnapshot) {
              final actividades = actividadesSnapshot.data?.docs
                      .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
                      .toList(growable: false) ??
                  <ActividadModel>[];
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
                    perfil: data,
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
    required Map<String, dynamic> perfil,
    required String nombre,
    required String rol,
    required String foto,
    required DateTime? cumpleanos,
    required List<ActividadModel> actividades,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
  }) {
    final puedeVerOperacion =
        usuarioActual.rol == AppRoles.admin || _esPropio;
    final proyectosQuery = puedeVerOperacion
        ? FirebaseFirestore.instance
              .collection('proyectos')
              .where('encargados', arrayContains: perfilId)
        : null;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: proyectosQuery?.snapshots(),
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
          stream: puedeVerOperacion
              ? FirebaseFirestore.instance
                    .collection('salidas_instalacion')
                    .where('usuarioId', isEqualTo: perfilId)
                    .snapshots()
              : Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
          builder: (context, salidasSnapshot) {
            final salidas = salidasSnapshot.data?.docs.toList(growable: true) ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            salidas.sort((a, b) {
              final fechaA = a.data()['fecha'];
              final fechaB = b.data()['fecha'];
              final aDate = fechaA is Timestamp
                  ? fechaA.toDate()
                  : DateTime(2000);
              final bDate = fechaB is Timestamp
                  ? fechaB.toDate()
                  : DateTime(2000);
              return bDate.compareTo(aDate);
            });
            final totalInstalaciones =
                salidas.isNotEmpty ? salidas.length : proyectos.length;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usuarioActual.rol == AppRoles.admin
                  ? FirebaseFirestore.instance.collection('clientes').snapshots()
                  : Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
              builder: (context, clientesSnapshot) {
                final clientes = <String, Map<String, dynamic>>{
                  for (final doc in clientesSnapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    doc.id: doc.data(),
                };
                return ListView(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 100),
                  children: [
                    _cabecera(context, nombre, rol, foto, cumpleanos),
                    TeamProfileDetails(usuarioActual: usuarioActual, perfilId: perfilId, data: perfil),
                    ProfileNetworks(profileId: perfilId, editable: _esPropio, data: perfil['redesSociales']),
                    SizedBox(height: 14),
                    _metricas(actividades, posts.length, totalInstalaciones),
                    SizedBox(height: 20),
                    _insignias(actividades, totalInstalaciones),
                    SizedBox(height: 22),
                    _instalaciones(
                      proyectos,
                      salidas,
                      clientes,
                      actividades,
                    ),
                    SizedBox(height: 20),
                    _sugerencias(context, nombre),
                    SizedBox(height: 22),
                    Text(
                      'AVANCES PUBLICADOS',
                      style: GoogleFonts.inter(
                        color: StiloColors.text.withValues(alpha: .54),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 10),
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
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: rol == AppRoles.admin
              ? [StiloColors.surface, Color(0xFF6D28D9)]
              : [StiloColors.surface, StiloColors.border],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: StiloColors.text.withValues(alpha: .12),
            backgroundImage: foto.isNotEmpty ? stiloImageProvider(foto) : null,
            child: foto.isEmpty
                ? Text(
                    nombre.isEmpty ? 'U' : nombre[0].toUpperCase(),
                    style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          SizedBox(height: 12),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: StiloColors.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            rol == AppRoles.admin ? 'ADMINISTRACIÓN SAUNA STILO' : rol.toUpperCase(),
            style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .60), fontSize: 11),
          ),
          if (cumpleanos != null) ...[
            SizedBox(height: 6),
            Text(
              '🎂 ${DateFormat('d MMMM', 'es').format(cumpleanos)}',
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 11),
            ),
          ],
          if (!_esPropio) ...[
            SizedBox(height: 15),
            StreamBuilder<bool>(
              stream: social.siguiendo(seguidorId: usuarioActual.id, seguidoId: perfilId),
              builder: (context, snapshot) {
                final siguiendo = snapshot.data ?? false;
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: siguiendo ? StiloColors.text.withValues(alpha: .12) : StiloColors.text,
                    foregroundColor: siguiendo ? StiloColors.text : StiloColors.background,
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
      physics: NeverScrollableScrollPhysics(),
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
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 5),
        decoration: BoxDecoration(
          color: StiloColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StiloColors.text.withValues(alpha: .10)),
        ),
        child: Column(
          children: [
            Text('$valor', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 8, fontWeight: FontWeight.w800),
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
      logros.add(('Primera misión', Icons.flag_rounded, Color(0xFF00E676)));
    }
    if (completadas.length >= 5) {
      logros.add(('Cumplidor', Icons.task_alt_rounded, Color(0xFFFF729C)));
    }
    if (evidencias >= 10) {
      logros.add(('Evidencia impecable', Icons.verified_rounded, StiloColors.accent));
    }
    if (puntuales >= 5) {
      logros.add(('Siempre a tiempo', Icons.timer_rounded, Color(0xFFFF9800)));
    }
    if (instalaciones >= 1) {
      logros.add(('Instalador en campo', Icons.location_on_rounded, Color(0xFF70E1D0)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOGROS E INSIGNIAS',
          style: GoogleFonts.inter(
            color: StiloColors.text.withValues(alpha: .54),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 10),
        if (logros.isEmpty)
          _vacio('Completa tareas con evidencia para desbloquear insignias.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: logros.map((logro) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: logro.$3.withOpacity(.13),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: logro.$3.withOpacity(.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StiloOrbitIcon(icon: logro.$2, color: logro.$3, size: 34, active: true),
                    SizedBox(width: 6),
                    Text(
                      logro.$1,
                      style: GoogleFonts.inter(
                        color: StiloColors.text,
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> salidas,
    Map<String, Map<String, dynamic>> clientes,
    List<ActividadModel> actividades,
  ) {
    final usaRegistrosNuevos = salidas.isNotEmpty;
    final registros = usaRegistrosNuevos ? salidas : proyectos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LUGARES E INSTALACIONES',
          style: GoogleFonts.inter(
            color: StiloColors.text.withValues(alpha: .54),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 10),
        if (registros.isEmpty)
          _vacio('Todavía no hay instalaciones registradas en este perfil.')
        else
          ...registros.take(8).map((doc) {
            final data = doc.data();
            final proyectoId = usaRegistrosNuevos
                ? data['proyectoId']?.toString() ?? ''
                : doc.id;
            final cliente = clientes[data['id_cliente']?.toString()] ??
                <String, dynamic>{};
            final fechaRaw = usaRegistrosNuevos
                ? data['fecha']
                : data['fecha_salida_instalacion'];
            final fecha = fechaRaw is Timestamp
                ? DateFormat('d MMM yyyy · HH:mm', 'es')
                    .format(fechaRaw.toDate())
                : 'Fecha por confirmar';
            final direccion = cliente['direccion']?.toString().trim() ?? '';
            var evidenciaUrl = '';
            for (final actividad in actividades) {
              if (actividad.proyectoId == proyectoId &&
                  actividad.evidenciaFotos.isNotEmpty) {
                evidenciaUrl = actividad.evidenciaFotos.first;
                break;
              }
            }
            return Container(
              margin: EdgeInsets.only(bottom: 9),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StiloColors.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Color(0xFF70E1D0).withOpacity(.18)),
              ),
              child: Row(
                children: [
                  if (evidenciaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        evidenciaUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          backgroundColor: Color(0x1F70E1D0),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF70E1D0),
                          ),
                        ),
                      ),
                    )
                  else
                    CircleAvatar(
                      backgroundColor: Color(0x1F70E1D0),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF70E1D0),
                      ),
                    ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usaRegistrosNuevos
                              ? data['proyectoTitulo']?.toString() ??
                                  'Instalación Sauna Stilo'
                              : data['titulo']?.toString() ??
                                  'Instalación Sauna Stilo',
                          style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          usaRegistrosNuevos
                              ? data['ubicacionRegistrada'] == true
                                  ? 'Salida confirmada con ubicación'
                                  : 'Salida confirmada'
                              : direccion.isEmpty
                              ? 'Ubicación interna del proyecto'
                              : direccion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 11),
                        ),
                        Text(fecha, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .30), fontSize: 10)),
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
                color: StiloColors.text.withValues(alpha: .54),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            Spacer(),
            if (!_esPropio)
              IconButton(
                onPressed: () => _escribirSugerencia(context, ref, nombrePerfil),
                icon: Icon(Icons.add_comment_rounded, color: Color(0xFF00E5FF)),
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
                  leading: CircleAvatar(
                    backgroundColor: StiloColors.text.withValues(alpha: .10),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: StiloColors.text.withValues(alpha: .54), size: 18),
                  ),
                  title: Text(
                    data['autorNombre']?.toString() ?? 'Compañero',
                    style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    data['texto']?.toString() ?? '',
                    style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), height: 1.35),
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
        backgroundColor: StiloColors.surface,
        title: Text('Sugerencia para $nombrePerfil'),
        content: TextField(contextMenuBuilder: privacyTextMenu,
          controller: controller,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: 'Escribe una sugerencia respetuosa y útil'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
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
            child: Text('Enviar'),
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
        : <String>[];
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StiloColors.surface,
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
                errorBuilder: (_, __, ___) => SizedBox(width: 62, height: 62),
              ),
            ),
          if (imagenes.isNotEmpty) SizedBox(width: 12),
          Expanded(
            child: Text(
              data['texto']?.toString().isNotEmpty == true
                  ? data['texto'].toString()
                  : 'Avance fotográfico',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio(String texto) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StiloColors.text.withOpacity(.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(texto, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38))),
    );
  }
}
