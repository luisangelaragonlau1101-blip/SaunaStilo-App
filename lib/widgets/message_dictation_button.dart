import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class MessageDictationButton extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  const MessageDictationButton({super.key, required this.controller, this.enabled = true});
  @override
  State<MessageDictationButton> createState() => _MessageDictationButtonState();
}
class _MessageDictationButtonState extends State<MessageDictationButton> {
  final _speech = SpeechToText();
  bool _listening = false;
  bool _starting = false;
  void _feedback(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _toggle() async {
    if (_starting) return;
    if (_listening) { await _speech.stop(); if (mounted) setState(() => _listening = false); return; }
    setState(() => _starting = true);
    try {
      final available = await _speech.initialize(onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) setState(() => _listening = false);
      }, onError: (_) {
        if (mounted) setState(() => _listening = false);
        _feedback('No se pudo continuar el dictado. Revisa el micrófono o dicta con el teclado del teléfono.');
      });
      if (!available || !mounted) { _feedback('Este navegador no ofrece dictado directo. Puedes usar el micrófono del teclado.'); return; }
      final prefix = widget.controller.text.trim();
      await _speech.listen(localeId: 'es_MX', onResult: (result) {
        if (!mounted) return;
        final text = '${prefix.isEmpty ? '' : '$prefix '}${result.recognizedWords}';
        widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      });
      if (mounted) setState(() => _listening = _speech.isListening);
    } catch (_) { _feedback('No se pudo iniciar el micrófono. Puedes escribir o usar el dictado del teclado.'); }
    finally { if (mounted) setState(() => _starting = false); }
  }
  @override
  void didUpdateWidget(covariant MessageDictationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) { _speech.stop(); _listening = false; }
  }
  @override
  void dispose() { _speech.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IconButton(tooltip: _listening ? 'Detener dictado' : 'Dictar texto', onPressed: widget.enabled && !_starting ? _toggle : null, icon: Icon(_listening ? Icons.mic_rounded : Icons.keyboard_voice_outlined, color: _listening ? const Color(0xFFFF647A) : const Color(0xFFB7FF2A)));
}
