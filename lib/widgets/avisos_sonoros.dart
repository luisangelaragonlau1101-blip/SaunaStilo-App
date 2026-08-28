import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notificacion_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import '../services/push_notifications_service.dart';

class AvisosSonoros extends StatefulWidget {
  final UserModel usuario;
  final Widget child;

  const AvisosSonoros({
    super.key,
    required this.usuario,
    required this.child,
  });

  @override
  State<AvisosSonoros> createState() => _AvisosSonorosState();
}

class _AvisosSonorosState extends State<AvisosSonoros> {
  final AudioPlayer _player = AudioPlayer();
  final PushNotificationsService _pushService = PushNotificationsService();
  StreamSubscription<List<NotificacionApp>>? _subscription;
  Set<String>? _idsConocidos;
  bool _configurandoPush = false;

  @override
  void initState() {
    super.initState();
    _escuchar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preparePushNotifications();
    });
  }

  @override
  void didUpdateWidget(covariant AvisosSonoros oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id ||
        oldWidget.usuario.rol != widget.usuario.rol) {
      _subscription?.cancel();
      _idsConocidos = null;
      _escuchar();
      _preparePushNotifications();
    }
  }

  Future<void> _preparePushNotifications() async {
    if (!mounted || _configurandoPush) return;
    _configurandoPush = true;
    try {
      final settings = await _pushService.currentSettings();
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (authorized || !kIsWeb) {
        final result = await _pushService.activateFor(widget.usuario);
        if (!result.active && mounted) {
          _showPushAction(result.message);
        }
      } else if (mounted) {
        _showPushAction(
          'Activa las notificaciones para recibir tareas y solicitudes aunque la app esté cerrada.',
        );
      }
    } finally {
      _configurandoPush = false;
    }
  }

  void _showPushAction(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 18),
          backgroundColor: const Color(0xFF171717),
          behavior: SnackBarBehavior.floating,
          content: Text(message),
          action: SnackBarAction(
            label: 'ACTIVAR',
            textColor: const Color(0xFF00E5FF),
            onPressed: _activatePushFromUserAction,
          ),
        ),
      );
  }

  Future<void> _activatePushFromUserAction() async {
    if (_configurandoPush) return;
    _configurandoPush = true;
    final result = await _pushService.activateFor(widget.usuario);
    _configurandoPush = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: result.active
              ? const Color(0xFF12372A)
              : const Color(0xFF3A1D1D),
          behavior: SnackBarBehavior.floating,
          content: Text(result.message),
        ),
      );
  }

  void _escuchar() {
    _subscription = NotificacionesService()
        .avisosPara(usuarioId: widget.usuario.id, rol: widget.usuario.rol)
        .listen((avisos) async {
          final idsActuales = avisos.map((aviso) => aviso.id).toSet();
          if (_idsConocidos == null) {
            _idsConocidos = idsActuales;
            return;
          }
          final nuevos = avisos
              .where((aviso) => !_idsConocidos!.contains(aviso.id))
              .toList(growable: false);
          _idsConocidos = idsActuales;
          if (nuevos.isEmpty) return;
          try {
            await _player.play(AssetSource('sounds/beep.ogg'), volume: 1);
          } catch (_) {}
          if (!mounted) return;
          final aviso = nuevos.first;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF171717),
                behavior: SnackBarBehavior.floating,
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 11),
                    Expanded(child: Text('${aviso.titulo}\n${aviso.mensaje}')),
                  ],
                ),
              ),
            );
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pushService.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
