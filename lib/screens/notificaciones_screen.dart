import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/notificacion_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';

class NotificacionesScreen extends StatelessWidget {
  final UserModel usuario;

  const NotificacionesScreen({super.key, required this.usuario});

  static const _fondo = Color(0xFF000000);
  static const _tarjeta = Color(0xFF171717);
  static const _acento = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final service = NotificacionesService();
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text(
          'AVISOS',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => service.marcarTodasLeidas(
              usuarioId: usuario.id,
              rol: usuario.rol,
            ),
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificacionApp>>(
        stream: service.avisosPara(
          usuarioId: usuario.id,
          rol: usuario.rol,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final avisos = snapshot.data ?? const <NotificacionApp>[];
          if (avisos.isEmpty) {
            return _EstadoVacio(nombre: usuario.nombre);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            itemCount: avisos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aviso = avisos[index];
              final leida = aviso.leidaPor(usuario.id);
              return InkWell(
                onTap: leida
                    ? null
                    : () => service.marcarLeida(aviso.id, usuario.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _tarjeta,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: leida ? Colors.white10 : _acento.withOpacity(.7),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _color(aviso.tipo).withOpacity(.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_icono(aviso.tipo), color: _color(aviso.tipo)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    aviso.titulo,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (!leida)
                                  const CircleAvatar(
                                    radius: 5,
                                    backgroundColor: _acento,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              aviso.mensaje,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              DateFormat('dd MMM yyyy · HH:mm', 'es')
                                  .format(aviso.fecha),
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static IconData _icono(String tipo) {
    switch (tipo) {
      case 'tarea':
        return Icons.assignment_turned_in_rounded;
      case 'almacen':
        return Icons.inventory_2_rounded;
      case 'blog':
        return Icons.campaign_rounded;
      case 'reconocimiento':
        return Icons.workspace_premium_rounded;
      case 'social':
        return Icons.forum_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static Color _color(String tipo) {
    switch (tipo) {
      case 'tarea':
        return const Color(0xFF00E676);
      case 'almacen':
        return const Color(0xFFFF9800);
      case 'blog':
        return const Color(0xFF8B5CF6);
      case 'reconocimiento':
        return const Color(0xFFFFDE21);
      case 'social':
        return const Color(0xFF00E5FF);
      default:
        return _acento;
    }
  }
}

class _EstadoVacio extends StatelessWidget {
  final String nombre;

  const _EstadoVacio({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 70, color: Colors.white24),
            const SizedBox(height: 18),
            Text(
              'Todo al día, $nombre',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí aparecerán nuevas tareas, solicitudes de almacén y comunicados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
