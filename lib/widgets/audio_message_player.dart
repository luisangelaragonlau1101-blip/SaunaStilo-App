import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final int durationSeconds;
  final Color color;
  const AudioMessagePlayer({super.key, required this.url, this.durationSeconds = 0, this.color = const Color(0xFFB7FF2A)});
  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}
class _AudioMessagePlayerState extends State<AudioMessagePlayer> with WidgetsBindingObserver {
  static final _selected = StreamController<Object>.broadcast(sync: true);
  final _identity = Object();
  final _player = AudioPlayer();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Duration _position = Duration.zero, _duration = Duration.zero;
  bool _playing = false, _loading = false, _loaded = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _subscriptions.add(_player.onPlayerComplete.listen((_) {if (mounted) setState(() {_playing = false; _loaded = false; _position = Duration.zero;});}));
    _subscriptions.add(_player.onPositionChanged.listen((v) {if (mounted) setState(() => _position = v);}));
    _subscriptions.add(_player.onDurationChanged.listen((v) {if (mounted) setState(() => _duration = v);}));
    _subscriptions.add(_selected.stream.listen((owner) {if (owner != _identity) unawaited(_pause());}));
  }
  @override
  void didUpdateWidget(covariant AudioMessagePlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {++_generation; unawaited(_player.stop()); _loaded = false; _playing = false; _position = Duration.zero; _duration = Duration.zero;}
  }
  @override
  void didChangeDependencies() {super.didChangeDependencies(); if (!TickerMode.of(context)) unawaited(_pause());}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) unawaited(_pause());
  }
  @override
  void dispose() {
    ++_generation; WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {s.cancel();}
    _player.dispose(); super.dispose();
  }
  Future<void> _pause() async {
    ++_generation;
    try {await _player.pause();} catch (_) {}
    if (mounted) setState(() {_playing = false; _loading = false;});
  }
  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {await _pause(); return;}
    final token = ++_generation;
    setState(() => _loading = true);
    _selected.add(_identity);
    try {
      final uri = Uri.tryParse(widget.url);
      if (uri == null || !['https', 'http', 'blob'].contains(uri.scheme)) throw StateError('Invalid audio URL');
      await _player.setPlaybackRate(1.0);
      if (!mounted || token != _generation) return;
      if (_loaded) {await _player.resume();} else {await _player.play(UrlSource(widget.url));}
      if (!mounted || token != _generation) {await _player.pause(); return;}
      setState(() {_playing = true; _loaded = true;});
    } catch (_) {
      if (mounted) {
        _loaded = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo escuchar el audio. Revisa Internet, el volumen y toca Reproducir para reintentar.')));
      }
    } finally {if (mounted && token == _generation) setState(() => _loading = false);}
  }
  String _time(Duration d) => '${d.inSeconds ~/ 60}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final total = _duration > Duration.zero ? _duration : Duration(seconds: widget.durationSeconds);
    return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: Container(
      padding: const EdgeInsets.fromLTRB(5, 6, 10, 6),
      decoration: BoxDecoration(color: widget.color.withOpacity(.09), borderRadius: BorderRadius.circular(28), border: Border.all(color: widget.color.withOpacity(.28))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: _playing ? 'Pausar audio' : 'Reproducir audio', onPressed: _loading ? null : _toggle,
          icon: _loading ? SizedBox.square(dimension: 21, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color)) : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.color)),
        Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.graphic_eq_rounded, size: 19, color: widget.color), const SizedBox(width: 6), const Text('Nota de voz · 1×', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
          if (total.inMilliseconds > 0) SizedBox(height: 20, child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)), child: Slider(
            activeColor: widget.color, min: 0, max: total.inMilliseconds.toDouble(), value: _position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
            onChanged: !_loaded ? null : (v) async {try {await _player.seek(Duration(milliseconds: v.round()));} catch (_) {}}))),
          Text('${_time(_position)} / ${total.inSeconds > 0 ? _time(total) : 'Audio'}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ])),
      ]),
    ));
  }
}
