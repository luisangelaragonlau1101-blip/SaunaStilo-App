import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../screens/trabajador_asistencia_screen.dart';

String mexicoDayKey(DateTime now) => DateFormat('yyyyMMdd').format(now.toUtc().subtract(const Duration(hours: 6)));

class JornadaCompacta extends StatefulWidget {
  final UserModel usuario;
  const JornadaCompacta({super.key, required this.usuario});
  @override
  State<JornadaCompacta> createState() => _JornadaCompactaState();
}
class _JornadaCompactaState extends State<JornadaCompacta> {
  bool _busy = false;
  String? _error;
  late String _day;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _day = mexicoDayKey(DateTime.now());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      final day = mexicoDayKey(DateTime.now());
      if (mounted && day != _day) setState(() => _day = day);
    });
  }
  @override
  void dispose() { _clock?.cancel(); super.dispose(); }
  String _hour(dynamic value) => value is Timestamp ? DateFormat('HH:mm').format(value.toDate().toUtc().subtract(const Duration(hours: 6))) : '—';
  Future<void> _register(String action) async {
    if (_busy) return;
    if (action == 'salida') {
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('¿Registrar tu salida?'), content: const Text('Se guardará la hora actual en tu jornada de hoy.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Registrar salida'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Activa la ubicación del teléfono para registrar tu jornada.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('Autoriza la ubicación de Sauna Stilo en los ajustes del teléfono o navegador.');
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 25));
      if (position.accuracy > 60) throw StateError('La ubicación tiene poca precisión. Acércate a una zona despejada e intenta de nuevo.');
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('updateAttendance', options: HttpsCallableOptions(timeout: const Duration(seconds: 35))).call({
        'accion': action, 'latitud': position.latitude, 'longitud': position.longitude,
      });
      if (result.data is! Map || result.data['exito'] != true) throw StateError('El servidor no confirmó el registro. Revisa tu jornada antes de reintentar.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['mensaje']?.toString() ?? 'Registro confirmado por el servidor.')));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = switch (e.code) {
        'not-found' => 'El servicio de asistencia todavía no está publicado en Firebase. Administración debe activar updateAttendance; no se registró una hora local ficticia.',
        'unauthenticated' => 'Tu sesión expiró. Inicia sesión nuevamente.',
        'permission-denied' => 'No tienes autorización para registrar esta jornada. Consulta a Administración.',
        'failed-precondition' => e.message ?? 'Debes encontrarte en una zona autorizada para registrar tu jornada.',
        'deadline-exceeded' => 'No llegó la confirmación. Revisa si la hora aparece en tu jornada antes de reintentar.',
        _ => 'No se pudo comunicar con el servidor de asistencia. Revisa Internet y solicita a Administración verificar el servicio.',
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'La ubicación tardó demasiado. Revisa su permiso y vuelve a intentar.');
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo confirmar el registro. Revisa ubicación, conexión y tu jornada.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('asistencias').doc('${widget.usuario.id}_$_day').snapshots(),
    builder: (context, snapshot) {
      final data = snapshot.data?.data() ?? <String, dynamic>{};
      final entered = data['horaEntrada'] is Timestamp;
      final left = data['horaSalida'] is Timestamp;
      final ready = snapshot.hasData && !snapshot.hasError;
      return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF111012), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF452332))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.fingerprint_rounded, color: Color(0xFFB7FF2A)), const SizedBox(width: 9), const Expanded(child: Text('Mi jornada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Text(left ? 'FINALIZADA' : entered ? 'EN CURSO' : 'HOY', style: const TextStyle(color: Color(0xFFB7FF2A), fontSize: 10, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 14),
        Text('Entrada ${_hour(data['horaEntrada'])}     ·     Salida ${_hour(data['horaSalida'])}', style: const TextStyle(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 5),
        Text('Horario: ${widget.usuario.horaEntrada ?? '09:00'}–${widget.usuario.horaSalida ?? '19:00'} · hora de Ciudad de México', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        if (snapshot.hasError) const Padding(padding: EdgeInsets.only(top: 10), child: Text('No pudimos leer la jornada. Los registros no se muestran como vacíos cuando hay un error de permisos o conexión.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Semantics(liveRegion: true, child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.4)))),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: !ready || _busy || entered ? null : () => _register('entrada'), icon: const Icon(Icons.login_rounded), label: const Text('Entrada'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: !ready || _busy || !entered || left ? null : () => _register('salida'), icon: const Icon(Icons.logout_rounded), label: const Text('Salida')))]),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrabajadorAsistenciaScreen(trabajador: widget.usuario))), child: const Text('Comida, historial y detalles de jornada')),
      ]));
    },
  );
}
