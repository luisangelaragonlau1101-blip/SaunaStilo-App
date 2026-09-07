import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/custom_voice_service.dart';

/// Synthesizes only a reply explicitly selected by the user, inside the
/// authenticated Sauna Stilo parent. No Firebase credential goes to the iframe.
class OfficialVoiceReply extends StatefulWidget {
  final String text;
  const OfficialVoiceReply({super.key, required this.text});
  @override
  State<OfficialVoiceReply> createState() => _OfficialVoiceReplyState();
}
class _OfficialVoiceReplyState extends State<OfficialVoiceReply> {
  final _voice = CustomVoiceService();
  final _player = AudioPlayer();
  late final List<String> _parts = splitVoiceReply(widget.text);
  final _audio = <int, AdminVoiceAudio>{};
  int _part = 0, _generation = 0;
  bool _busy = false, _playing = false;
  String? _error;
  StreamSubscription<void>? _complete;
  @override
  void initState() {super.initState(); _complete = _player.onPlayerComplete.listen((_) {if (mounted) setState(() => _playing = false);});}
  @override
  void dispose() {++_generation; _complete?.cancel(); _player.dispose(); super.dispose();}
  Future<void> _generate() async {
    if (_busy || _parts.isEmpty) return;
    final part = _part, epoch = ++_generation;
    setState(() {_busy = true; _error = null;});
    try {
      final status = await _voice.status();
      if (!status.enabled) throw const CustomVoiceException('La voz oficial aún no está activada. Administración debe crearla en Estudio de voz. La IA puede seguir respondiendo normalmente.');
      final result = await _voice.synthesize(_parts[part]);
      if (result == null) throw const CustomVoiceException('No se generó la voz personalizada. Revisa la activación del servicio; no se sustituirá por otra voz sin avisarte.');
      if (mounted && epoch == _generation) setState(() => _audio[part] = result);
    } catch (e) {if (mounted && epoch == _generation) setState(() => _error = e is CustomVoiceException ? e.message : 'No se pudo generar el audio. Revisa el servicio de voz y vuelve a intentar.');}
    finally {if (mounted && epoch == _generation) setState(() => _busy = false);}
  }
  Future<void> _listen() async {
    final audio = _audio[_part];
    if (audio == null) return;
    try {
      if (_playing) {await _player.pause(); if (mounted) setState(() => _playing = false); return;}
      await _player.setPlaybackRate(1.0);
      if (!mounted) return;
      await _player.play(BytesSource(audio.bytes, mimeType: audio.mimeType));
      if (mounted) setState(() => _playing = true);
    } catch (_) {if (mounted) setState(() => _error = 'No se pudo reproducir. Revisa el volumen y toca Escuchar otra vez.');}
  }
  void _move(int index) {++_generation; unawaited(_player.stop()); setState(() {_part = index; _playing = false; _error = null;});}
  @override
  Widget build(BuildContext context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Expanded(child: Text('Voz oficial · Sauna Stilo', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), IconButton(tooltip: 'Cerrar voz', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
    const Text('Voz sintética autorizada por Ángel. El audio se genera únicamente al tocar el botón; requiere servicio activo.', style: TextStyle(color: Colors.white60, height: 1.4)),
    const SizedBox(height: 16),
    if (_parts.isNotEmpty) Text(_parts[_part], style: const TextStyle(height: 1.5)),
    if (_parts.length > 1) Row(children: [IconButton(tooltip: 'Parte anterior', onPressed: _busy || _part == 0 ? null : () => _move(_part - 1), icon: const Icon(Icons.chevron_left)), Expanded(child: Text('Parte ${_part + 1} de ${_parts.length}', textAlign: TextAlign.center)), IconButton(tooltip: 'Parte siguiente', onPressed: _busy || _part == _parts.length - 1 ? null : () => _move(_part + 1), icon: const Icon(Icons.chevron_right))]),
    if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
    const SizedBox(height: 16),
    if (_busy) const Center(child: CircularProgressIndicator())
    else if (_audio.containsKey(_part)) FilledButton.icon(onPressed: _listen, icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded), label: const Text('Escuchar con voz de Ángel'))
    else FilledButton.icon(onPressed: _parts.isEmpty ? null : _generate, icon: const Icon(Icons.graphic_eq_rounded), label: const Text('Generar con voz oficial')),
    const SizedBox(height: 8), const Text('No se utiliza ni comparte tu sesión con el sitio de la guía.', style: TextStyle(color: Colors.white38, fontSize: 11)),
  ])));
}
List<String> splitVoiceReply(String text) {
  var rest = text.trim(); final parts = <String>[];
  while (rest.isNotEmpty) {
    var end = rest.length > 900 ? 900 : rest.length;
    if (end < rest.length) {final gap = rest.lastIndexOf(' ', end); if (gap >= 600) end = gap;}
    parts.add(rest.substring(0, end).trim()); rest = rest.substring(end).trimLeft();
  }
  return parts;
}
