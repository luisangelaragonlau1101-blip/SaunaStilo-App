import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/enterprise_finance_service.dart';
import '../widgets/finance_controls.dart';
import '../widgets/finance_entry_sheet.dart';

class PurchasesWorkspaceScreen extends StatefulWidget {
  const PurchasesWorkspaceScreen({super.key, required this.user, this.service, this.administrative = false});
  final UserModel user;
  final EnterpriseFinanceService? service;
  final bool administrative;
  @override State<PurchasesWorkspaceScreen> createState() => _PurchasesState();
}
class _PurchasesState extends State<PurchasesWorkspaceScreen> {
  late final EnterpriseFinanceService api = widget.service ?? EnterpriseFinanceService();
  StreamSubscription<String?>? session;
  Map<String, dynamic>? data;
  String? error;
  bool busy = true;
  @override void initState() { super.initState(); session = api.sessionChanges.listen((id) { if (id != widget.user.id && mounted) setState(() { data = null; error = 'La sesión cambió. Abre esta pantalla con tu cuenta.'; busy = false; }); }); unawaited(load()); }
  @override void dispose() { session?.cancel(); super.dispose(); }
  Future<void> load() async {
    if (mounted) setState(() { busy = true; error = null; });
    try { final result = await api.call(widget.administrative ? 'dashboard' : 'myPurchases'); if (mounted) setState(() { data = result; busy = false; }); }
    catch (e) { if (mounted) setState(() { data = null; error = EnterpriseFinanceService.message(e); busy = false; }); }
  }
  Future<void> create() async {
    final result = await showFinanceForm(context, title: 'Solicitar compra', help: 'Producto, importe estimado y para qué lo necesitas.', fields: [
      const FinanceField('producto', 'Producto'), const FinanceField('importe', 'Precio estimado', money: true), const FinanceField('motivo', 'Motivo', lines: 3),
      FinanceField('proyectoId', 'Proyecto', options: {'': 'General / sin proyecto', for (final p in financeRows(data?['projects'])) p['id'].toString(): p['titulo'].toString()}), const FinanceField('proveedor', 'Proveedor (opcional)'),
    ], save: (v, op) async { await api.call('requestPurchase', {...v, 'operationId': op, 'centavosEstimados': financeCents(v['importe'], zero: false)}); });
    if (result == true) await load();
  }
  Future<void> resolve(Map<String, dynamic> request, String state) async {
    final result = await showFinanceForm(context, title: {'aprobada': 'Aprobar compra', 'rechazada': 'Rechazar compra', 'informacion_solicitada': 'Solicitar información'}[state]!, help: '${request['producto']} · ${financeMoney(request['centavosEstimados'])}', fields: [FinanceField('comentario', state == 'aprobada' ? 'Comentario (opcional)' : 'Motivo o información necesaria', lines: 3)], saveLabel: 'Confirmar', save: (v, op) async { await api.call('resolvePurchase', {...v, 'id': request['id'], 'estado': state, 'operationId': op}); });
    if (result == true) await load();
  }
  Future<void> information(Map<String, dynamic> request) async {
    final result = await showFinanceForm(context, title: 'Responder a Administración', help: request['comentarioAdministracion']?.toString(), fields: const [FinanceField('comentario', 'Información adicional', lines: 3)], save: (v, op) async { await api.call('purchaseInformation', {...v, 'id': request['id'], 'operationId': op}); });
    if (result == true) await load();
  }
  @override Widget build(BuildContext context) {
    final requests = financeRows(data?['requests'])..sort((a, b) => (b['creadoEn'] ?? '').toString().compareTo((a['creadoEn'] ?? '').toString()));
    return Scaffold(appBar: AppBar(title: const Text('Gestión de compras'), actions: [IconButton(tooltip: 'Actualizar', onPressed: busy ? null : load, icon: const Icon(Icons.refresh))]), floatingActionButton: data == null ? null : FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Solicitar compra')), body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 110), children: [
      const Text('Compra lo necesario, con autorización.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Consulta la respuesta y registra la compra aprobada desde aquí.'), const SizedBox(height: 18),
      if (busy) const LinearProgressIndicator(), if (error != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Text(error!), TextButton(onPressed: load, child: const Text('Reintentar'))]))),
      if (data != null && requests.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Todavía no hay solicitudes.'))),
      for (final r in requests) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r['producto'].toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text('${financeMoney(r['centavosEstimados'])} · ${r['estado'].toString().replaceAll('_', ' ')}'), const SizedBox(height: 8), Text(r['motivo']?.toString() ?? ''),
        if ((r['comentarioAdministracion'] ?? '').toString().isNotEmpty) Text('Administración: ${r['comentarioAdministracion']}'),
        if ((r['respuestaSolicitante'] ?? '').toString().isNotEmpty) Text('Respuesta: ${r['respuestaSolicitante']}'),
        if (r['resueltoPor'] != null) Text('Resuelto por ${r['resueltoPor']}'),
        if (data?['canApprove'] == true && ['pendiente', 'informacion_solicitada'].contains(r['estado'])) ...[
          for (final b in financeRows(data?['budgets']).where((b) => b['proyectoId'] == r['proyectoId'] && (b['centavos'] as num? ?? 0) - (b['gastadoCentavos'] as num? ?? 0) < (r['centavosEstimados'] as num? ?? 0))) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Excede el disponible de ${b['nombre']}. Revisa el presupuesto antes de aprobar.', style: const TextStyle(color: Colors.orangeAccent))),
          const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: () => resolve(r, 'aprobada'), icon: const Icon(Icons.check), label: const Text('Aprobar')), OutlinedButton(onPressed: () => resolve(r, 'rechazada'), child: const Text('Rechazar')), TextButton(onPressed: () => resolve(r, 'informacion_solicitada'), child: const Text('Solicitar información'))]),
        ],
        if (r['creadoPor'] == widget.user.id && r['estado'] == 'informacion_solicitada') FilledButton.tonal(onPressed: () => information(r), child: const Text('Responder')),
        if (r['estado'] == 'aprobada' && r['movimientoId'] == null && (r['creadoPor'] == widget.user.id || data?['canWrite'] == true)) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton.icon(onPressed: () async { if (await showFinanceEntry(context, service: api, purchase: r, projects: financeRows(data?['projects']), financial: widget.administrative) == true) await load(); }, icon: const Icon(Icons.receipt_long), label: const Text('Registrar compra realizada'))),
        if (r['movimientoId'] != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Compra registrada en el libro.')),
      ]))),
    ])));
  }
}
