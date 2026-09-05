import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../screens/mensajes_equipo_screen.dart';

class PersonalMessageOverlay extends StatefulWidget {
  final UserModel usuario;
  final Widget child;
  const PersonalMessageOverlay({super.key, required this.usuario, required this.child});
  @override
  State<PersonalMessageOverlay> createState() => _PersonalMessageOverlayState();
}
class _PersonalMessageOverlayState extends State<PersonalMessageOverlay> with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final _seen = <String>{};
  final _queue = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final _audio = AudioPlayer();
  Timer? _stop;
  bool _showing = false;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _listen(); }
  @override
  void didUpdateWidget(covariant PersonalMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id) { _sub?.cancel(); _queue.clear(); _seen.clear(); _listen(); }
  }
  bool _recent(Map<String, dynamic> data) {
    final date = data['fecha'];
    if (date is! Timestamp) return false;
    final age = DateTime.now().difference(date.toDate());
    return !age.isNegative && age.inSeconds < (data['esLlamada'] == true ? 60 : 900);
  }
  void _listen() {
    _sub = FirebaseFirestore.instance.collection('notificaciones').where('destinatarioId', isEqualTo: widget.usuario.id).snapshots().listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['tipo'] != 'aviso_personal' || !_recent(data) || (data['leidosPor'] is List && (data['leidosPor'] as List).contains(widget.usuario.id)) || !_seen.add(doc.id)) continue;
        _queue.add(doc);
      }
      unawaited(_drain());
    }, onError: (Object _) { /* The existing inbox remains available. */ });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_drain());
    else { _stop?.cancel(); unawaited(_audio.stop()); }
  }
  Future<void> _drain() async {
    if (_showing || !mounted || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused || WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden) return;
    _showing = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        final notice = _queue.removeAt(0);
        final data = notice.data();
        if (!_recent(data) || data['destinatarioId'] != widget.usuario.id) continue;
        final cid = data['conversacionId']; final mid = data['mensajeId'];
        if (cid is! String || mid is! String || cid.contains('/') || mid.contains('/')) continue;
        final message = await FirebaseFirestore.instance.collection('conversaciones').doc(cid).collection('mensajes').doc(mid).get();
        final content = message.data();
        if (!mounted || content == null || content['autorId'] != data['creadoPor']) continue;
        final author = await FirebaseFirestore.instance.collection('usuarios').doc(content['autorId'].toString()).get();
        if (!mounted || !author.exists) continue;
        final contact = UserModel.fromFirestore(author);
        final call = data['esLlamada'] == true;
        if (call && _recent(data)) {
          try { await _audio.setReleaseMode(ReleaseMode.loop); await _audio.play(AssetSource('sounds/urgent_alarm.ogg'), volume: 1); } catch (_) {}
          _stop?.cancel(); _stop = Timer(const Duration(seconds: 20), () => _audio.stop());
        }
        if (!call) {
          try { await _audio.setReleaseMode(ReleaseMode.release); await _audio.play(AssetSource('sounds/beep.ogg'), volume: 1); } catch (_) {}
        }
        final result = await showDialog<String>(context: context, builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF130C10),
          icon: Icon(call ? Icons.phone_in_talk_rounded : Icons.mark_chat_unread_outlined, color: const Color(0xFFB7FF2A), size: 34),
          title: Text(call ? '${contact.nombre} te llama' : 'Mensaje de ${contact.nombre}'),
          content: SingleChildScrollView(child: Text(call ? 'Invitación a una sala de llamada. Pulsa Entrar para abrirla.' : (content['texto']?.toString().isNotEmpty == true ? content['texto'].toString() : 'Te envió un archivo o una nota de voz. Abre el chat para verlo.'), style: const TextStyle(height: 1.45))),
          actions: [TextButton(onPressed: () => Navigator.pop(c, 'dismiss'), child: const Text('Entendido')), FilledButton(onPressed: () => Navigator.pop(c, 'open'), child: Text(call ? 'Entrar' : 'Abrir chat'))],
        ));
        _stop?.cancel(); await _audio.stop();
        if (!mounted) break;
        try { await notice.reference.update({'leidosPor': FieldValue.arrayUnion([widget.usuario.id])}); } catch (_) {}
        if (result == 'open' && mounted) {
          final url = Uri.tryParse(content['reunionUrl']?.toString() ?? '');
          if (call && _recent(data) && url?.scheme == 'https' && url?.host == 'meet.jit.si') {
            final opened = await launchUrl(url!, mode: LaunchMode.externalApplication);
            if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se abrió la sala. Puedes entrar desde el chat.')));
          } else {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConversacionPrivadaScreen(usuario: widget.usuario, contacto: contact)));
          }
        }
      }
    } catch (_) {
      // Protected message reads can fail if project or account access was revoked.
    } finally { _stop?.cancel(); await _audio.stop(); _showing = false; }
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _sub?.cancel(); _stop?.cancel(); _queue.clear(); unawaited(_audio.dispose()); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.child;
}
