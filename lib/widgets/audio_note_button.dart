import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

typedef AudioNoteReady = Future<void> Function(
  Uint8List wav,
  int durationSeconds,
);

class AudioNoteButton extends StatefulWidget {
  final AudioNoteReady onAudioReady;
  final Color color;
  final double iconSize;
  final int maximumSeconds;

  const AudioNoteButton({
    super.key,
    required this.onAudioReady,
    this.color = const Color(0xFF00E5FF),
    this.iconSize = 24,
    this.maximumSeconds = 180,
  });

  @override
  State<AudioNoteButton> createState() => _AudioNoteButtonState();
}

class _AudioNoteButtonState extends State<AudioNoteButton> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSubscription;
  BytesBuilder _bytes = BytesBuilder(copy: false);
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _sending = false;

  @override
  void dispose() {
    _timer?.cancel();
    _streamSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_sending) return;
    if (_recording) {
      await _stopAndSend();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      _message('Autoriza el micrófono para enviar notas de voz.');
      return;
    }
    try {
      _bytes = BytesBuilder(copy: false);
      _seconds = 0;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _streamSubscription = stream.listen(_bytes.add);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= widget.maximumSeconds) _stopAndSend();
      });
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      _message('No se pudo iniciar la grabación en este dispositivo.');
    }
  }

  Future<void> _stopAndSend() async {
    if (!_recording) return;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _recording = false;
        _sending = true;
      });
    }
    await _recorder.stop();
    await _streamSubscription?.cancel();
    final pcm = _bytes.takeBytes();
    if (pcm.isEmpty || _seconds < 1) {
      if (mounted) setState(() => _sending = false);
      _message('El audio quedó vacío. Mantén el botón y vuelve a intentarlo.');
      return;
    }
    try {
      await widget.onAudioReady(
        _createWav(pcm, sampleRate: 16000, channels: 1),
        _seconds,
      );
    } catch (_) {
      _message('No se pudo enviar el audio. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Uint8List _createWav(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final header = ByteData(44);
    void writeText(int offset, String value) {
      final bytes = ascii.encode(value);
      for (var index = 0; index < bytes.length; index++) {
        header.setUint8(offset + index, bytes[index]);
      }
    }

    writeText(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeText(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_sending) {
      return SizedBox.square(
        dimension: 44,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
        ),
      );
    }
    return Tooltip(
      message: _recording
          ? 'Toca para enviar (${_seconds}s)'
          : 'Grabar comentario de voz',
      child: IconButton(
        onPressed: _toggle,
        iconSize: widget.iconSize,
        color: _recording ? Colors.redAccent : widget.color,
        icon: Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_rounded),
      ),
    );
  }
}
