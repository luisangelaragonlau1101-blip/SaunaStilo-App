import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/notificacion_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import '../services/notification_router.dart';
import 'mensajes_equipo_screen.dart';

class NotificacionesScreen extends StatelessWidget {
  final UserModel usuario;
  const NotificacionesScreen({super.key, required this.usuario});

  static Color get _fondo => StiloColors.background;
  static Color get _tarjeta => StiloColors.surface;
  static Color get _acento => StiloColors.accent;
  static final _urgente = Color(0xFFFF334F);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final service = NotificacionesService();
    final admin = usuario.rol == AppRoles.admin;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text('AVISOS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'LLAMAR A TODO EL EQUIPO',
              onPressed: () => _confirmarLlamadaGeneral(context, service),
              icon: Icon(Icons.campaign_rounded, color: _urgente, size: 28),
            ),
          TextButton(
            onPressed: () => service.marcarTodasLeidas(usuarioId: usuario.id, rol: usuario.rol),
            child: Text('Leídas'),
          ),
        ],
      ),
      body: Column(children: [
        if (admin) _botonEmergencia(context, service),
        Expanded(child: StreamBuilder<List<NotificacionApp>>(
          stream: service.avisosPara(usuarioId: usuario.id, rol: usuario.rol),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _EstadoError();
            final avisos = snapshot.data ?? <NotificacionApp>[];
            if (avisos.isEmpty) return _EstadoVacio(nombre: usuario.nombre);
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 100),
              itemCount: avisos.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final aviso = avisos[index];
                final leida = aviso.leidaPor(usuario.id);
                return InkWell(
                  onTap: () async {
                    if (!leida) await service.marcarLeida(aviso.id, usuario.id);
                    if (context.mounted) await NotificationRouter.open(context, usuario, aviso.id);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _tarjeta, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: leida ? StiloColors.text.withValues(alpha: .10) : _color(aviso.tipo).withOpacity(.7)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(color: _color(aviso.tipo).withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(_icono(aviso.tipo), color: _color(aviso.tipo))),
                      SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(aviso.titulo, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: StiloColors.text))),
                          if (!leida) CircleAvatar(radius: 5, backgroundColor: _color(aviso.tipo)),
                        ]),
                        SizedBox(height: 5),
                        Text(aviso.mensaje, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), height: 1.35)),
                        SizedBox(height: 9),
                        Text(DateFormat('dd MMM yyyy · HH:mm', 'es').format(aviso.fecha), style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 11)),
                      ])),
                    ]),
                  ),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _botonEmergencia(BuildContext context, NotificacionesService service) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Material(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _confirmarLlamadaGeneral(context, service),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: _urgente.withOpacity(.65))),
            child: Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: _urgente.withOpacity(.15), shape: BoxShape.circle), child: Icon(Icons.notifications_active_rounded, color: _urgente, size: 28)),
              SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LLAMAR A TODO EL EQUIPO', style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.w900, fontSize: 14)),
                SizedBox(height: 4),
                Text('Alerta crítica para todos los dispositivos registrados.', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 10.5)),
              ])),
              Icon(Icons.chevron_right_rounded, color: _urgente),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarLlamadaGeneral(BuildContext context, NotificacionesService service) async {
    final motivo = TextEditingController(text: 'Atención inmediata: Administración está llamando a todo el equipo.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: StiloColors.surface,
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: _urgente), SizedBox(width: 9), Expanded(child: Text('Llamada general'))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Se enviará una alerta crítica a TODO el equipo. Úsala únicamente cuando necesites su atención inmediata.'),
          SizedBox(height: 14),
          TextField(contextMenuBuilder: privacyTextMenu, controller: motivo, maxLength: 220, maxLines: 3, decoration: InputDecoration(labelText: 'Motivo de la llamada')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _urgente, foregroundColor: StiloColors.text),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('LLAMAR A TODOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.llamarATodoElEquipo(mensaje: motivo.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🚨 Llamada general enviada al sistema de notificaciones.'), backgroundColor: StiloColors.border));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar la llamada general: $error'), backgroundColor: Colors.redAccent));
    } finally {
      motivo.dispose();
    }
  }

  static IconData _icono(String tipo) {
    switch (tipo) {
      case 'alarma_admin': return Icons.notifications_active_rounded;
      case 'tarea': return Icons.assignment_turned_in_rounded;
      case 'almacen': return Icons.inventory_2_rounded;
      case 'blog': return Icons.campaign_rounded;
      case 'reconocimiento': return Icons.workspace_premium_rounded;
      case 'social': case 'proyecto_chat': return Icons.forum_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  static Color _color(String tipo) {
    switch (tipo) {
      case 'alarma_admin': return _urgente;
      case 'tarea': return StiloColors.accent;
      case 'almacen': return Color(0xFFFF9800);
      case 'blog': return StiloColors.accent;
      case 'reconocimiento': return Color(0xFFFFDE21);
      case 'social': return Color(0xFFB82B55);
      case 'proyecto_chat': return Color(0xFFC6FF68);
      default: return _acento;
    }
  }
}

class _EstadoError extends StatelessWidget {
  _EstadoError();
  @override Widget build(BuildContext context) => Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.notifications_paused_rounded, size: 68, color: Colors.orangeAccent), SizedBox(height: 16),
    Text('No pudimos cargar los avisos', style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.w800, fontSize: 19)), SizedBox(height: 8),
    Text('Comprueba tu conexión. La pantalla se actualizará automáticamente cuando vuelva el servicio.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), height: 1.4)),
  ])));
}

class _EstadoVacio extends StatelessWidget {
  final String nombre;
  _EstadoVacio({required this.nombre});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.notifications_none_rounded, size: 70, color: StiloColors.text.withValues(alpha: .24)), SizedBox(height: 18),
    Text('Todo al día, $nombre', textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: StiloColors.text, fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 8),
    Text('Aquí aparecerán nuevas tareas, solicitudes de almacén y comunicados.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), height: 1.4)),
  ])));
}
