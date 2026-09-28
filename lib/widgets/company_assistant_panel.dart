import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../workflow/staff_policy.dart';
import 'official_voice_reply.dart';

class CompanyAssistantPanel extends StatefulWidget {
  final CompanyLearningService? service;
  final String description, example;
  CompanyAssistantPanel({super.key, this.service,
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
  Future<void> _officialVoice(String text) async {
    _stop();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OfficialVoiceReply(text: text),
    );
  }
  @override Widget build(BuildContext context) => Column(children: [
    Expanded(child: ListView(padding: EdgeInsets.all(18), children: [
      Text('Online Smart · Sauna Stilo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      SizedBox(height: 8), Text(widget.description, style: TextStyle(color: StiloColors.text.withValues(alpha: .60), height: 1.5)),
      SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Icon(Icons.record_voice_over_rounded, color: StiloColors.accent), title: Text('Responder también con voz'), subtitle: Text('Voz del dispositivo · respuesta completa'), value: _autoRead, onChanged: (v) { if (!v) _stop(); setState(() => _autoRead = v); }),
      if (_speaking) TextButton.icon(onPressed: _stop, icon: Icon(Icons.stop_circle_rounded, color: Color(0xFFFF729C)), label: Text('Detener lectura')),
      if (_messages.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text(widget.example, style: TextStyle(color: StiloColors.text.withValues(alpha: .70)))),
      for (final m in _messages) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: StiloColors.surface, child: Padding(padding: EdgeInsets.all(16), child: Text(m['question'], style: TextStyle(fontWeight: FontWeight.w700)))),
        Card(child: Padding(padding: EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['text'], style: TextStyle(height: 1.55)), SizedBox(height: 10),
          Text(m['hasManuals'] == true ? 'Respuesta con manuales autorizados' : 'Sin un manual coincidente · orientación general', style: TextStyle(fontSize: 11, color: StiloColors.accent)),
          TextButton.icon(onPressed: () => _speak(m['text']), icon: Icon(Icons.volume_up_rounded), label: Text('Escuchar · voz del dispositivo')),
          TextButton.icon(onPressed: () => _officialVoice(m['text']), icon: Icon(Icons.graphic_eq_rounded), label: Text('Escuchar · voz de Ángel')),
          for (final source in (m['sources'] as List? ?? [])) ExpansionTile(title: Text('${source['title']} · v${source['version']}'), subtitle: Text('Fragmento ${source['section']}'), children: [Padding(padding: EdgeInsets.all(12), child: Text(source['text'], style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.5)))]),
        ]))),
      ]),
      if (_error != null) Padding(padding: EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Colors.orangeAccent))),
    ])),
    SafeArea(top: false, child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: TextField(contextMenuBuilder: privacyTextMenu, controller: input, enabled: !_busy, minLines: 1, maxLines: 4, maxLength: 2500, decoration: InputDecoration(hintText: '¿Cómo le hago con…?', counterText: ''), onSubmitted: (_) => _send())),
      SizedBox(width: 8), IconButton.filled(tooltip: 'Enviar pregunta', onPressed: _busy ? null : _send, icon: _busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.send_rounded)),
    ]))),
  ]);
}
