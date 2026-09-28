import '../presentation/appearance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';

class AttendanceAdminSync extends StatefulWidget {
  final DateTime day;
  final AttendanceGatewayService? service;
  const AttendanceAdminSync({super.key, required this.day, this.service});
  @override
  State<AttendanceAdminSync> createState() => _AttendanceAdminSyncState();
}

class _AttendanceAdminSyncState extends State<AttendanceAdminSync> with WidgetsBindingObserver {
  late final AttendanceGatewayService _service = widget.service ?? AttendanceGatewayService();
  Timer? _timer;
  bool _busy = false;
  String? _error;
  String? _updatedDay;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
    _timer = Timer.periodic(Duration(seconds: 45), (_) => unawaited(_sync()));
  }
  @override
  void didUpdateWidget(covariant AttendanceAdminSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (AttendanceGatewayService.dayKey(oldWidget.day) != AttendanceGatewayService.dayKey(widget.day)) unawaited(_sync());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }
  Future<void> _sync() async {
    if (_busy) return;
    final day = AttendanceGatewayService.dayKey(widget.day);
    if (day.compareTo(AttendanceGatewayService.dayKey(AttendanceGatewayService.today)) > 0) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _service.syncDay(day);
      if (mounted) setState(() => _updatedDay = day);
    } catch (error) {
      if (mounted) setState(() => _error = CompanyLearningService.message(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (day != AttendanceGatewayService.dayKey(widget.day)) unawaited(_sync());
      }
    }
  }
  @override
  void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      if (_busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      else Icon(_error != null ? Icons.warning_amber_rounded : Icons.cloud_done_outlined, size: 20),
      SizedBox(width: 10),
      Expanded(child: Text(_busy ? 'Actualizando entradas, comidas y salidas…' : _error ?? (_updatedDay == AttendanceGatewayService.dayKey(widget.day) ? 'Movimientos actualizados para revisión y nómina.' : 'Selecciona una fecha hasta hoy.'), style: TextStyle(fontSize: 12, color: _error != null ? Colors.orangeAccent : StiloColors.text.withValues(alpha: .70)))),
      IconButton(tooltip: 'Actualizar movimientos', onPressed: _busy ? null : _sync, icon: Icon(Icons.refresh)),
    ]),
  );
}
