import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../services/chat_audio_capture_stub.dart'
    if (dart.library.js_interop) '../services/chat_audio_capture_web.dart' as capture;

typedef AudioNoteReady = Future<void> Function(Uint8List wav, int durationSeconds);

class AudioNoteButton extends StatelessWidget {
  final AudioNoteReady onAudioReady;
  final Color color;
  final double iconSize;
  final int maximumSeconds;
  const AudioNoteButton({super.key, required this.onAudioReady,
    this.color = const Color(0xFFB7FF2A), this.iconSize = 24, this.maximumSeconds = 180});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Grabar audio', color: color, iconSize: iconSize,
    icon: const Icon(Icons.mic_rounded),
    onPressed: () => showModalBottomSheet<void>(context: context,
      isScrollControlled: true, useSafeArea: true, isDismissible: false, enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => AudioNoteComposer(onAudioReady: onAudioReady, color: color,
        maximumSeconds: maximumSeconds.clamp(1, 180))),
  );
}

/// Explicit record → review → send. A failed send keeps the recording for retry.
class AudioNoteComposer extends StatefulWidget {
  final AudioNoteReady onAudioReady;
  final Color color;
  final int maximumSeconds;
  const AudioNoteComposer({super.key, required this.onAudioReady,
    this.color = const Color(0xFFB7FF2A), this.maximumSeconds = 180});
  @override
  State<AudioNoteComposer> createState() => _AudioNoteComposerState();
}
class _AudioNoteComposerState extends State<AudioNoteComposer> with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  late final _web = capture.ChatAudioCapture();
  StreamSubscription<Uint8List>? _stream;
  StreamSubscription<void>? _complete;
  Timer? _timer;
  BytesBuilder _pcm = BytesBuilder(copy: false);
  Uint8List? _wav;
  int _seconds = 0;
  bool _recording = false, _busy = false, _playing = false;
  String? _error;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _complete = _player.onPlayerComplete.listen((_) {if (mounted) setState(() => _playing = false);});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_recording && !_busy) unawaited(_stop());
      unawaited(_player.pause());
      if (mounted) setState(() => _playing = false);
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); _timer?.cancel();
    _stream?.cancel(); _complete?.cancel(); unawaited(_web.dispose());
    _recorder.dispose(); _player.dispose(); super.dispose();
  }
  Future<void> _start() async {
    if (_busy || _recording) return;
    setState(() {_busy = true; _error = null; _playing = false;});
    try {
      await _player.stop(); _pcm = BytesBuilder(copy: false);
      if (capture.isWebCapture) {
        await _web.start(widget.maximumSeconds);
      } else {
        if (!await _recorder.hasPermission()) throw StateError('Autoriza el micrófono para grabar.');
        final input = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits,
          sampleRate: 24000, numChannels: 1, autoGain: true, echoCancel: true, noiseSuppress: true));
        _stream = input.listen((chunk) {if (_pcm.length < 24000 * 2 * widget.maximumSeconds) _pcm.add(chunk);});
      }
      if (!mounted) {await _web.dispose(); await _recorder.stop(); return;}
      setState(() {_wav = null; _seconds = 0; _recording = true; _busy = false;});
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= widget.maximumSeconds) unawaited(_stop());
      });
    } catch (_) {
      if (mounted) setState(() {_busy = false; _error = 'No se inició el micrófono. Autoriza su uso en este sitio y vuelve a tocar Grabar.';});
    }
  }
  Future<void> _stop() async {
    if (!_recording || _busy) return;
    _timer?.cancel(); setState(() {_busy = true; _recording = false;});
    try {
      Uint8List wav;
      if (capture.isWebCapture) {wav = await _web.stop();}
      else {
        await _recorder.stop(); await _stream?.cancel();
        final all = _pcm.takeBytes();
        final limit = (widget.maximumSeconds * 48000).clamp(0, all.length);
        wav = createAudioNoteWav(Uint8List.sublistView(all, 0, limit - limit % 2));
      }
      final seconds = (wav.length - 44) / 48000;
      if (seconds < 1 || seconds > widget.maximumSeconds + .1) throw StateError('Invalid duration');
      if (mounted) setState(() {_wav = wav; _seconds = seconds.ceil(); _error = null;});
    } catch (_) {if (mounted) setState(() => _error = 'La grabación quedó vacía o fue interrumpida. Graba al menos un segundo.');}
    finally {if (mounted) setState(() => _busy = false);}
  }
  Future<void> _listen() async {
    if (_busy || _wav == null) return;
    try {
      if (_playing) {await _player.pause(); if (mounted) setState(() => _playing = false); return;}
      await _player.setPlaybackRate(1.0);
      if (!mounted) return;
      await _player.play(BytesSource(_wav!, mimeType: 'audio/wav'));
      if (mounted) setState(() => _playing = true);
    } catch (_) {if (mounted) setState(() => _error = 'No se pudo escuchar la muestra. Toca de nuevo para reintentar.');}
  }
  Future<void> _send() async {
    final wav = _wav;
    if (_busy || wav == null) return;
    setState(() {_busy = true; _error = null; _playing = false;});
    try {
      await _player.stop();
      await widget.onAudioReady(wav, _seconds);
      if (mounted) Navigator.pop(context);
    } catch (_) {if (mounted) setState(() {_busy = false; _error = 'No se confirmó el envío. Tu audio sigue aquí: revisa Internet y toca Enviar otra vez.';});}
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: SafeArea(child: SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(24, 22, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [const Expanded(child: Text('Tu voz, cerca del equipo', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        IconButton(tooltip: 'Cancelar audio', onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
      const SizedBox(height: 12),
      Icon(_recording ? Icons.mic_rounded : Icons.graphic_eq_rounded, color: _recording ? Colors.redAccent : widget.color, size: 52),
      const SizedBox(height: 12), Text('${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(_recording ? 'Grabando. Toca Detener cuando termines.' : _wav != null ? 'Escucha antes de enviar. Todavía no se ha enviado.' : 'Toca Grabar y permite el micrófono. Hasta ${widget.maximumSeconds ~/ 60} minutos.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.5)),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Semantics(liveRegion: true, child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)))),
      const SizedBox(height: 18),
      if (_busy) const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator()),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
        OutlinedButton.icon(onPressed: _busy ? null : _recording ? _stop : _start, icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded), label: Text(_recording ? 'Detener' : _wav == null ? 'Grabar' : 'Volver a grabar')),
        if (_wav != null && !_recording) ...[
          OutlinedButton.icon(onPressed: _busy ? null : _listen, icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded), label: const Text('Escuchar')),
          FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded), label: const Text('Enviar audio')),
        ],
      ]),
    ]),
  )));
}

Uint8List createAudioNoteWav(Uint8List pcm) {
  final header = ByteData(44);
  void text(int offset, String s) {final b = ascii.encode(s); for (var i = 0; i < b.length; i++) {header.setUint8(offset + i, b[i]);}}
  text(0, 'RIFF'); header.setUint32(4, 36 + pcm.length, Endian.little); text(8, 'WAVE'); text(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); header.setUint16(20, 1, Endian.little); header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 24000, Endian.little); header.setUint32(28, 48000, Endian.little);
  header.setUint16(32, 2, Endian.little); header.setUint16(34, 16, Endian.little); text(36, 'data'); header.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)..add(header.buffer.asUint8List())..add(pcm)).takeBytes();
}
