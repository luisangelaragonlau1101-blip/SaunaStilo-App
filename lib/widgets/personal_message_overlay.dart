import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription<User?>? _authSub;
  final _seen = <String>{};
  final _queue = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final _audio = AudioPlayer();
  Timer? _stop;
  DialogRoute<String>? _dialog;
  bool _showing = false;
  bool _disposed = false;
  int _generation = 0;
  bool get _foreground => WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool _valid(int generation) => !_disposed && mounted && generation == _generation && FirebaseAuth.instance.currentUser?.uid == widget.usuario.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != widget.usuario.id) {
        _generation++;
        _queue.clear();
        unawaited(_stopAudio());
        _closeDialog();
      }
    });
    _listen();
  }
  @override
  void didUpdateWidget(covariant PersonalMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id) {
      _generation++;
      _sub?.cancel(); _queue.clear(); _seen.clear();
      unawaited(_stopAudio()); _closeDialog(); _listen();
    }
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
  Future<void> _stopAudio() async {
    _stop?.cancel();
    if (_disposed) return;
    try { await _audio.stop(); } catch (_) { /* A concurrent session disposal must not create an unhandled error. */ }
  }
  void _closeDialog() {
    final route = _dialog;
    _dialog = null;
    if (route != null) WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_drain());
    else { unawaited(_stopAudio()); _closeDialog(); }
  }
  Future<void> _drain() async {
    final generation = _generation;
    if (_showing || !_valid(generation) || !_foreground) return;
    _showing = true;
    try {
      while (_queue.isNotEmpty && _valid(generation) && _foreground) {
        final notice = _queue.removeAt(0);
        final data = notice.data();
        if (!_recent(data) || data['destinatarioId'] != widget.usuario.id) continue;
        final cid = data['conversacionId']; final mid = data['mensajeId'];
        if (cid is! String || mid is! String || cid.contains('/') || mid.contains('/')) continue;
        final message = await FirebaseFirestore.instance.collection('conversaciones').doc(cid).collection('mensajes').doc(mid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15));
        final content = message.data();
        if (!_valid(generation) || content == null || content['autorId'] != data['creadoPor']) continue;
        final author = await FirebaseFirestore.instance.collection('usuarios').doc(content['autorId'].toString()).get();
        if (!_valid(generation) || !author.exists) continue;
        if (!_foreground) { _queue.insert(0, notice); break; }
        final contact = UserModel.fromFirestore(author);
        final call = data['esLlamada'] == true;
        if (call && _recent(data)) {
          try {
            await _audio.setReleaseMode(ReleaseMode.loop);
            if (_valid(generation) && _foreground) await _audio.play(AssetSource('sounds/urgent_alarm.ogg'), volume: 1);
          } catch (_) {}
          if (!_valid(generation) || !_foreground) { await _stopAudio(); break; }
          _stop = Timer(const Duration(seconds: 20), () => unawaited(_stopAudio()));
        }
        final route = DialogRoute<String>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF130C10),
          icon: Icon(call ? Icons.phone_in_talk_rounded : Icons.mark_chat_unread_outlined, color: const Color(0xFFB7FF2A), size: 34),
          title: Text(call ? '${contact.nombre} te llama' : 'Mensaje de ${contact.nombre}'),
          content: SingleChildScrollView(child: Text(call ? 'Invitación a una sala de llamada. Pulsa Entrar para abrirla.' : (content['texto']?.toString().isNotEmpty == true ? content['texto'].toString() : 'Te envió un archivo o una nota de voz. Abre el chat para verlo.'), style: const TextStyle(height: 1.45))),
          actions: [TextButton(onPressed: () => Navigator.pop(c, 'dismiss'), child: const Text('Entendido')), FilledButton(onPressed: () => Navigator.pop(c, 'open'), child: Text(call ? 'Entrar' : 'Abrir chat'))],
        ));
        _dialog = route;
        final result = await Navigator.of(context, rootNavigator: true).push(route);
        if (_dialog == route) _dialog = null;
        await _stopAudio();
        if (!_valid(generation)) break;
        if (!_foreground) { _queue.insert(0, notice); break; }
        try { await notice.reference.update({'leidosPor': FieldValue.arrayUnion([widget.usuario.id])}); } catch (_) {}
        if (result == 'open' && _valid(generation)) {
          final url = Uri.tryParse(content['reunionUrl']?.toString() ?? '');
          if (call && _recent(data) && url?.scheme == 'https' && url?.host == 'meet.jit.si') {
            final opened = await launchUrl(url!, mode: LaunchMode.externalApplication);
            if (!opened && _valid(generation)) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se abrió la sala. Puedes entrar desde el chat.')));
          } else {
            unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConversacionPrivadaScreen(usuario: widget.usuario, contacto: contact))));
          }
        }
      }
    } catch (_) {
      // Protected reads may fail if access is revoked. No cached private text is disclosed.
    } finally { await _stopAudio(); _showing = false; }
  }
  @override
  void dispose() {
    _disposed = true; _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel(); _authSub?.cancel(); _stop?.cancel(); _queue.clear(); _closeDialog();
    unawaited(_audio.dispose().catchError((Object _) {}));
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.child;
}
