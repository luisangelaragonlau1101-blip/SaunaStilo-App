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
  final NotificacionesService _notificacionesService =
      NotificacionesService();
  final PushNotificationsService _pushService = PushNotificationsService();
  StreamSubscription<List<NotificacionApp>>? _subscription;
  Set<String>? _idsConocidos;
  final Set<String> _alarmasPendientes = <String>{};
  bool _configurandoPush = false;
  bool _alarmaActiva = false;
  bool _dialogoAlarmaVisible = false;

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
    _subscription = _notificacionesService
        .avisosPara(usuarioId: widget.usuario.id, rol: widget.usuario.rol)
        .listen((avisos) async {
          final idsActuales = avisos.map((aviso) => aviso.id).toSet();
          if (_idsConocidos == null) {
            _idsConocidos = idsActuales;
            final alarmasSinConfirmar = avisos
                .where(
                  (aviso) =>
                      aviso.tipo == 'alarma_admin' &&
                      !aviso.leidaPor(widget.usuario.id),
                )
                .toList(growable: false);
            if (alarmasSinConfirmar.isNotEmpty) {
              _alarmasPendientes.addAll(
                alarmasSinConfirmar.map((aviso) => aviso.id),
              );
              await _activarAlarmaUrgente(alarmasSinConfirmar.first);
            }
            return;
          }
          final nuevos = avisos
              .where((aviso) => !_idsConocidos!.contains(aviso.id))
              .toList(growable: false);
          _idsConocidos = idsActuales;
          if (nuevos.isEmpty) return;

          final alarmas = nuevos
              .where((aviso) => aviso.tipo == 'alarma_admin')
              .toList(growable: false);
          if (alarmas.isNotEmpty) {
            _alarmasPendientes.addAll(alarmas.map((aviso) => aviso.id));
            await _activarAlarmaUrgente(alarmas.first);
            return;
          }

          await _reproducirAvisoNormal();
          if (!mounted || _alarmaActiva) return;
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

  Future<void> _reproducirAvisoNormal() async {
    if (_alarmaActiva) return;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sounds/beep.ogg'), volume: 1);
    } catch (_) {
      // El aviso visual permanece disponible si el navegador bloquea el audio.
    }
  }

  Future<void> _activarAlarmaUrgente(NotificacionApp aviso) async {
    if (!mounted) return;

    if (!_alarmaActiva) {
      _alarmaActiva = true;
      try {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/urgent_alarm.ogg'), volume: 1);
      } catch (_) {
        // Algunos navegadores exigen interacción; el diálogo sigue siendo visible.
      }
    }

    if (!mounted || _dialogoAlarmaVisible) return;
    _dialogoAlarmaVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF160606),
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFFF3B30), width: 2),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF453A),
                size: 42,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ALARMA INTERNA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aviso.titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                aviso.mensaje,
                style: const TextStyle(
                  color: Color(0xFFFFD8D5),
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Confirma que recibiste esta alerta para detener el sonido.',
                style: TextStyle(
                  color: Color(0xFFFF9F99),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  await _detenerYReconocerAlarma();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'DETENER Y CONFIRMAR',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    _dialogoAlarmaVisible = false;
  }

  Future<void> _detenerYReconocerAlarma() async {
    final alarmasAReconocer = Set<String>.from(_alarmasPendientes);
    _alarmasPendientes.clear();
    _alarmaActiva = false;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (_) {}

    for (final avisoId in alarmasAReconocer) {
      try {
        await _notificacionesService.marcarLeida(avisoId, widget.usuario.id);
      } catch (_) {
        // Detener el sonido no depende de la conexión disponible en ese momento.
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pushService.dispose();
    _alarmaActiva = false;
    _alarmasPendientes.clear();
    unawaited(_player.stop());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
