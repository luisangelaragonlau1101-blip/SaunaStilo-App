import '../widgets/payroll_recognitions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';
import '../services/attendance_history_service.dart';
import '../services/attendance_gateway_service.dart';
import '../services/recorded_streak.dart';

class PayrollRecordsScreen extends StatefulWidget {
  final UserModel user;
  const PayrollRecordsScreen({super.key, required this.user});
  @override State<PayrollRecordsScreen> createState() => _PayrollRecordsState();
}
class _PayrollRecordsState extends State<PayrollRecordsScreen> {
  late final _history = AttendanceHistoryService.watch(widget.user.id);
  late DateTime _week = DateTime(AttendanceGatewayService.today.year, AttendanceGatewayService.today.month, AttendanceGatewayService.today.day).subtract(Duration(days: AttendanceGatewayService.today.weekday - 1));
  String hour(DateTime? time) => time == null ? '—' : DateFormat('HH:mm').format(time.toUtc().subtract(const Duration(hours: 6)));
  String money(num value) => '\$${value.toStringAsFixed(2)}';
  DateTime day(AsistenciaModel row) { final d = row.fecha.toUtc().subtract(const Duration(hours: 6)); return DateTime(d.year, d.month, d.day); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Nómina y registros'), actions: [IconButton(tooltip: 'Actualizar', onPressed: AttendanceGatewayService.refresh, icon: const Icon(Icons.refresh))]), body: StreamBuilder<AttendanceHistory>(stream: _history, builder: (c,s) {
    if (s.hasError) return const Center(child: Text('No se pudo consultar tu historial. Vuelve a abrir esta pantalla.'));
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    final history = s.data!;
    final rows = history.rows.where((r) => !day(r).isBefore(_week) && day(r).isBefore(_week.add(const Duration(days: 7)))).toList();
    final streak = RecordedStreak.from(history.rows.map((r) => AttendancePoint(day(r), r.estatus)).toList());
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(widget.user.nombre, style: Theme.of(context).textTheme.headlineSmall),
      Text('Sueldo semanal configurado: ${money(widget.user.sueldoBaseSemanal ?? 0)}'),
      const Text('Detalle de registros para nómina. Los importes mostrados son los guardados por Administración; no son un comprobante de pago.', style: TextStyle(color: Colors.white60)),
      PayrollRecognitions(profileId: widget.user.id),
      Text('Racha registrada: ${streak.current} · Mejor racha: ${streak.best}'),
      Row(children: [IconButton(onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)), Expanded(child: Text('${DateFormat('dd/MM').format(_week)} – ${DateFormat('dd/MM/yyyy').format(_week.add(const Duration(days: 6)))}', textAlign: TextAlign.center)), IconButton(onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right))]),
      if (history.notice != null) Text(history.notice!, style: const TextStyle(color: Colors.orangeAccent)),
      if (history.cached) const Text('Copia local: pendiente de actualizar.'),
      if (rows.isEmpty) const ListTile(title: Text('No hay registros en esta semana.')),
      for (final row in rows) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${DateFormat('dd/MM/yyyy').format(day(row))} · ${row.estatus.replaceAll('_', ' ')}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Entrada ${hour(row.horaEntrada)} · Salida ${hour(row.horaSalida)}'),
        Text('Comida ${hour(row.salidaComidaReal)} · Regreso ${hour(row.regresoComidaReal)}'),
        for (final bonus in row.listaBonos ?? <Map<String,dynamic>>[]) Text('Bono +${money(bonus['monto'] as num? ?? 0)} · ${bonus['motivo'] ?? ''}'),
        for (final fine in row.listaMultas ?? <Map<String,dynamic>>[]) Text('Descuento −${money(fine['monto'] as num? ?? 0)} · ${fine['motivo'] ?? ''}'),
        if (row.observacionesAdmin.isNotEmpty) Text('Administración: ${row.observacionesAdmin}'),
      ]))),
    ]);
  }));
}
