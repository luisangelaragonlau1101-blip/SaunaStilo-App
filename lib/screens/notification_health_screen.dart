import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/push_notifications_service.dart';

class NotificationHealthScreen extends StatefulWidget {
  final UserModel user;
  const NotificationHealthScreen({super.key, required this.user});
  @override State<NotificationHealthScreen> createState() => _NotificationHealthState();
}
class _NotificationHealthState extends State<NotificationHealthScreen> {
  final service = PushNotificationsService(), player = AudioPlayer();
  String status = 'Comprobando el dispositivo…';
  bool busy = false, playing = false;
  Timer? stopTimer;
  @override void initState() { super.initState(); _read(); }
  @override void dispose() { stopTimer?.cancel(); player.dispose(); service.dispose(); super.dispose(); }
  Future<void> _read() async {
    try {
      final settings = await service.currentSettings(), p = await SharedPreferences.getInstance();
      if (mounted) setState(() => status = 'Permiso del sistema: ${settings.authorizationStatus.name}.\n${p.getString('sauna.push.lastStatus.${widget.user.id}') ?? 'Todavía no hay un registro confirmado para este teléfono.'}');
    } catch (_) { if (mounted) setState(() => status = 'No se pudo consultar el permiso. Abre la aplicación en un navegador compatible o revisa los ajustes de Android.'); }
  }
  Future<void> _activate() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await service.activateFor(widget.user);
      final p = await SharedPreferences.getInstance();
      await p.setBool('sauna.push.promptShown.${widget.user.id}', true);
      await p.setString('sauna.push.lastStatus.${widget.user.id}', result.message);
      if (mounted) setState(() => status = result.message);
    } catch (_) {
      if (mounted) setState(() => status = 'No se confirmó el registro del dispositivo. Revisa la conexión y consulta el estado antes de reintentar.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _sound() async {
    try {
      stopTimer?.cancel(); await player.stop();
      if (playing) { if (mounted) setState(() => playing = false); return; }
      await player.play(AssetSource('sounds/urgent_alarm.ogg'), volume: 1);
      if (!mounted) return;
      setState(() => playing = true);
      stopTimer = Timer(const Duration(seconds: 3), () { player.stop(); if (mounted) setState(() => playing = false); });
    } catch (_) { if (mounted) setState(() { playing = false; status = 'No se pudo reproducir la alarma local. Revisa el volumen y el permiso de sonido.'; }); }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Notificaciones y sonido')), body: ListView(padding: const EdgeInsets.all(22), children: [
    const Icon(Icons.notifications_active_rounded, size: 60, color: Color(0xFFFFB876)), const SizedBox(height: 18),
    const Text('Sin preguntas repetidas', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
    const Text('El permiso no se vuelve a solicitar en cada inicio o al regresar a la aplicación. Puedes revisarlo o activarlo aquí cuando lo necesites.', style: TextStyle(color: Colors.white60, height: 1.5)),
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(status, style: const TextStyle(height: 1.5)))),
    FilledButton.icon(onPressed: busy ? null : _activate, icon: const Icon(Icons.phonelink_ring_rounded), label: Text(busy ? 'Registrando…' : 'Activar o volver a registrar este teléfono')),
    OutlinedButton.icon(onPressed: _sound, icon: Icon(playing ? Icons.stop_circle_rounded : Icons.volume_up_rounded), label: Text(playing ? 'Detener prueba' : 'Probar alarma aquí · 3 segundos')),
    TextButton.icon(onPressed: _read, icon: const Icon(Icons.refresh_rounded), label: const Text('Consultar estado')),
    const SizedBox(height: 18), const Text('La prueba de sonido solo se reproduce en este dispositivo. No envía avisos al personal. Registrar el teléfono no confirma que el servidor esté entregando notificaciones: la recepción en segundo plano requiere el servicio de envío, Internet y los permisos del sistema. No se cambia el volumen ni el modo Silencio.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
  ]));
}
