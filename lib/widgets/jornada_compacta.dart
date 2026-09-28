import '../presentation/appearance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../screens/payroll_records_screen.dart';
import '../services/asistencia_service.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';

String mexicoDayKey(DateTime now) => DateFormat('yyyyMMdd').format(now.toUtc().subtract(Duration(hours: 6)));

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
  bool _manual = false;
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
    _journal = _service.gateway.watchDay(widget.usuario.id);
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
      ? DateFormat('HH:mm').format(value.toDate().toUtc().subtract(Duration(hours: 6))) : '—';

  Future<void> _register(String action) async {
    if (_busy || (widget.usuario.rol == AppRoles.admin && !_manual)) return;
    if (action == 'salida') {
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: Text('¿Registrar tu salida?'),
        content: Text('Se guardará la hora actual y finalizará tu jornada.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('Confirmar salida'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _service.registrarMovimiento(action, manual: _manual);
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
    Theme.of(context);
    return StreamBuilder<Map<String, dynamic>>(
      stream: _journal,
      builder: (context, snapshot) {
        final live = snapshot.data;
        // Prefer the write's confirmed readback until the stream catches up.
        if (_confirmed != null && live != null) {
          final saved = _confirmed!['data'] as Map;
          final current = live['data'] as Map;
          if (_confirmed!['day'] != live['day'] || ['horaEntrada', 'salidaComidaSolicitada', 'salidaComidaReal', 'regresoComidaReal', 'horaSalida'].every((k) => saved[k] == null || current[k] != null)) _confirmed = null;
        }
        final record = _confirmed ?? live;
        final data = Map<String, dynamic>.from(record?['data'] as Map? ?? {});
        final entered = data['horaEntrada'] is Timestamp;
        final left = data['horaSalida'] is Timestamp;
        final mealStarted = data['salidaComidaReal'] is Timestamp;
        final mealReturned = data['regresoComidaReal'] is Timestamp;
        final mealPending = data['salidaComidaSolicitada'] is Timestamp && !mealStarted;
        _manual = record?['supportsManual'] == true;
        final ready = record != null && !snapshot.hasError && !_busy && (widget.usuario.rol != AppRoles.admin || _manual);
        return Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: StiloColors.surface)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(Icons.fingerprint_rounded, color: StiloColors.accent), SizedBox(width: 9),
              Expanded(child: Text('Mi jornada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Actualizar jornada', onPressed: _busy ? null : AttendanceGatewayService.refresh, icon: Icon(Icons.refresh_rounded))]),
            Text(left ? 'FINALIZADA' : entered ? 'EN CURSO' : 'HOY', style: TextStyle(color: StiloColors.accent, fontSize: 11)),
            SizedBox(height: 12),
            Wrap(spacing: 20, runSpacing: 8, children: [Text('Entrada ${_hour(data['horaEntrada'])}', style: TextStyle(fontSize: 19)), Text('Salida ${_hour(data['horaSalida'])}', style: TextStyle(fontSize: 19))]),
            SizedBox(height: 6),
            Text('Horario: ${widget.usuario.horaEntrada ?? '09:00'}–${widget.usuario.horaSalida ?? '19:00'} · Ciudad de México', style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 11)),
            SizedBox(height: 14),
            if (_manual) Text('Registro manual con hora del servidor. No solicita ubicación.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), fontSize: 12)),
            if (!_manual && widget.usuario.rol == AppRoles.admin) Text('Tu registro personal sencillo está pendiente de la actualización del servicio.', style: TextStyle(color: Colors.orangeAccent)),
            FilledButton.icon(key: ValueKey('attendance-entry'), onPressed: ready && !entered ? () => _register('entrada') : null, icon: Icon(Icons.login_rounded), label: Text(entered ? 'Entrada registrada' : 'Registrar entrada')),
            if (entered) ...[
              SizedBox(height: 16),
              Text('Hora de comida', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Salida ${_hour(data['salidaComidaReal'])} · Regreso ${_hour(data['regresoComidaReal'])}', style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
              if (!left && !mealStarted && (!mealPending || _manual))
                OutlinedButton.icon(key: ValueKey('attendance-meal'), onPressed: ready ? () => _register(_manual ? 'salida_comida' : 'solicitar_comida') : null, icon: Icon(Icons.restaurant_rounded), label: Text(_manual ? 'Salir a comer' : 'Solicitar hora de comida')),
              if (mealPending && !_manual) Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Solicitud guardada. Espera la autorización de Administración.', style: TextStyle(color: Color(0xFFFFB876)))),
              if (!left && mealStarted && !mealReturned)
                FilledButton.icon(key: ValueKey('attendance-return'), onPressed: ready ? () => _register('regreso_comida') : null, icon: Icon(Icons.keyboard_return_rounded), label: Text('Ya regresé de comer')),
              if (mealReturned) Text('Regreso de comida registrado', style: TextStyle(color: StiloColors.accent)),
              SizedBox(height: 12),
              OutlinedButton.icon(key: ValueKey('attendance-exit'), onPressed: ready && !left ? () => _register('salida') : null, icon: Icon(Icons.logout_rounded), label: Text(left ? 'Salida registrada' : 'Registrar salida')),
            ],
            if (_busy || snapshot.connectionState == ConnectionState.waiting) Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator()),
            if (record?['pendingSync'] == true) Padding(padding: EdgeInsets.only(top: 10), child: Text('Horario guardado. Se actualizará en nómina cuando Administración abra Asistencias.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), fontSize: 12))),
            if (snapshot.hasError || _error != null) Padding(padding: EdgeInsets.only(top: 12), child: Semantics(liveRegion: true, child: Text(_error ?? CompanyLearningService.message(snapshot.error!), style: TextStyle(color: Colors.orangeAccent)))),
            if (widget.showDetails) TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayrollRecordsScreen(user: widget.usuario))), child: Text('Ver mis registros y nómina')),
          ]),
        );
      },
    );
  }
}
