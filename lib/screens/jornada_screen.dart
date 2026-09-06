import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/asistencia_service.dart';
import '../services/attendance_zones.dart';
import 'trabajador_asistencia_screen.dart';

class JornadaScreen extends StatefulWidget {
  final UserModel usuario;
  const JornadaScreen({super.key, required this.usuario});
  @override
  State<JornadaScreen> createState() => _JornadaScreenState();
}
class _JornadaScreenState extends State<JornadaScreen> {
  final AsistenciaService _service = AsistenciaService();
  bool _busy = false;
  String _message = '';
  bool _error = false;
  Timer? _clock;
  @override
  void initState() { super.initState(); _clock = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _clock?.cancel(); super.dispose(); }
  DateTime get _now => DateTime.now().toUtc().subtract(const Duration(hours: 6));
  String _time(dynamic t) => t is Timestamp ? DateFormat('HH:mm').format(t.toDate().toUtc().subtract(const Duration(hours: 6))) : '—';
  Future<void> _register(String action) async {
    if (_busy || widget.usuario.rol == AppRoles.admin) return;
    if (action == 'salida') {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Registrar salida'), content: const Text('Se guardará la hora actual confirmada por el servidor.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Registrar salida'))]));
      if (ok != true || !mounted) return;
    }
    setState(() { _busy = true; _message = 'Validando ubicación y registro…'; _error = false; });
    try {
      Map<String, dynamic> result;
      if (action == 'entrada') result = await _service.registrarEntrada(zonasPermitidas: zonasAsistenciaSauna);
      else if (action == 'salida') result = await _service.registrarSalida(trabajadorId: widget.usuario.id, zonasPermitidas: zonasAsistenciaSauna, horaSalidaOficial: widget.usuario.horaSalida);
      else if (action == 'comida') { await _service.solicitarSalidaComida(widget.usuario.id); result = {'exito': true, 'mensaje': 'Solicitud de comida enviada a Administración.'}; }
      else result = await _service.registrarRegresoComida(trabajadorId: widget.usuario.id, zonasPermitidas: zonasAsistenciaSauna);
      if (result['exito'] != true) throw StateError(result['mensaje']?.toString() ?? 'No se confirmó el registro.');
      if (mounted) setState(() => _message = result['mensaje']?.toString() ?? 'Registro confirmado por el servidor.');
    } catch (error) { if (mounted) setState(() { _error = true; _message = error.toString().replaceFirst('Bad state: ', ''); }); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.usuario.rol == AppRoles.admin) return Scaffold(appBar: AppBar(title: const Text('Administración')), body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Administración no registra asistencia. Consulta las jornadas del equipo desde Inicio → Asistencias.'))));
    final key = '${widget.usuario.id}_${DateFormat('yyyyMMdd').format(_now)}';
    // Query ownership instead of reading a missing private document: absence is a valid empty state.
    final stream = FirebaseFirestore.instance.collection('asistencias').where('trabajadorId', isEqualTo: widget.usuario.id).snapshots();
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Mi jornada'), actions: [
      IconButton(tooltip: 'Historial de asistencia', onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrabajadorAsistenciaScreen(trabajador: widget.usuario))), icon: const Icon(Icons.history_rounded))]),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: stream, builder: (context, snapshot) {
        Map<String,dynamic> data = {};
        for (final d in snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String,dynamic>>>[]) { if (d.id == key) data = d.data(); }
        final entrada = data['horaEntrada'] != null;
        final salida = data['horaSalida'] != null;
        final enabled = !_busy && snapshot.hasData && !snapshot.hasError;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(DateFormat('dd/MM/yyyy · HH:mm').format(_now), style: const TextStyle(color: Color(0xFFB7FF2A), fontSize: 14)),
          const SizedBox(height: 8), const Text('Tu jornada,\ncon un toque.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12), Text('Horario asignado: ${widget.usuario.horaEntrada ?? '09:00'} — ${widget.usuario.horaSalida ?? '19:00'}\nHora de la empresa · Ciudad de México', style: const TextStyle(color: Colors.white60, height: 1.6)),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(22), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ENTRADA', style: TextStyle(color: Colors.white60)), const SizedBox(height: 8), Text(_time(data['horaEntrada']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SALIDA', style: TextStyle(color: Colors.white60)), const SizedBox(height: 8), Text(_time(data['horaSalida']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))]),
          ]))),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: enabled && !entrada ? () => _register('entrada') : null, icon: const Icon(Icons.login_rounded), label: Text(entrada ? 'Entrada registrada' : 'Registrar entrada')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: enabled && entrada && !salida ? () => _register('salida') : null, icon: const Icon(Icons.logout_rounded), label: Text(salida ? 'Salida registrada' : 'Registrar salida')),
          const SizedBox(height: 14),
          if (entrada && !salida) Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: enabled && data['salidaComidaSolicitada'] == null && data['salidaComidaReal'] == null ? () => _register('comida') : null, icon: const Icon(Icons.restaurant_outlined), label: const Text('Solicitar comida')),
            OutlinedButton.icon(onPressed: enabled && data['salidaComidaReal'] != null && data['regresoComidaReal'] == null ? () => _register('regreso') : null, icon: const Icon(Icons.keyboard_return_rounded), label: const Text('Regresé de comer')),
          ]),
          if (_busy || snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator()),
          if (snapshot.hasError) const Padding(padding: EdgeInsets.all(12), child: Text('No pudimos consultar tu asistencia. No se ha registrado ningún horario.', style: TextStyle(color: Colors.orangeAccent))),
          if (_message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Semantics(liveRegion: true, child: Text(_message, style: TextStyle(color: _error ? const Color(0xFFFF8BA5) : const Color(0xFFC6FF68), height: 1.6)))),
          const Text('La entrada y la salida requieren estar en una zona autorizada. Solo aparecerán registradas cuando el servidor confirme el horario; los permisos GPS se solicitan al registrar.', style: TextStyle(color: Colors.white54, height: 1.5)),
        ]);
      }));
  }
}
