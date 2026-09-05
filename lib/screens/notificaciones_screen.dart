import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notificacion_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import 'mensajes_equipo_screen.dart';

class NotificacionesScreen extends StatelessWidget {
  final UserModel usuario;
  const NotificacionesScreen({super.key, required this.usuario});
  static const _fondo = Color(0xFF000000);
  static const _tarjeta = Color(0xFF171717);
  static const _acento = Color(0xFFB7FF2A);
  static const _urgente = Color(0xFFFF334F);

  Future<void> _openNotice(BuildContext context, NotificacionesService service, NotificacionApp aviso) async {
    try {
      if (aviso.tipo == 'aviso_personal' || aviso.tipo == 'mensaje_privado') {
        final db = FirebaseFirestore.instance;
        final notice = await db.collection('notificaciones').doc(aviso.id).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15));
        final data = notice.data();
        final cid = data?['conversacionId'];
        if (data?['destinatarioId'] != usuario.id || cid is! String || cid.isEmpty || cid.contains('/')) throw StateError('Aviso no disponible.');
        // Firestore verifies membership. A role or contact supplied in a URL is not authorization.
        final conversation = await db.collection('conversaciones').doc(cid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15));
        final rawMembers = conversation.data()?['participantes'];
        final members = rawMembers is List ? rawMembers.whereType<String>().toList() : <String>[];
        if (members.length != 2 || !members.contains(usuario.id)) throw StateError('Conversación no disponible.');
        final other = members.firstWhere((id) => id != usuario.id);
        final profile = await db.collection('usuarios').doc(other).get();
        if (!profile.exists || !context.mounted) return;
        try { await service.marcarLeida(aviso.id, usuario.id); } catch (_) {}
        if (context.mounted) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConversacionPrivadaScreen(usuario: usuario, contacto: UserModel.fromFirestore(profile))));
        return;
      }
      if (!aviso.leidaPor(usuario.id)) await service.marcarLeida(aviso.id, usuario.id);
      if (aviso.tipo == 'alarma_admin' && context.mounted) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MensajesEquipoScreen(usuario: usuario)));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el aviso. Revisa la conexión o entra en Chats para consultar tus conversaciones.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificacionesService();
    final admin = usuario.rol == AppRoles.admin;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text('AVISOS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
        actions: [
          if (admin) IconButton(tooltip: 'LLAMAR A TODO EL EQUIPO', onPressed: () => _confirmarLlamadaGeneral(context, service), icon: const Icon(Icons.campaign_rounded, color: _urgente, size: 28)),
          TextButton(onPressed: () async {
            try { await service.marcarTodasLeidas(usuarioId: usuario.id, rol: usuario.rol); }
            catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron marcar todos los avisos. Revisa Internet e intenta de nuevo.'))); }
          }, child: const Text('Leídas')),
        ],
      ),
      body: Column(children: [
        if (admin) _botonEmergencia(context, service),
        Expanded(child: StreamBuilder<List<NotificacionApp>>(
          stream: service.avisosPara(usuarioId: usuario.id, rol: usuario.rol),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return const _EstadoError();
            final avisos = snapshot.data ?? const <NotificacionApp>[];
            if (avisos.isEmpty) return _EstadoVacio(nombre: usuario.nombre);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100), itemCount: avisos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final aviso = avisos[index]; final leida = aviso.leidaPor(usuario.id);
                return InkWell(onTap: () => _openNotice(context, service, aviso), borderRadius: BorderRadius.circular(20), child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: _tarjeta, borderRadius: BorderRadius.circular(20), border: Border.all(color: leida ? Colors.white10 : _color(aviso.tipo).withOpacity(.7))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 46, height: 46, decoration: BoxDecoration(color: _color(aviso.tipo).withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(_icono(aviso.tipo), color: _color(aviso.tipo))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(aviso.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white))), if (!leida) CircleAvatar(radius: 5, backgroundColor: _color(aviso.tipo))]),
                      const SizedBox(height: 5), Text(aviso.mensaje, style: GoogleFonts.inter(color: Colors.white70, height: 1.35)),
                      const SizedBox(height: 9), Text(DateFormat('dd MMM yyyy · HH:mm', 'es').format(aviso.fecha), style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                    ])),
                  ]),
                ));
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _botonEmergencia(BuildContext context, NotificacionesService service) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
    child: Material(color: const Color(0xFF24080E), borderRadius: BorderRadius.circular(22), child: InkWell(
      borderRadius: BorderRadius.circular(22), onTap: () => _confirmarLlamadaGeneral(context, service),
      child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: _urgente.withOpacity(.65))), child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: _urgente.withOpacity(.15), shape: BoxShape.circle), child: const Icon(Icons.notifications_active_rounded, color: _urgente, size: 28)),
        const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LLAMAR A TODO EL EQUIPO', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 4), Text('Alerta importante para todo el equipo.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5)),
        ])), const Icon(Icons.chevron_right_rounded, color: _urgente),
      ])),
    )),
  );

  Future<void> _confirmarLlamadaGeneral(BuildContext context, NotificacionesService service) async {
    final motivo = TextEditingController(text: 'Atención inmediata: Administración está llamando a todo el equipo.');
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF151113),
      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: _urgente), SizedBox(width: 9), Expanded(child: Text('Llamada general'))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Se enviará una alerta a TODO el equipo. Úsala únicamente cuando necesites su atención inmediata.'),
        const SizedBox(height: 14), TextField(controller: motivo, maxLength: 220, maxLines: 3, decoration: const InputDecoration(labelText: 'Motivo de la llamada')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: _urgente, foregroundColor: Colors.white), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('LLAMAR A TODOS'))],
    ));
    if (confirmed != true || !context.mounted) return;
    try {
      await service.llamarATodoElEquipo(mensaje: motivo.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 Llamada general registrada en el sistema de notificaciones.'), backgroundColor: Color(0xFF7A1027)));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo registrar la llamada general. Revisa tu sesión y conexión.'), backgroundColor: Colors.redAccent));
    } finally { motivo.dispose(); }
  }
  static IconData _icono(String tipo) => switch (tipo) {
    'alarma_admin' => Icons.notifications_active_rounded,
    'aviso_personal' || 'mensaje_privado' => Icons.mark_chat_unread_outlined,
    'tarea' => Icons.assignment_turned_in_outlined,
    'almacen' => Icons.inventory_2_outlined,
    'blog' => Icons.auto_awesome_mosaic_outlined,
    'reconocimiento' => Icons.workspace_premium_outlined,
    'social' || 'proyecto_chat' => Icons.forum_outlined,
    _ => Icons.notifications_none_rounded,
  };
  static Color _color(String tipo) => switch (tipo) {
    'alarma_admin' => _urgente,
    'tarea' => const Color(0xFFB7FF2A),
    'almacen' => const Color(0xFFFF9800),
    'blog' => const Color(0xFFC13CFF),
    'reconocimiento' => const Color(0xFFFFDE21),
    'social' => const Color(0xFFB82B55),
    'proyecto_chat' => const Color(0xFFC6FF68),
    _ => _acento,
  };
}
class _EstadoError extends StatelessWidget {
  const _EstadoError();
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.notifications_paused_rounded, size: 68, color: Colors.orangeAccent), const SizedBox(height: 16),
    Text('No pudimos cargar los avisos', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)), const SizedBox(height: 8),
    Text('Comprueba tu conexión. La pantalla se actualizará automáticamente cuando vuelva el servicio.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white54, height: 1.4)),
  ])));
}
class _EstadoVacio extends StatelessWidget {
  final String nombre;
  const _EstadoVacio({required this.nombre});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.notifications_none_rounded, size: 70, color: Colors.white24), const SizedBox(height: 18),
    Text('Todo al día, $nombre', textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
    Text('Aquí aparecerán nuevas tareas, solicitudes de almacén y comunicados.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white54, height: 1.4)),
  ])));
}
