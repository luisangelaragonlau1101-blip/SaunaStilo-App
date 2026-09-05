import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';

import '../models/user_model.dart';
import '../services/custom_voice_service.dart';
import '../services/media_upload_service.dart';

class VozAdministracionScreen extends StatefulWidget {
  final UserModel usuario;

  const VozAdministracionScreen({super.key, required this.usuario});

  @override
  State<VozAdministracionScreen> createState() =>
      _VozAdministracionScreenState();
}

enum _VoiceSlot { consent, reference }

class _VozAdministracionScreenState extends State<VozAdministracionScreen> {
  static const _bg = Color(0xFF05070A);
  static const _panel = Color(0xFF11161C);
  static const _cyan = Color(0xFF86E9FF);
  static const _mint = Color(0xFFA8F6D5);
  static const _violet = Color(0xFFB8A7FF);
  static const _consentText =
      'Soy el propietario de esta voz y doy mi consentimiento para que Google la utilice para crear un modelo de voz sintética.';

  final _voice = CustomVoiceService();
  final _media = MediaUploadService();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  StreamSubscription<Uint8List>? _stream;
  Timer? _timer;
  BytesBuilder _bytes = BytesBuilder(copy: false);
  _VoiceSlot? _recording;
  int _seconds = 0;
  Uint8List? _consentAudio;
  Uint8List? _referenceAudio;
  AdminVoiceStatus? _status;
  bool _busy = false;
  String? _message;

  bool get _admin => widget.usuario.rol == AppRoles.admin;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stream?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (!_admin) return;
    try {
      final status = await _voice.status();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is CustomVoiceException
              ? error.message
              : 'No pude consultar el estado del servicio de voz.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_admin) {
      return const Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Este estudio de voz está disponible únicamente para Administración.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Estudio de voz',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _hero(),
          const SizedBox(height: 14),
          _statusCard(),
          const SizedBox(height: 14),
          _recordCard(
            slot: _VoiceSlot.consent,
            step: '01',
            title: 'Consentimiento',
            detail:
                'Graba exactamente esta frase. El proveedor exige este consentimiento para crear la voz sintética.',
            script: _consentText,
            bytes: _consentAudio,
            color: _violet,
          ),
          const SizedBox(height: 12),
          _recordCard(
            slot: _VoiceSlot.reference,
            step: '02',
            title: 'Muestra de tu voz',
            detail:
                'Habla natural, con energía y pausas. Acércate a 10 segundos y evita ruido de fondo.',
            script:
                'Ejemplo: “Hola equipo, soy Ángel. Estoy aquí para ayudarles a trabajar mejor, resolver dudas y avanzar cada proyecto con calidad.”',
            bytes: _referenceAudio,
            color: _cyan,
          ),
          const SizedBox(height: 16),
          _activateCard(),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _messageCard(_message!),
          ],
          const SizedBox(height: 18),
          Text(
            'Si Instant Custom Voice todavía no está autorizado en Google Cloud, Sauna IA seguirá usando la voz del dispositivo. La app no mostrará tu voz como activa hasta recibir confirmación real del servidor.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10.8,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF182533), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _cyan.withOpacity(.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: const LinearGradient(colors: [_cyan, _violet]),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.black,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU VOZ. TODA LA APP.',
                  style: GoogleFonts.inter(
                    color: _cyan,
                    fontSize: 9.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Haz que Sauna IA hable como tú.',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final status = _status;
    final active = status?.enabled == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? _mint : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status?.message ?? 'Consultando estado de la voz…',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy ? null : _loadStatus,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _recordCard({
    required _VoiceSlot slot,
    required String step,
    required String title,
    required String detail,
    required String script,
    required Uint8List? bytes,
    required Color color,
  }) {
    final recording = _recording == slot;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$step · ${title.toUpperCase()}',
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              script,
              style: GoogleFonts.inter(
                color: Colors.white78,
                fontSize: 12.2,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || (_recording != null && !recording)
                      ? null
                      : () => recording
                          ? _stopRecording()
                          : _startRecording(slot),
                  style: FilledButton.styleFrom(
                    backgroundColor: recording ? Colors.redAccent : color,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  label: Text(
                    recording
                        ? 'DETENER · ${10 - _seconds}s'
                        : bytes == null
                            ? 'GRABAR'
                            : 'VOLVER A GRABAR',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (bytes != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Escuchar grabación',
                  onPressed: () => _player.play(BytesSource(bytes)),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _activateCard() {
    final ready = _consentAudio != null && _referenceAudio != null;
    final configured = _status?.configured == true;
    final enabled = _status?.enabled == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1817),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _mint.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '03 · ACTIVAR EN SAUNA STILO',
            style: GoogleFonts.inter(
              color: _mint,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            configured
                ? 'Ya existe una voz configurada. Puedes probarla, pausarla o reemplazarla por nuevas grabaciones.'
                : 'Cuando estén listas las dos grabaciones, el servidor solicitará la creación de tu voz personalizada.',
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          if (!configured)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ready && !_busy ? _enroll : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _mint,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 50),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _busy ? 'CREANDO VOZ…' : 'CREAR MI VOZ',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _testVoice,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('PROBAR MI VOZ'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _toggleEnabled(!enabled),
                  icon: Icon(
                    enabled
                        ? Icons.pause_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(enabled ? 'DESACTIVAR' : 'ACTIVAR'),
                ),
                if (ready)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _enroll,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('REEMPLAZAR VOZ'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171319),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _violet.withOpacity(.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _violet),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording(_VoiceSlot slot) async {
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      setState(() {
        _message = 'Activa el permiso de micrófono para grabar tu voz.';
      });
      return;
    }
    await _player.stop();
    try {
      _bytes = BytesBuilder(copy: false);
      _seconds = 0;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 24000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _stream = stream.listen(_bytes.add);
      setState(() {
        _recording = slot;
        _message = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 10) unawaited(_stopRecording());
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Este dispositivo no permitió iniciar la grabación.';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    final slot = _recording;
    if (slot == null) return;
    _timer?.cancel();
    await _recorder.stop();
    await _stream?.cancel();
    final pcm = _bytes.takeBytes();
    final wav = pcm.isEmpty
        ? null
        : _createWav(pcm, sampleRate: 24000, channels: 1);
    if (!mounted) return;
    setState(() {
      _recording = null;
      if (wav == null || wav.length < 8000) {
        _message =
            'La grabación quedó demasiado corta. Graba de nuevo acercándote a 10 segundos.';
      } else if (slot == _VoiceSlot.consent) {
        _consentAudio = wav;
      } else {
        _referenceAudio = wav;
      }
    });
  }

  Future<void> _enroll() async {
    final consent = _consentAudio;
    final reference = _referenceAudio;
    if (consent == null || reference == null || _busy) return;
    setState(() {
      _busy = true;
      _message = 'Subiendo las dos grabaciones de forma segura…';
    });
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final consentUpload = await _media.upload(
        bytes: consent,
        fileName: 'consentimiento_$stamp.wav',
        contentType: 'audio/wav',
        folder: 'voz_administracion/consentimiento',
      );
      final referenceUpload = await _media.upload(
        bytes: reference,
        fileName: 'referencia_$stamp.wav',
        contentType: 'audio/wav',
        folder: 'voz_administracion/referencia',
      );
      final status = await _voice.enroll(
        consentUrl: consentUpload.url,
        referenceUrl: referenceUpload.url,
        languageCode: 'es-US',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = status;
        _message = status.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error is CustomVoiceException
            ? error.message
            : 'No se pudo crear la voz. Revisa la conexión y la configuración de Google Cloud.';
      });
    }
  }

  Future<void> _testVoice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = 'Generando una prueba con tu voz…';
    });
    try {
      final audio = await _voice.synthesize(
        'Hola equipo. Soy la voz oficial de Sauna Stilo. Estoy aquí para ayudarles a trabajar mejor y avanzar cada proyecto.',
      );
      if (audio == null) {
        throw const CustomVoiceException(
          'La voz está configurada, pero el servicio de síntesis todavía no está disponible.',
        );
      }
      await _player.play(BytesSource(audio.bytes));
      if (mounted) setState(() => _message = 'Prueba generada correctamente.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is CustomVoiceException
              ? error.message
              : 'No pude reproducir la prueba de voz.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await _voice.setEnabled(enabled);
      if (mounted) {
        setState(() {
          _status = status;
          _message = status.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is CustomVoiceException
              ? error.message
              : 'No pude cambiar el estado de la voz.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
      final data = ascii.encode(value);
      for (var index = 0; index < data.length; index++) {
        header.setUint8(offset + index, data[index]);
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
    final builder = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm);
    return builder.takeBytes();
  }
}
