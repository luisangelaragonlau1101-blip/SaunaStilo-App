import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../workflow/staff_policy.dart';

class CompanyAssistantPanel extends StatefulWidget {
  final CompanyLearningService? service;
  final String description, example;
  const CompanyAssistantPanel({super.key, this.service,
    this.description = 'Inteligencia artificial mexicana creada por ANGEL ZALDÍVAR. Pregunta cómo realizar una actividad; consultaré los manuales publicados para tu cuenta.',
    this.example = 'Ejemplo: “¿Cómo uso el control del sauna?”\nIncluye el modelo o equipo para encontrar el procedimiento correcto.'});
  @override State<CompanyAssistantPanel> createState() => _CompanyAssistantState();
}
class _CompanyAssistantState extends State<CompanyAssistantPanel> with WidgetsBindingObserver {
  final input = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _busy = false, _autoRead = false, _speaking = false;
  String? _error;
  FlutterTts? _tts;
  int _speech = 0;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void didChangeDependencies() { super.didChangeDependencies(); if (!TickerMode.of(context)) { _speech++; _tts?.stop(); _speaking = false; } }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state != AppLifecycleState.resumed) _stop(); }
  void _stop() { _speech++; _tts?.stop(); if (mounted) setState(() => _speaking = false); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _speech++; input.dispose(); _tts?.stop(); super.dispose(); }
  Future<void> _send() async {
    final q = input.text.trim(); if (q.isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final r = await (widget.service ?? CompanyLearningService()).call('manual-ask', {'question': q});
      if (!mounted) return;
      final full = plainAssistantText(r['text']?.toString() ?? '');
      if (full.isEmpty) throw StateError('El asistente no devolvió una respuesta.');
      setState(() { _messages.add({'question': q, ...r, 'text': full}); if (_messages.length > 15) _messages.removeAt(0); });
      input.clear();
      if (_autoRead && TickerMode.of(context)) _speak(full);
    } catch (e) { if (mounted) setState(() => _error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _speak(String text) async {
    final ticket = ++_speech;
    try {
      final t = _tts ??= FlutterTts();
      await t.stop(); await t.setLanguage('es-MX'); await t.awaitSpeakCompletion(true);
      if (!mounted || ticket != _speech) return;
      setState(() => _speaking = true);
      for (final part in spokenAnswerChunks(text)) {
        if (!mounted || ticket != _speech || !TickerMode.of(context)) break;
        await t.speak(part);
      }
    } catch (_) { if (mounted) setState(() => _error = 'La voz del dispositivo no está disponible. La respuesta completa permanece en pantalla.'); }
    finally { if (mounted && ticket == _speech) setState(() => _speaking = false); }
  }
  @override Widget build(BuildContext context) => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Online Smart · Sauna Stilo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), Text(widget.description, style: const TextStyle(color: Colors.white60, height: 1.5)),
      SwitchListTile(contentPadding: EdgeInsets.zero, secondary: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFC798FF)), title: const Text('Responder también con voz'), subtitle: const Text('Voz del dispositivo · respuesta completa'), value: _autoRead, onChanged: (v) { if (!v) _stop(); setState(() => _autoRead = v); }),
      if (_speaking) TextButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFFFF729C)), label: const Text('Detener lectura')),
      if (_messages.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(widget.example, style: const TextStyle(color: Colors.white70))),
      for (final m in _messages) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: const Color(0xFF2A101C), child: Padding(padding: const EdgeInsets.all(16), child: Text(m['question'], style: const TextStyle(fontWeight: FontWeight.w700)))),
        Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['text'], style: const TextStyle(height: 1.55)), const SizedBox(height: 10),
          Text(m['hasManuals'] == true ? 'Respuesta con manuales autorizados' : 'Sin un manual coincidente · orientación general', style: const TextStyle(fontSize: 11, color: Color(0xFFC798FF))),
          TextButton.icon(onPressed: () => _speak(m['text']), icon: const Icon(Icons.volume_up_rounded), label: const Text('Escuchar · voz del dispositivo')),
          for (final source in (m['sources'] as List? ?? [])) ExpansionTile(title: Text('${source['title']} · v${source['version']}'), subtitle: Text('Fragmento ${source['section']}'), children: [Padding(padding: const EdgeInsets.all(12), child: Text(source['text'], style: const TextStyle(color: Colors.white70, height: 1.5)))]),
        ]))),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
    ])),
    SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: TextField(contextMenuBuilder: privacyTextMenu, controller: input, enabled: !_busy, minLines: 1, maxLines: 4, maxLength: 2500, decoration: const InputDecoration(hintText: '¿Cómo le hago con…?', counterText: ''), onSubmitted: (_) => _send())),
      const SizedBox(width: 8), IconButton.filled(tooltip: 'Enviar pregunta', onPressed: _busy ? null : _send, icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
    ]))),
  ]);
}
