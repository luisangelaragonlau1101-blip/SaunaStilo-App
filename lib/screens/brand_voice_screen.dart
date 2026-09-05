import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class BrandVoiceScreen extends StatefulWidget {
  final UserModel usuario;
  const BrandVoiceScreen({super.key, required this.usuario});
  @override
  State<BrandVoiceScreen> createState() => _BrandVoiceScreenState();
}
class _BrandVoiceScreenState extends State<BrandVoiceScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  StreamSubscription<Uint8List>? _stream;
  Timer? _timer;
  BytesBuilder _pcm = BytesBuilder(copy: false);
  Uint8List? _sample;
  int _seconds = 0;
  bool _recording = false, _busy = false, _consent = false;
  String _status = 'La muestra permanece en este dispositivo hasta que decidas activar la voz.';
  String _failure(Object error) => error is FirebaseFunctionsException && error.code == 'not-found' ? 'El servicio de voz aún no está publicado en Firebase. La grabación local y la escucha previa sí están disponibles.' : error is FirebaseFunctionsException && error.message != null ? error.message! : 'No se pudo completar la operación. Comprueba permisos y conexión.';
  void _setStatus(String value) { if (mounted) setState(() => _status = value); }
  Future<void> _start() async {
    if (_busy || _recording) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!await _recorder.hasPermission()) { _setStatus('Permite el micrófono en los ajustes de este navegador.'); return; }
      _pcm = BytesBuilder(copy: false); _seconds = 0; _sample = null;
      final stream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      if (!mounted) { await _recorder.stop(); return; }
      _stream = stream.listen((bytes) { if (_pcm.length < 2880000) _pcm.add(bytes); }, onError: (_) { _setStatus('La grabación se interrumpió. Graba una nueva muestra.'); _stop(); });
      setState(() { _recording = true; _status = 'Grabando tu voz. Habla de forma natural, sin música ni otras personas.'; });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; setState(() => _seconds++); if (_seconds >= 90) _stop(); });
    } catch (error) { _setStatus(_failure(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Uint8List _wav(Uint8List pcm) {
    final data = ByteData(44);
    void text(int offset, String value) { for (var i = 0; i < value.length; i++) { data.setUint8(offset + i, value.codeUnitAt(i)); } }
    text(0, 'RIFF'); data.setUint32(4, 36 + pcm.length, Endian.little); text(8, 'WAVE'); text(12, 'fmt '); data.setUint32(16, 16, Endian.little); data.setUint16(20, 1, Endian.little); data.setUint16(22, 1, Endian.little); data.setUint32(24, 16000, Endian.little); data.setUint32(28, 32000, Endian.little); data.setUint16(32, 2, Endian.little); data.setUint16(34, 16, Endian.little); text(36, 'data'); data.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)..add(data.buffer.asUint8List())..add(pcm)).takeBytes();
  }
  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    setState(() { _recording = false; _busy = true; });
    try { await _recorder.stop(); await _stream?.cancel(); final bytes = _pcm.takeBytes(); if (bytes.isNotEmpty) _sample = _wav(bytes); _setStatus('Muestra grabada. Escúchala antes de activar. Para activación se requieren entre 30 y 90 segundos de audio.'); }
    catch (error) { _setStatus(_failure(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _activate() async {
    if (!_consent || _sample == null || _busy) return;
    if (_sample!.length < 960044) { _setStatus('Graba por lo menos 30 segundos de voz.'); return; }
    setState(() => _busy = true);
    try { final result = await _functions.httpsCallable('saunaBrandEnroll', options: HttpsCallableOptions(timeout: const Duration(seconds: 80))).call({'audio': base64Encode(_sample!), 'consentimiento': true}); final data = Map<String, dynamic>.from(result.data as Map); _setStatus(data['mensaje']?.toString() ?? 'Solicitud procesada. Comprueba el estado de la voz.'); }
    catch (error) { _setStatus(_failure(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    try { final result = await _functions.httpsCallable('saunaBrandStatus').call(); final data = Map<String, dynamic>.from(result.data as Map); _setStatus(data['mensaje']?.toString() ?? 'Estado no disponible.'); }
    catch (error) { _setStatus(_failure(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _delete() async {
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Eliminar la voz de la marca?'), content: const Text('Se desactivará para nuevas respuestas y se eliminará el perfil del proveedor. Los audios ya reproducidos no pueden retirarse de otros dispositivos.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try { await _functions.httpsCallable('saunaBrandDelete').call(); _setStatus('Voz eliminada y desactivada.'); }
    catch (error) { _setStatus(_failure(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _timer?.cancel(); _stream?.cancel(); _recorder.dispose(); _player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.usuario.rol != AppRoles.admin) return const Scaffold(body: Center(child: Text('Acceso exclusivo de Administración.')));
    return Scaffold(appBar: AppBar(title: const Text('Voz de la marca')), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.graphic_eq_rounded, size: 70), const SizedBox(height: 22),
      const Text('Tu identidad. Tu voz.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
      const Text('Graba entre 30 y 90 segundos en un lugar silencioso. La escucha previa usa tu grabación real. Las respuestas nuevas usarán una voz sintética autorizada, no una grabación en directo.', style: TextStyle(height: 1.5, color: Color(0xFFCDD0D6))), const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1C1E23), borderRadius: BorderRadius.circular(22)), child: const Text('Texto sugerido: Hola, soy la voz de Sauna Stilo. Bienvenido a nuestro espacio de trabajo. Aquí puedes revisar tus proyectos, registrar tus tiempos y comunicarte con tu equipo. Cada detalle cuenta: el orden, la calidad y la atención hacen la diferencia. Vamos a trabajar con claridad, resolver tus dudas y mantener al día nuestros avances. Habla ahora sobre tu día, tu trabajo y lo que significa Sauna Stilo para ti.', style: TextStyle(height: 1.6))),
      const SizedBox(height: 20), Text('${_seconds.toString().padLeft(2, '0')} s', textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700)), const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: [FilledButton.icon(onPressed: _busy ? null : _recording ? _stop : _start, icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded), label: Text(_recording ? 'Detener grabación' : 'Grabar mi voz')), OutlinedButton.icon(onPressed: _sample == null || _recording || _busy ? null : () async { try { await _player.play(BytesSource(_sample!, mimeType: 'audio/wav')); } catch (_) { _setStatus('No se pudo reproducir la muestra en este navegador.'); } }, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Escuchar muestra')), TextButton(onPressed: _recording || _busy ? null : () { _player.stop(); setState(() { _sample = null; _seconds = 0; _status = 'Muestra local eliminada.'; }); }, child: const Text('Borrar muestra'))]),
      const SizedBox(height: 22),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: _consent, onChanged: _busy || _recording ? null : (value) => setState(() => _consent = value == true), title: const Text('Esta es mi propia voz. Autorizo su envío a ElevenLabs y su uso sintético para las respuestas de Sauna Stilo.', style: TextStyle(fontSize: 14, height: 1.4))),
      const Text('Requiere un servicio de voz habilitado y una cuenta de proveedor compatible. No se guardan claves en esta pantalla. Solo el titular configurado en el servidor puede activar o eliminar la voz.', style: TextStyle(fontSize: 12, color: Color(0xFFB9BDC6), height: 1.5)), const SizedBox(height: 16),
      FilledButton.icon(onPressed: _busy || _recording || !_consent || _sample == null ? null : _activate, icon: const Icon(Icons.verified_user_outlined), label: const Text('Activar mi voz en Sauna Stilo')),
      OutlinedButton(onPressed: _busy || _recording ? null : _check, child: const Text('Comprobar estado del servicio')),
      TextButton(onPressed: _busy || _recording ? null : _delete, child: const Text('Eliminar voz del servicio')),
      const SizedBox(height: 18), if (_busy) const LinearProgressIndicator(), const SizedBox(height: 12),
      Semantics(liveRegion: true, child: Text(_status, style: const TextStyle(height: 1.5, fontWeight: FontWeight.w600))),
    ])))));
  }
}
