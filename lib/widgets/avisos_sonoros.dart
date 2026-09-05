import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notificacion_model.dart';
import '../screens/notificaciones_screen.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import '../services/notification_router.dart';
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

class _AvisosSonorosState extends State<AvisosSonoros> with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _openedSubscription;
  final Set<String> _openedIds = <String>{};
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
  bool _avisoPersonalVisible = false;
  Timer? _soundTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) => _openNotice(message.data['notificationId']?.toString()));
    _escuchar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preparePushNotifications();
      if (kIsWeb) {
        _openNotice(Uri.base.queryParameters['notification']);
      } else {
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) _openNotice(message.data['notificationId']?.toString());
        }).catchError((Object _) {});
      }
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

  void _openNotice(String? id) {
    if (!mounted || id == null || id.isEmpty || !_openedIds.add(id)) return;
    unawaited(NotificationRouter.open(context, widget.usuario, id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _preparePushNotifications();
  }

  Future<void> _preparePushNotifications() async {
    if (!mounted || _configurandoPush) return;
    _configurandoPush = true;
    try {
      final settings = await _pushService.currentSettings();
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (authorized) {
        final result = await _pushService.activateFor(widget.usuario);
        if (!result.active && mounted) {
          _showPushAction(result.message);
        }
      } else if (mounted) {
        _showPushAction(
          'Activa las notificaciones para recibir tareas y solicitudes aunque la app esté cerrada.',
        );
      }
    } catch (_) {
      // Unsupported browser or temporary network failure must not break startup.
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
            textColor: const Color(0xFFB7FF2A),
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
                      !aviso.leidaPor(widget.usuario.id) &&
                      DateTime.now().difference(aviso.fecha).inMinutes < 15,
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
              .where((aviso) => !_idsConocidos!.contains(aviso.id) && !aviso.leidaPor(widget.usuario.id) &&
                aviso.tipo != 'aviso_personal' && aviso.creadoPor != widget.usuario.id && DateTime.now().difference(aviso.fecha).inMinutes < 15)
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

          final destacados = nuevos.where((a) => a.tipo == 'aviso_personal' || (a.esLlamada && DateTime.now().difference(a.fecha).inSeconds < 60)).toList();
          if (destacados.isNotEmpty && !_avisoPersonalVisible && !_alarmaActiva) {
            await _mostrarPersonal(destacados.first);
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
                action: SnackBarAction(label: 'ABRIR', onPressed: () => _openNotice(aviso.id)),
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFB7FF2A)),
                    const SizedBox(width: 11),
                    Expanded(child: Text('${aviso.titulo}\n${aviso.mensaje}')),
                  ],
                ),
              ),
            );
        }, onError: (Object _) {
          if (mounted) _showPushAction('No se pudieron sincronizar los avisos. Revisa la conexión; no se ha confirmado su recepción.');
        });
  }

  Future<void> _mostrarPersonal(NotificacionApp aviso) async {
    if (!mounted || _avisoPersonalVisible) return;
    _avisoPersonalVisible = true;
    bool open = false;
    try {
      try {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/urgent_alarm.ogg'), volume: 1);
        _soundTimeout?.cancel();
        _soundTimeout = Timer(const Duration(seconds: 8), () { if (!_alarmaActiva) unawaited(_player.stop()); });
      } catch (_) {}
      if (!mounted) return;
      open = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF190A10),
        title: Row(children: [Icon(aviso.esLlamada ? Icons.call_outlined : Icons.notifications_active_outlined, color: const Color(0xFFB7FF2A)), const SizedBox(width: 12), Expanded(child: Text(aviso.titulo))]),
        content: SingleChildScrollView(child: Text(aviso.mensaje, style: const TextStyle(fontSize: 18, height: 1.5))),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Recibido')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(aviso.esLlamada ? 'Abrir llamada' : 'Ver mensaje'))],
      )) ?? false;
      try { await _notificacionesService.marcarLeida(aviso.id, widget.usuario.id); } catch (_) {}
    } finally {
      _soundTimeout?.cancel();
      if (!_alarmaActiva) { try { await _player.stop(); await _player.setReleaseMode(ReleaseMode.release); } catch (_) {} }
      _avisoPersonalVisible = false;
    }
    if (open && mounted) _openNotice(aviso.id);
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
    WidgetsBinding.instance.removeObserver(this);
    _openedSubscription?.cancel();
    _subscription?.cancel();
    _soundTimeout?.cancel();
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
