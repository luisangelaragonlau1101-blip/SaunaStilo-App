import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
class DictadoButton extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  const DictadoButton({super.key, required this.controller, this.enabled = true});
  @override
  State<DictadoButton> createState() => _DictadoButtonState();
}
class _DictadoButtonState extends State<DictadoButton> {
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  bool _starting = false;
  String _before = '';
  @override
  void dispose() { _speech.cancel(); super.dispose(); }
  Future<void> _toggle() async {
    if (_starting) return;
    if (_listening) { await _speech.stop(); if (mounted) setState(() => _listening = false); return; }
    _starting = true;
    try {
      final ready = await _speech.initialize(onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) setState(() => _listening = false);
      }, onError: (_) { if (mounted) setState(() => _listening = false); });
      if (!mounted) return;
      if (!ready) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El dictado no está disponible. Puedes usar el micrófono del teclado o enviar una nota de voz.')));
        return;
      }
      _before = widget.controller.text.trim();
      setState(() => _listening = true);
      await _speech.listen(localeId: 'es_MX', onResult: (result) {
        if (!mounted) return;
        widget.controller.text = '${_before.isEmpty ? '' : '$_before '}${result.recognizedWords}';
        widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
      });
    } catch (_) {
      if (mounted) { setState(() => _listening = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo iniciar el dictado. Revisa el permiso de micrófono.'))); }
    } finally { _starting = false; }
  }
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _listening ? 'Detener dictado' : 'Dictar mensaje',
    onPressed: widget.enabled ? _toggle : null,
    icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _listening ? const Color(0xFFB82B55) : const Color(0xFFB7FF2A)));
}
