import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'asistente_ia_screen.dart';

class StiloIntelligenceScreen extends StatefulWidget {
  final UserModel usuario;
  const StiloIntelligenceScreen({super.key, required this.usuario});
  @override
  State<StiloIntelligenceScreen> createState() => _StiloIntelligenceScreenState();
}
class _StiloIntelligenceScreenState extends State<StiloIntelligenceScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _player = AudioPlayer();
  final List<Map<String, dynamic>> _messages = [];
  bool _web = false, _busy = false, _voiceBusy = false, _autoVoice = false;
  int _audioGeneration = 0;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  void _notice(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
  String _error(Object error) => error is FirebaseFunctionsException && ['not-found', 'unavailable'].contains(error.code) ? 'El servicio todavía no está disponible. Usa el asistente existente o pide a Administración revisar Firebase.' : error is FirebaseFunctionsException && error.message != null ? error.message! : 'No se pudo completar la solicitud. No se ha ejecutado ninguna acción.';
  Future<void> _speak(String id) async {
    if (_voiceBusy) return;
    final generation = ++_audioGeneration;
    setState(() => _voiceBusy = true);
    try {
      await _player.stop();
      final result = await _functions.httpsCallable('saunaBrandSpeak', options: HttpsCallableOptions(timeout: const Duration(seconds: 45))).call({'replyId': id});
      if (!mounted || generation != _audioGeneration) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      await _player.play(BytesSource(base64Decode(data['audio'] as String), mimeType: 'audio/mpeg'));
    } catch (error) { _notice(_error(error)); }
    finally { if (mounted) setState(() => _voiceBusy = false); }
  }
  Future<void> _send() async {
    final question = _text.text.trim();
    if (_busy || question.isEmpty) return;
    if (question.length > 2500) { _notice('Escribe hasta 2500 caracteres.'); return; }
    final history = _messages.where((m) => m['mode'] == (_web ? 'internet' : 'empresa') && m['error'] != true).map((m) => {'rol': m['user'] == true ? 'usuario' : 'asistente', 'texto': m['text']}).toList();
    final mode = _web ? 'internet' : 'empresa';
    setState(() { _busy = true; _text.clear(); _messages.add({'text': question, 'user': true, 'mode': mode}); });
    try {
      final result = await _functions.httpsCallable('saunaStiloAssistant', options: HttpsCallableOptions(timeout: const Duration(seconds: 80))).call({'pregunta': question, 'historial': history, 'modo': mode});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = data['respuesta']?.toString().trim() ?? '';
      if (answer.isEmpty) throw StateError('Empty response');
      setState(() => _messages.add({'text': answer, 'user': false, 'mode': mode, 'replyId': data['replyId'], 'sources': data['fuentes'] ?? []}));
      if (_autoVoice && data['replyId'] is String) await _speak(data['replyId']);
    } catch (error) { if (mounted) setState(() => _messages.add({'text': _error(error), 'user': false, 'error': true, 'mode': mode})); }
    finally {
      if (mounted) { setState(() => _busy = false); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); }); }
    }
  }
  @override
  void dispose() { _audioGeneration++; _player.dispose(); _text.dispose(); _scroll.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF08090B), appBar: AppBar(title: const Text('SAUNA IA'), actions: [IconButton(tooltip: 'Detener voz', onPressed: () { _audioGeneration++; _player.stop(); }, icon: const Icon(Icons.stop_circle_outlined)), IconButton(tooltip: 'Asistente existente con fotos y audios', onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AsistenteIaScreen(usuario: widget.usuario))), icon: const Icon(Icons.attach_file_rounded))]), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Column(children: [
      SegmentedButton<bool>(segments: const [ButtonSegment(value: false, icon: Icon(Icons.business_outlined), label: Text('Empresa')), ButtonSegment(value: true, icon: Icon(Icons.public_rounded), label: Text('Internet'))], selected: {_web}, onSelectionChanged: _busy ? null : (value) => setState(() => _web = value.first)),
      const SizedBox(height: 10),
      Text(_web ? 'Búsqueda pública con fuentes. No envíes datos privados de clientes o del equipo.' : 'Consulta los datos autorizados para tu cuenta. No ejecuta cambios sin que los registres en el módulo.', style: const TextStyle(fontSize: 12, color: Color(0xFFC7CAD2), height: 1.4)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Leer con la voz de la marca', style: TextStyle(fontSize: 14)), subtitle: const Text('Voz sintética autorizada; requiere activación.', style: TextStyle(fontSize: 11)), value: _autoVoice, onChanged: (value) { setState(() => _autoVoice = value); if (!value) { _audioGeneration++; _player.stop(); } }),
    ])),
    Expanded(child: _messages.isEmpty ? ListView(padding: const EdgeInsets.all(24), children: [const Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.white70), const SizedBox(height: 24), const Text('Tu trabajo, más claro.', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 12), const Text('Pregunta por tus pendientes o consulta información pública. El servicio muestra sus errores reales; no sustituye una conexión fallida por respuestas inventadas.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB9BDC6), height: 1.5)), const SizedBox(height: 24), OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AsistenteIaScreen(usuario: widget.usuario))), icon: const Icon(Icons.forum_outlined), label: const Text('Abrir asistente existente y adjuntos'))]) : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(18), itemCount: _messages.length, itemBuilder: (context, index) {
      final item = _messages[index];
      final user = item['user'] == true;
      final sources = item['sources'] is List ? item['sources'] as List : const [];
      return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 650), margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: user ? const Color(0xFF303239) : const Color(0xFF16171B), borderRadius: BorderRadius.circular(20), border: Border.all(color: item['error'] == true ? const Color(0xFFB8837A) : const Color(0xFF33353B))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user ? 'Tú' : 'Sauna IA · ${item['mode']}', style: const TextStyle(fontSize: 11, color: Color(0xFFBBC0CA))), const SizedBox(height: 8), SelectableText(item['text'].toString(), style: const TextStyle(height: 1.5, fontSize: 15)), if (item['replyId'] is String) TextButton.icon(onPressed: _voiceBusy ? null : () => _speak(item['replyId'] as String), icon: const Icon(Icons.volume_up_outlined), label: Text(_voiceBusy ? 'Preparando voz…' : 'Escuchar voz de marca')), ...sources.whereType<Map>().map((source) => TextButton.icon(onPressed: () async { final uri = Uri.tryParse(source['url']?.toString() ?? ''); if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) { try { final opened = await launchUrl(uri, mode: LaunchMode.externalApplication); if (!opened) _notice('No se pudo abrir la fuente.'); } catch (_) { _notice('No se pudo abrir la fuente.'); } } }, icon: const Icon(Icons.open_in_new_rounded, size: 16), label: Text(source['titulo']?.toString() ?? 'Consultar fuente', maxLines: 2, overflow: TextOverflow.ellipsis)))])));
    })),
    if (_busy) const LinearProgressIndicator(minHeight: 2),
    Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: _text, minLines: 1, maxLines: 5, maxLength: 2500, decoration: const InputDecoration(hintText: 'Escribe tu pregunta…', counterText: '', border: OutlineInputBorder()))), const SizedBox(width: 10), IconButton.filled(tooltip: 'Enviar pregunta', onPressed: _busy ? null : _send, icon: const Icon(Icons.arrow_upward_rounded))])),
  ])))));
}
