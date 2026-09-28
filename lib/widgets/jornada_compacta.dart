import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../screens/jornada_screen.dart';
import '../services/asistencia_service.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';

String mexicoDayKey(DateTime now) => DateFormat('yyyyMMdd').format(now.toUtc().subtract(const Duration(hours: 6)));

class JornadaCompacta extends StatefulWidget {
  final UserModel usuario;
  final VoidCallback? onExitConfirmed;
  final AsistenciaService? service;
  final bool showDetails;
  const JornadaCompacta({super.key, required this.usuario, this.onExitConfirmed, this.service, this.showDetails = true});
  @override
  State<JornadaCompacta> createState() => _JornadaCompactaState();
}

class _JornadaCompactaState extends State<JornadaCompacta> with WidgetsBindingObserver {
  late AsistenciaService _service;
  Stream<Map<String, dynamic>>? _journal;
  Map<String, dynamic>? _confirmed;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }
  void _connect() {
    _service = widget.service ?? AsistenciaService();
    _confirmed = null;
    _journal = widget.usuario.rol == AppRoles.admin ? null : _service.gateway.watchDay(widget.usuario.id);
  }
  @override
  void didUpdateWidget(covariant JornadaCompacta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id || oldWidget.usuario.rol != widget.usuario.rol || oldWidget.service != widget.service) _connect();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AttendanceGatewayService.refresh();
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  String _hour(dynamic value) => value is Timestamp
      ? DateFormat('HH:mm').format(value.toDate().toUtc().subtract(const Duration(hours: 6))) : '—';

  Future<void> _register(String action) async {
    if (_busy || widget.usuario.rol == AppRoles.admin) return;
    if (action == 'salida') {
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('¿Registrar tu salida?'),
        content: const Text('Se guardará la hora actual y finalizará tu jornada.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar salida'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _service.registrarMovimiento(action);
      if (result['exito'] != true) throw StateError('No se confirmó el movimiento. Actualiza tu jornada.');
      if (!mounted) return;
      setState(() => _confirmed = result);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['mensaje']?.toString() ?? 'Registro guardado.')));
      if (action == 'salida') widget.onExitConfirmed?.call();
    } catch (error) {
      if (mounted) setState(() => _error = CompanyLearningService.message(error));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.rol == AppRoles.admin) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>>(
      stream: _journal,
      builder: (context, snapshot) {
        final live = snapshot.data;
        // Prefer the write's confirmed readback until the stream catches up.
        if (_confirmed != null && live != null) {
          final saved = _confirmed!['data'] as Map;
          final current = live['data'] as Map;
          if (_confirmed!['day'] != live['day'] || ['horaEntrada', 'salidaComidaSolicitada', 'regresoComidaReal', 'horaSalida'].every((k) => saved[k] == null || current[k] != null)) _confirmed = null;
        }
        final record = _confirmed ?? live;
        final data = Map<String, dynamic>.from(record?['data'] as Map? ?? {});
        final entered = data['horaEntrada'] is Timestamp;
        final left = data['horaSalida'] is Timestamp;
        final mealStarted = data['salidaComidaReal'] is Timestamp;
        final mealReturned = data['regresoComidaReal'] is Timestamp;
        final mealPending = data['salidaComidaSolicitada'] is Timestamp && !mealStarted;
        final ready = record != null && !snapshot.hasError && !_busy;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF111012), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF452332))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Icon(Icons.fingerprint_rounded, color: Color(0xFFB7FF2A)), const SizedBox(width: 9),
              const Expanded(child: Text('Mi jornada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Actualizar jornada', onPressed: _busy ? null : AttendanceGatewayService.refresh, icon: const Icon(Icons.refresh_rounded))]),
            Text(left ? 'FINALIZADA' : entered ? 'EN CURSO' : 'HOY', style: const TextStyle(color: Color(0xFFB7FF2A), fontSize: 11)),
            const SizedBox(height: 12),
            Wrap(spacing: 20, runSpacing: 8, children: [Text('Entrada ${_hour(data['horaEntrada'])}', style: const TextStyle(fontSize: 19)), Text('Salida ${_hour(data['horaSalida'])}', style: const TextStyle(fontSize: 19))]),
            const SizedBox(height: 6),
            Text('Horario: ${widget.usuario.horaEntrada ?? '09:00'}–${widget.usuario.horaSalida ?? '19:00'} · Ciudad de México', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 14),
            FilledButton.icon(key: const ValueKey('attendance-entry'), onPressed: ready && !entered ? () => _register('entrada') : null, icon: const Icon(Icons.login_rounded), label: Text(entered ? 'Entrada registrada' : 'Registrar entrada')),
            if (entered) ...[
              const SizedBox(height: 16),
              const Text('Hora de comida', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Salida ${_hour(data['salidaComidaReal'])} · Regreso ${_hour(data['regresoComidaReal'])}', style: const TextStyle(color: Colors.white70)),
              if (!left && !mealStarted && !mealPending)
                OutlinedButton.icon(key: const ValueKey('attendance-meal'), onPressed: ready ? () => _register('solicitar_comida') : null, icon: const Icon(Icons.restaurant_rounded), label: const Text('Solicitar hora de comida')),
              if (mealPending) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Solicitud guardada. Espera la autorización de Administración.', style: TextStyle(color: Color(0xFFFFB876)))),
              if (!left && mealStarted && !mealReturned)
                FilledButton.icon(key: const ValueKey('attendance-return'), onPressed: ready ? () => _register('regreso_comida') : null, icon: const Icon(Icons.keyboard_return_rounded), label: const Text('Ya regresé de comer')),
              if (mealReturned) const Text('Regreso de comida registrado', style: TextStyle(color: Color(0xFFB7FF2A))),
              const SizedBox(height: 12),
              OutlinedButton.icon(key: const ValueKey('attendance-exit'), onPressed: ready && !left ? () => _register('salida') : null, icon: const Icon(Icons.logout_rounded), label: Text(left ? 'Salida registrada' : 'Registrar salida')),
            ],
            if (_busy || snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator()),
            if (record?['pendingSync'] == true) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Horario guardado. Se actualizará en nómina cuando Administración abra Asistencias.', style: TextStyle(color: Colors.white60, fontSize: 12))),
            if (snapshot.hasError || _error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Semantics(liveRegion: true, child: Text(_error ?? CompanyLearningService.message(snapshot.error!), style: const TextStyle(color: Colors.orangeAccent)))),
            if (widget.showDetails) TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => JornadaScreen(usuario: widget.usuario))), child: const Text('Comida, historial y detalles')),
          ]),
        );
      },
    );
  }
}
