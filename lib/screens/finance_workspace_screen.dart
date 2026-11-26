import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../services/enterprise_finance_service.dart';
import '../services/finance_reports_service.dart';
import '../widgets/finance_controls.dart';
import '../widgets/finance_entry_sheet.dart';
import '../workflow/enterprise_permissions.dart';
import 'purchases_workspace_screen.dart';

const financeInvoiceStates = <String, String>{
  'pendiente': 'Pendiente de factura',
  'solicitada': 'Factura solicitada',
  'esperando_proveedor': 'Esperando proveedor',
  'recibida': 'Factura recibida',
  'verificacion_pendiente': 'Verificación pendiente',
  'verificada': 'Factura verificada',
  'requiere_correccion': 'Requiere corrección',
  'no_facturable': 'No facturable',
};

class FinanceWorkspaceScreen extends StatefulWidget {
  const FinanceWorkspaceScreen({super.key, required this.user, this.service,
    this.initialSection = 'resumen'});
  final UserModel user;
  final EnterpriseFinanceService? service;
  final String initialSection;
  @override State<FinanceWorkspaceScreen> createState() => _FinanceWorkspaceState();
}

class _FinanceWorkspaceState extends State<FinanceWorkspaceScreen> {
  late final api = widget.service ?? EnterpriseFinanceService();
  StreamSubscription<String?>? _session;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late String section = widget.initialSection;
  Map<String, dynamic>? data;
  bool busy = false, verifiedHistory = false;
  String? error;
  int generation = 0;
  bool sessionValid = true;
  String get monthKey => DateFormat('yyyy-MM').format(month);
  bool get writable => data?['canWrite'] == true;
  Map<String, dynamic> get summary => financeMap(data?['summary']);
  List<Map<String, dynamic>> get accounts => financeRows(data?['accounts']);
  List<Map<String, dynamic>> get projects => financeRows(data?['projects']);
  Map<String, String> get accountOptions => {for (final a in accounts.where((a) => a['tipo'] != 'sin_clasificar')) a['id'].toString(): a['nombre'].toString()};
  Map<String, String> get projectOptions => {'': 'General / sin proyecto', for (final p in projects) p['id'].toString(): p['titulo'].toString()};
  @override void initState() {
    super.initState();
    if (!EnterprisePermissions.canViewFinance(widget.user)) return;
    _session = api.sessionChanges.listen((uid) {
      if (uid != widget.user.id && mounted) {
        generation++; sessionValid = false;
        setState(() { data = null; busy = false; error = 'La sesión cambió. Abre esta pantalla con tu cuenta.'; });
      }
    });
    unawaited(load());
  }
  @override void dispose() { generation++; _session?.cancel(); super.dispose(); }
  @override void didUpdateWidget(covariant FinanceWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.rol != widget.user.rol) {
      generation++; sessionValid = false; data = null; busy = false;
      error = 'El acceso cambió. Vuelve a abrir esta sección.';
    }
  }
  Future<void> load() async {
    if (!sessionValid || !EnterprisePermissions.canViewFinance(widget.user)) return;
    final ticket = ++generation;
    setState(() { busy = true; error = null; });
    try {
      final result = await api.call('dashboard', {'month': monthKey});
      if (mounted && ticket == generation && sessionValid) {
        if (result['viewerId'] != widget.user.id) throw StateError('La sesión cambió.');
        setState(() { data = result; busy = false; });
      }
    } catch (e) { if (mounted && ticket == generation) setState(() { data = null; busy = false; error = EnterpriseFinanceService.message(e); }); }
  }
  Future<void> entry(String kind) async {
    if (await showFinanceEntry(context, service: api, kind: kind, accounts: accounts, projects: projects) == true && mounted) await load();
  }
  Future<void> form(String title, List<FinanceField> fields, String action,
      Map<String, dynamic> Function(Map<String, dynamic>) convert, {String? help}) async {
    final ok = await showFinanceForm(context, title: title, fields: fields, help: help,
      save: (v, op) async { await api.call(action, {...convert(v), 'operationId': op}); });
    if (ok == true && mounted) await load();
  }
  Future<void> account([Map<String, dynamic>? row]) => form('Cuenta de la empresa', [
    FinanceField('nombre', 'Nombre', initial: row?['nombre'] ?? ''),
    FinanceField('tipo', 'Tipo', initial: row?['tipo'] ?? 'banco', options: const {'banco': 'Cuenta bancaria', 'efectivo': 'Caja de efectivo'}),
    FinanceField('saldo', 'Saldo inicial registrado', initial: ((row?['saldoInicialCentavos'] as num? ?? 0) / 100).toStringAsFixed(2), money: true),
  ], 'saveAccount', (v) => {...v, if (row != null) 'id': row['id'], 'saldoInicialCentavos': financeCents(v['saldo'], signed: true)},
    help: 'Usa un saldo inicial documentado. Los movimientos históricos se conservan y no se vuelven a sumar como ingresos.');
  Future<void> transfer() => form('Traspaso entre cuentas propias', [
    FinanceField('cuentaOrigenId', 'De', initial: 'banco_principal', options: accountOptions),
    FinanceField('cuentaDestinoId', 'A', initial: 'caja', options: accountOptions),
    const FinanceField('importe', 'Importe', money: true),
    const FinanceField('concepto', 'Concepto (opcional)'),
  ], 'transfer', (v) => {...v, 'centavos': financeCents(v['importe'], zero: false)},
    help: 'Este registro mueve saldo entre cuentas de la empresa; no cuenta como venta ni nuevo ingreso.');
  Future<void> bankBalance(Map<String, dynamic> row) => form('Saldo del estado de cuenta', [
    const FinanceField('importe', 'Saldo revisado del banco', money: true),
    const FinanceField('referencia', 'Referencia del estado de cuenta'),
    FinanceField('fecha', 'Fecha AAAA-MM-DD', initial: DateFormat('yyyy-MM-dd').format(DateTime.now())),
  ], 'recordBankBalance', (v) => {...v, 'cuentaId': row['id'], 'centavos': financeCents(v['importe'], signed: true)},
    help: 'Registra la cifra del documento bancario revisado. La conciliación individual de movimientos se conserva por separado.');
  Future<void> budget([Map<String, dynamic>? row]) => form('Presupuesto o inversión', [
    FinanceField('nombre', 'Nombre', initial: row?['nombre'] ?? ''),
    FinanceField('importe', 'Presupuesto', initial: row == null ? '' : ((row['centavos'] as num) / 100).toStringAsFixed(2), money: true),
    FinanceField('proyectoId', 'Proyecto', initial: row?['proyectoId'] ?? '', options: projectOptions),
    FinanceField('categoria', 'Categoría', initial: row?['categoria'] ?? '', options: {'': 'Todas las categorías', for (final c in financeCategories) c: c}),
    FinanceField('mes', 'Mes AAAA-MM (vacío: todo el proyecto)', initial: row?['mes'] ?? monthKey),
    FinanceField('naturaleza', 'Naturaleza', initial: row?['naturaleza'] ?? 'operacion', options: const {'operacion': 'Gasto operativo', 'inversion': 'Inversión en activo'}),
  ], 'saveBudget', (v) => {...v, if (row != null) 'id': row['id'], 'centavos': financeCents(v['importe'], zero: false)});
  Future<void> projectPlan(Map<String, dynamic> row) => form('Rentabilidad · ${row['titulo']}', [
    FinanceField('venta', 'Precio de venta total', initial: row['precioVentaCentavos'] == null ? '' : ((row['precioVentaCentavos'] as num) / 100).toStringAsFixed(2), money: true),
    FinanceField('neto', 'Precio antes de impuestos', initial: row['precioVentaNetoCentavos'] == null ? '' : ((row['precioVentaNetoCentavos'] as num) / 100).toStringAsFixed(2), money: true),
    FinanceField('pendiente', 'Costos comprometidos pendientes', initial: ((row['costosPendientes'] as num? ?? 0) / 100).toStringAsFixed(2), money: true),
    FinanceField('estimado', 'Otros costos estimados', initial: ((row['costosEstimados'] as num? ?? 0) / 100).toStringAsFixed(2), money: true),
  ], 'saveProjectPlan', (v) => {'proyectoId': row['id'], 'precioVentaCentavos': financeCents(v['venta'], zero: false), 'precioVentaNetoCentavos': v['neto'].toString().isEmpty ? null : financeCents(v['neto'], zero: false), 'costosPendientesCentavos': financeCents(v['pendiente']), 'costosEstimadosCentavos': financeCents(v['estimado'])},
    help: 'Los anticipos son cobros del cliente. El margen compara precio neto con costos registrados, comprometidos y estimados.');
  Future<void> fiscalConfig() async {
    final config = financeMap(data?['config']);
    final declared = financeMap(financeMap(config['declaraciones'])[monthKey])['declaradoCentavos'];
    final isr = financeMap(config['isrEstimados'])[monthKey];
    await form('Configuración de Contabilidad', [
      FinanceField('rfc', 'RFC receptor de la empresa', initial: config['rfc'] ?? ''),
      FinanceField('regimen', 'Régimen fiscal', initial: config['regimen'] ?? 'pendiente', options: const {'pendiente': 'Por confirmar', 'actividad_empresarial': 'Actividad empresarial', 'resico': 'RESICO', 'otro': 'Otro régimen'}),
      FinanceField('confirmada', 'Contabilidad confirmó el régimen', initial: config['confirmada'] == true, toggle: true),
      for (final item in [('reservaFiscalCentavos', 'Reserva para impuestos'), ('reservaMaterialesCentavos', 'Reserva para materiales'), ('reservaInstalacionesCentavos', 'Reserva para instalaciones'), ('reservaCompromisosCentavos', 'Otros compromisos')])
        FinanceField(item.$1, item.$2, initial: ((config[item.$1] as num? ?? 0) / 100).toStringAsFixed(2), money: true),
      FinanceField('isr', 'ISR estimado por Contabilidad · $monthKey (opcional)', initial: isr == null ? '' : ((isr as num) / 100).toStringAsFixed(2), money: true),
      FinanceField('declarado', 'Impuestos declarados · $monthKey (opcional)', initial: declared == null ? '' : ((declared as num) / 100).toStringAsFixed(2), money: true),
    ], 'saveFiscalConfig', (v) => {...v, 'month': monthKey,
      for (final key in ['reservaFiscalCentavos', 'reservaMaterialesCentavos', 'reservaInstalacionesCentavos', 'reservaCompromisosCentavos']) key: financeCents(v[key]),
      if (v['isr'].toString().isNotEmpty) 'isrEstimadoCentavos': financeCents(v['isr']),
      if (v['declarado'].toString().isNotEmpty) 'declaradoCentavos': financeCents(v['declarado']),
    }, help: 'El ISR se muestra únicamente cuando Contabilidad confirmó el régimen y capturó una estimación para el periodo. No calcula nómina ni mezcla reglas de regímenes.');
  }
  Future<void> classify(Map<String, dynamic> row) => form('Clasificar movimiento', [
    FinanceField('subtipo', 'Tipo de movimiento', initial: row['subtipo'] ?? 'otro', options: row['tipo'] == 'ingreso'
      ? const {'venta': 'Venta', 'anticipo': 'Anticipo', 'parcialidad': 'Parcialidad', 'liquidacion': 'Liquidación', 'aportacion': 'Aportación del titular', 'deposito': 'Depósito por revisar', 'devolucion': 'Devolución', 'otro': 'Otro'}
      : const {'compra': 'Compra', 'retiro': 'Retiro', 'impuesto': 'Pago de impuestos', 'devolucion': 'Devolución', 'otro': 'Otro'}),
    FinanceField('cuentaId', 'Cuenta del movimiento', initial: accountOptions.containsKey(row['cuentaId']) ? row['cuentaId'] : '', options: {'': 'Mantener sin cuenta asignada', ...accountOptions}),
    FinanceField('tratamiento', 'Tratamiento fiscal', initial: financeMap(row['fiscal'])['tratamiento'] ?? 'pendiente', options: const {'pendiente': 'Por clasificar', 'gravado': 'Gravado', 'tasa_cero': 'Tasa cero', 'exento': 'Exento', 'no_objeto': 'No objeto'}),
    const FinanceField('tasa', 'Tasa IVA', initial: '1600', options: {'1600': '16 %', '800': '8 % cuando corresponda'}),
    FinanceField('total', 'Total del comprobante', initial: ((financeMap(row['fiscal'])['totalCentavos'] as num? ?? row['centavos'] as num) / 100).toStringAsFixed(2), money: true),
    const FinanceField('retencionIva', 'IVA retenido', money: true), const FinanceField('retencionIsr', 'ISR retenido', money: true),
  ], 'classifyMovement', (v) => {'id': row['id'], 'subtipo': v['subtipo'], if (v['cuentaId'].toString().isNotEmpty) 'cuentaId': v['cuentaId'], 'fiscal': {'tratamiento': v['tratamiento'], 'tasaBps': int.parse(v['tasa'].toString()), 'totalCentavos': financeCents(v['total'], zero: false), 'retencionIvaCentavos': financeCents(v['retencionIva']), 'retencionIsrCentavos': financeCents(v['retencionIsr'])}});
  Future<void> importStatement() async {
    final accountId = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Cuenta del estado de cuenta'), children: [
      for (final a in accounts.where((a) => a['tipo'] == 'banco')) SimpleDialogOption(onPressed: () => Navigator.pop(c, a['id'].toString()), child: Text(a['nombre'].toString())),
    ]));
    if (accountId == null || !mounted) return;
    try {
      final file = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (file.isEmpty) return;
      final rows = FinanceReports.statementRows(utf8.decode(await file.single.readAsBytes()));
      if (rows.length > 100) throw StateError('Importa hasta 100 renglones por archivo.');
      final operation = EnterpriseFinanceService.operationId();
      if (!mounted) return;
      final ok = await showFinanceForm(context, title: 'Confirmar importación', fields: const [], help: '${rows.length} movimientos para conciliar. Se conservan separados del libro hasta que los vincules; no se crean ingresos ni gastos automáticamente.', saveLabel: 'Importar', save: (_, op) async { await api.call('importStatement', {'operationId': operation, 'cuentaId': accountId, 'rows': rows}); });
      if (ok == true) await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(EnterpriseFinanceService.message(e)))); }
  }
  Future<void> reconcile(Map<String, dynamic> row) => form('Conciliar movimiento bancario', [
    FinanceField('movimientoId', 'Movimiento registrado', initial: '', options: {'': 'Selecciona un movimiento', for (final m in financeRows(data?['movements'])) m['id'].toString(): '${m['concepto']} · ${financeMoney(m['centavos'])}'}),
  ], 'reconcile', (v) => {'id': row['id'], 'movimientoId': v['movimientoId']}, help: '${row['fecha']} · ${row['referencia']} · ${financeMoney(row['centavos'])}. La cuenta y el importe deben coincidir.');
  Future<void> attachInvoice(Map<String, dynamic> invoice) async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xml', 'pdf'], withData: true, allowMultiple: true);
      if (picked == null || !mounted) return;
      final operation = EnterpriseFinanceService.operationId();
      final refs = <Map<String, dynamic>>[];
      String? xmlPath;
      for (final file in picked) {
        final ref = await api.upload(bytes: await file.readAsBytes(), name: file.name, operation: operation);
        if (file.extension?.toLowerCase() == 'xml') {
          if (xmlPath != null) throw StateError('Adjunta un solo XML por comprobación.');
          xmlPath = ref['path'].toString();
        }
        refs.add(ref);
      }
      if (!mounted) return;
      final ok = await showFinanceForm(context, title: 'Adjuntar comprobantes', fields: const [], help: '${refs.length} archivos. El XML se comprobará en el servidor; el PDF y la foto no sustituyen al CFDI.', saveLabel: 'Adjuntar y revisar', save: (_, op) async { await api.call('invoiceAttach', {'operationId': operation, 'id': invoice['id'], 'archivos': refs, if (xmlPath != null) 'xmlPath': xmlPath}); });
      if (ok == true) await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(EnterpriseFinanceService.message(e)))); }
  }
  Future<void> invoiceState(Map<String, dynamic> row) => form('Seguimiento de factura', [
    FinanceField('estado', 'Estado', initial: row['estado'], options: Map.fromEntries(financeInvoiceStates.entries.where((e) => e.key != 'verificada'))),
    FinanceField('comentario', 'Observaciones', initial: row['observaciones'] ?? '', lines: 3),
  ], 'invoiceState', (v) => {...v, 'id': row['id']});
  Future<void> verifyInvoice(Map<String, dynamic> row) => form('Verificar datos del CFDI', [
    const FinanceField('requisitosAcreditamientoConfirmados', 'Contabilidad revisó pago y requisitos de acreditamiento', initial: false, toggle: true),
    const FinanceField('acreditableConfirmado', 'Confirmar IVA acreditable', initial: false, toggle: true),
  ], 'verifyInvoice', (v) => {...v, 'id': row['id']}, help: 'Se comprueban estructura, UUID, RFC receptor, importes, IVA y duplicados. No se consulta el estado del CFDI en SAT ni se valida su sello criptográfico. El ticket no es CFDI.');
  Future<void> openFile(Map<String, dynamic> ref) async {
    try {
      final bytes = await api.readFile(ref['path'].toString());
      if (!mounted) return;
      if ((ref['contentType'] ?? '').toString().startsWith('image/')) {
        await showDialog<void>(context: context, builder: (c) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [Flexible(child: InteractiveViewer(child: Image.memory(bytes))), TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))])));
      } else {
        await FilePicker.saveFile(dialogTitle: 'Guardar comprobante privado', fileName: ref['name'].toString(), bytes: bytes);
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(EnterpriseFinanceService.message(e)))); }
  }
  Widget heading(String title, [Widget? action]) => Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), if (action != null) action]));
  Widget metrics(List<(String, dynamic)> values) => LayoutBuilder(builder: (context, c) {
    final columns = c.maxWidth >= 700 ? 2 : 1;
    return Wrap(spacing: 12, runSpacing: 8, children: [for (final v in values) SizedBox(width: (c.maxWidth - 12 * (columns - 1)) / columns, child: financeMetric(context, v.$1, v.$2))]);
  });
  List<Widget> overview() => [
    heading('Tu empresa, en cifras'),
    metrics([('Ingresos del mes', summary['ingresos']), ('Egresos del mes', summary['egresos']), ('Saldo registrado', summary['saldoRegistrado']), ('Disponible registrado para operar', summary['disponibleRegistrado'])]),
    const Padding(padding: EdgeInsets.all(8), child: Text('El saldo registrado reúne lo capturado en la aplicación. El saldo bancario se muestra únicamente cuando se registra un estado de cuenta revisado.')),
    Card(child: Padding(padding: const EdgeInsets.all(20), child: FinanceMonthlyBars(income: (summary['ingresos'] as num? ?? 0).toInt(), expenses: (summary['egresos'] as num? ?? 0).toInt()))),
    metrics([('IVA estimado por pagar', summary['ivaEstimadoPorPagar']), ('Fondos reservados', summary['reservasCentavos'])]),
    Wrap(spacing: 8, runSpacing: 8, children: [
      FilledButton.tonalIcon(onPressed: () => setState(() => section = 'facturas'), icon: const Icon(Icons.receipt_long_outlined), label: Text('${financeRows(data?['invoices']).where((i) => !['verificada', 'no_facturable'].contains(i['estado'])).length} facturas pendientes')),
      FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PurchasesWorkspaceScreen(user: widget.user, service: api, administrative: true))), icon: const Icon(Icons.shopping_bag_outlined), label: Text('${financeRows(data?['requests']).where((i) => ['pendiente', 'informacion_solicitada'].contains(i['estado'])).length} compras por autorizar')),
    ]),
    for (final a in accounts.where((a) => a['tipo'] == 'banco' && a['saldoBancarioRevisadoCentavos'] != null)) financeMetric(context, 'Saldo bancario revisado · ${a['nombre']}', a['saldoBancarioRevisadoCentavos'], subtitle: 'Estado de cuenta ${a['referenciaEstadoCuenta'] ?? ''} · ${a['fechaSaldoBancario'] ?? ''}. Revisa diferencias en Conciliación.'),
  ];
  List<Widget> accountView() => [heading('Banco y efectivo', writable ? IconButton(tooltip: 'Agregar cuenta', onPressed: () => account(), icon: const Icon(Icons.add_circle_outline)) : null),
    if (writable) OutlinedButton.icon(onPressed: transfer, icon: const Icon(Icons.swap_horiz), label: const Text('Traspaso entre cuentas propias')),
    for (final a in accounts) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(a['nombre'].toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text(a['tipo'] == 'efectivo' ? 'Caja de efectivo' : a['tipo'] == 'banco' ? 'Cuenta bancaria' : 'Histórico: cuenta pendiente de clasificar'),
      const SizedBox(height: 12), Text('Saldo registrado ${financeMoney(a['saldoRegistrado'])}', style: const TextStyle(fontSize: 20)),
      if (a['saldoBancarioRevisadoCentavos'] != null) Text('Saldo del banco revisado ${financeMoney(a['saldoBancarioRevisadoCentavos'])}'),
      if (writable && a['tipo'] != 'sin_clasificar') Wrap(spacing: 8, children: [TextButton(onPressed: () => account(a), child: const Text('Configurar cuenta')), if (a['tipo'] == 'banco') TextButton(onPressed: () => bankBalance(a), child: const Text('Registrar saldo revisado'))]),
    ]))),
  ];
  List<Widget> movementView() => [heading('Movimientos del mes'),
    if (financeRows(data?['movements']).isEmpty) const Text('No hay movimientos registrados para este mes.'),
    for (final m in financeRows(data?['movements'])) Card(child: ExpansionTile(
      title: Text(m['concepto'].toString()), subtitle: Text('${m['tipo']} · ${financeMoney(m['centavos'])} · ${m['fecha'].toString().split('T').first}'),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18), expandedCrossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cuenta: ${m['cuentaId'] ?? '${m['cuentaOrigenId']} → ${m['cuentaDestinoId']}'}'),
        Text('Categoría: ${m['categoria'] ?? 'Sin clasificar'} · responsable: ${m['creadoPor'] ?? 'Histórico'}'),
        if (m['cliente']?.toString().isNotEmpty == true) Text('Cliente: ${m['cliente']}'),
        if (m['proveedor']?.toString().isNotEmpty == true) Text('Proveedor: ${m['proveedor']}'),
        Text('Factura: ${financeInvoiceStates[m['facturaEstado']] ?? 'Revisión pendiente'}'),
        Text('Tratamiento: ${financeMap(m['fiscal'])['tratamiento'] ?? 'Histórico pendiente de clasificación'}'),
        if (financeMap(m['fiscal'])['pendienteCentavos'] != null) Text('Pendiente de cobrar/pagar: ${financeMoney(financeMap(m['fiscal'])['pendienteCentavos'])}'),
        for (final file in financeRows(m['archivos'])) TextButton.icon(onPressed: () => openFile(file), icon: const Icon(Icons.attachment), label: Text(file['name'].toString())),
        if (writable && m['tipo'] != 'traspaso') TextButton(onPressed: () => classify(m), child: const Text('Revisar clasificación fiscal')),
      ],
    )),
  ];
  List<Widget> invoiceView() => [heading('Facturas pendientes'),
    const Text('El ticket conserva la evidencia de compra. La verificación del CFDI requiere el XML y revisión de Contabilidad.'),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Incluir facturas verificadas y no facturables'), value: verifiedHistory, onChanged: (v) => setState(() => verifiedHistory = v)),
    for (final f in financeRows(data?['invoices']).where((f) => verifiedHistory || !['verificada', 'no_facturable'].contains(f['estado']))) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(f['concepto'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      Text('${financeMoney(f['centavos'])} · ${financeInvoiceStates[f['estado']] ?? f['estado']}'),
      if (f['proveedor']?.toString().isNotEmpty == true) Text('Proveedor: ${f['proveedor']}'),
      for (final file in financeRows(f['archivos'])) TextButton.icon(onPressed: () => openFile(file), icon: const Icon(Icons.attachment), label: Text(file['name'].toString())),
      if (f['cfdi'] is Map) Text('UUID: ${financeMap(f['cfdi'])['uuid']}\nRFC emisor: ${financeMap(f['cfdi'])['rfcEmisor']}\nRFC receptor: ${financeMap(f['cfdi'])['rfcReceptor']}\nTotal del XML: ${financeMoney(financeMap(f['cfdi'])['totalCentavos'])}'),
      if (f['verificadoPor'] != null) Text('Verificación: ${f['verificadoPor']} · ${f['verificadoEn']}'),
      if (writable && f['estado'] != 'verificada') Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => invoiceState(f), icon: const Icon(Icons.edit_note), label: const Text('Actualizar estado')),
        OutlinedButton.icon(onPressed: () => attachInvoice(f), icon: const Icon(Icons.upload_file), label: const Text('Adjuntar XML / PDF')),
        if (f['cfdi'] is Map) FilledButton.icon(onPressed: () => verifyInvoice(f), icon: const Icon(Icons.verified_outlined), label: const Text('Verificar CFDI')),
      ]),
    ]))),
  ];
  List<Widget> budgetsView() => [heading('Presupuestos e inversiones', writable ? IconButton(tooltip: 'Crear presupuesto', onPressed: () => budget(), icon: const Icon(Icons.add_circle_outline)) : null),
    if (financeRows(data?['budgets']).isEmpty) const Text('Crea presupuestos de fabricación, instalaciones, madera, materiales, herramientas, maquinaria, nueva bodega o viáticos.'),
    for (final b in financeRows(data?['budgets'])) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(b['nombre'].toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text('${b['naturaleza'] == 'inversion' ? 'Inversión' : 'Operación'} · ${b['mes'] ?? 'Todo el proyecto'}'),
      Text('Presupuesto ${financeMoney(b['centavos'])}\nGasto real ${financeMoney(b['gastadoCentavos'])}\nDisponible ${financeMoney((b['centavos'] as num? ?? 0) - (b['gastadoCentavos'] as num? ?? 0))}'),
      const SizedBox(height: 12), LinearProgressIndicator(value: ((b['gastadoCentavos'] as num? ?? 0) / ((b['centavos'] as num? ?? 1) == 0 ? 1 : b['centavos'] as num)).clamp(0, 1).toDouble()),
      if ((b['gastadoCentavos'] as num? ?? 0) > (b['centavos'] as num? ?? 0)) const Text('El gasto registrado supera el presupuesto.', style: TextStyle(color: Colors.orangeAccent)),
      if (writable) TextButton(onPressed: () => budget(b), child: const Text('Editar presupuesto')),
    ]))),
  ];
  List<Widget> reconciliationView() => [heading('Conciliación bancaria', writable ? IconButton(tooltip: 'Importar estado de cuenta CSV', onPressed: importStatement, icon: const Icon(Icons.file_upload_outlined)) : null),
    const Text('CSV: fecha, referencia, importe. Usa AAAA-MM-DD e importes con signo y punto decimal. La importación no crea movimientos en el libro.'),
    if (financeRows(data?['statements']).isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay renglones bancarios para este mes.')),
    for (final r in financeRows(data?['statements'])) Card(child: ListTile(isThreeLine: true, title: Text('${financeMoney(r['centavos'])} · ${r['referencia']}'), subtitle: Text('${r['fecha']}\n${r['estado']} · ${r['cuentaId']}'), trailing: writable && r['estado'] != 'conciliado' ? IconButton(tooltip: 'Conciliar', onPressed: () => reconcile(r), icon: const Icon(Icons.link)) : const Icon(Icons.check_circle_outline))),
  ];
  List<Widget> projectsView() => [heading('Rentabilidad por proyecto'),
    const Text('El margen es una estimación. Distingue precio neto, anticipos cobrados, costo registrado y costos pendientes; no considera los anticipos como utilidad.'),
    for (final p in financeRows(data?['profitability'])) Card(child: ExpansionTile(title: Text(p['titulo'].toString()), subtitle: Text('Margen estimado: ${financeMoney(p['margenEstimado'])}'), childrenPadding: const EdgeInsets.all(18), children: [
      for (final item in [('Precio de venta', 'precioVentaCentavos'), ('Anticipos y cobros', 'anticiposCentavos'), ('Saldo por cobrar', 'saldoPorCobrar'), ('Costo registrado', 'costoRegistrado'), ('Costos pendientes', 'costosPendientes'), ('Otros costos estimados', 'costosEstimados')]) ListTile(contentPadding: EdgeInsets.zero, title: Text(item.$1), trailing: Text(financeMoney(p[item.$2]))),
      for (final e in financeMap(p['categorias']).entries) ListTile(contentPadding: EdgeInsets.zero, title: Text(e.key), trailing: Text(financeMoney(e.value))),
      if (writable) FilledButton.tonal(onPressed: () => projectPlan(p), child: const Text('Configurar precio y costos pendientes')),
    ])),
  ];
  List<Widget> fiscalView() => [heading('Control fiscal estimado', writable ? IconButton(tooltip: 'Configuración fiscal', onPressed: fiscalConfig, icon: const Icon(Icons.settings_outlined)) : null),
    Text('Régimen: ${financeMap(data?['config'])['regimen'] ?? 'Pendiente de confirmar'} · ${financeMap(data?['config'])['confirmada'] == true ? 'Confirmado por Contabilidad' : 'Sin confirmar'}'),
    metrics([('Ingresos efectivamente cobrados', summary['ventasCobradas']), ('Ingresos antes de IVA', summary['baseCobrada']), ('IVA cobrado estimado', summary['ivaCobrado']), ('IVA acreditable estimado', summary['ivaAcreditable']), ('IVA estimado por pagar', summary['ivaEstimadoPorPagar']), ('ISR estimado por Contabilidad', summary['isrEstimado']), ('Impuestos declarados', summary['impuestosDeclarados']), ('Impuestos pagados registrados', summary['impuestosPagados']), ('Fondos reservados', summary['reservasCentavos'])]),
    Text('${summary['sinClasificar'] ?? '—'} movimientos pendientes de clasificación · ${summary['sinComprobar'] ?? '—'} gastos pendientes de comprobación.'),
    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Las estimaciones utilizan importes efectivamente cobrados o pagados y sus datos fiscales. El IVA acreditable requiere CFDI verificado y confirmación de requisitos por Contabilidad. El efectivo no implica exención. Los fondos reservados se separan del disponible para operar.')),
    if (writable) FilledButton.tonal(onPressed: fiscalConfig, child: const Text('Configurar régimen, reservas y declaraciones')),
  ];
  @override Widget build(BuildContext context) {
    if (!EnterprisePermissions.canViewFinance(widget.user)) return const Scaffold(body: Center(child: Text('Este espacio requiere permiso de Administración financiera.')));
    final sections = {'resumen': 'Resumen', 'movimientos': 'Movimientos', 'cuentas': 'Banco y efectivo', 'facturas': 'Facturas pendientes', 'presupuestos': 'Presupuestos e inversiones', 'conciliacion': 'Conciliación bancaria', 'proyectos': 'Rentabilidad por proyecto', 'fiscal': 'Control fiscal estimado'};
    return Scaffold(appBar: AppBar(title: const Text('Administración financiera'), actions: [
      IconButton(tooltip: 'Actualizar', onPressed: busy || !sessionValid ? null : load, icon: const Icon(Icons.refresh)),
      if (data != null) PopupMenuButton<String>(tooltip: 'Exportar reporte', onSelected: (v) async { try {
        if (v == 'csv') { await FinanceReports.exportCsv(monthKey, financeRows(data?['movements'])); }
        else { await FinanceReports.exportPdf(monthKey, financeRows(data?['movements']), summary, profitability: financeRows(data?['profitability'])); }
      } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(EnterpriseFinanceService.message(e)))); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'csv', child: Text('Reporte CSV para Contabilidad')), PopupMenuItem(value: 'pdf', child: Text('Reporte PDF para Dirección'))]),
    ]), body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 40), children: [
      Row(children: [IconButton(tooltip: 'Mes anterior', onPressed: busy ? null : () { setState(() { month = DateTime(month.year, month.month - 1); data = null; }); load(); }, icon: const Icon(Icons.chevron_left)), Expanded(child: Text(DateFormat('MMMM yyyy', 'es').format(month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))), IconButton(tooltip: 'Mes siguiente', onPressed: busy ? null : () { setState(() { month = DateTime(month.year, month.month + 1); data = null; }); load(); }, icon: const Icon(Icons.chevron_right))]),
      if (writable) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Wrap(spacing: 10, runSpacing: 10, children: [FilledButton.icon(key: const ValueKey('finance-add-income'), onPressed: busy ? null : () => entry('ingreso'), icon: const Icon(Icons.add), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Registrar ingreso'))), FilledButton.tonalIcon(key: const ValueKey('finance-add-expense'), onPressed: busy ? null : () => entry('egreso'), icon: const Icon(Icons.camera_alt_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Registrar gasto')))])),
      DropdownButtonFormField<String>(key: ValueKey('finance-section-$section'), initialValue: sections.containsKey(section) ? section : 'resumen', isExpanded: true, items: sections.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => section = v!), decoration: const InputDecoration(labelText: 'Consultar')),
      const SizedBox(height: 14),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Text(error!), if (sessionValid) TextButton(onPressed: load, child: const Text('Reintentar'))]))),
      if (data != null) ...switch (section) { 'cuentas' => accountView(), 'movimientos' => movementView(), 'facturas' => invoiceView(), 'presupuestos' => budgetsView(), 'conciliacion' => reconciliationView(), 'proyectos' => projectsView(), 'fiscal' => fiscalView(), _ => overview() },
    ])));
  }
}

class FinanceMonthlyBars extends StatelessWidget {
  final int income, expenses;
  const FinanceMonthlyBars({super.key, required this.income, required this.expenses});
  @override Widget build(BuildContext context) {
    final max = [income, expenses, 1].reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ingresos y egresos del mes', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final item in [('Ingresos', income, Colors.lightGreenAccent), ('Egresos', expenses, Colors.redAccent)]) Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.$1} ${financeMoney(item.$2)}'), const SizedBox(height: 6), Semantics(label: '${item.$1}: ${financeMoney(item.$2)}', child: LinearProgressIndicator(minHeight: 10, borderRadius: BorderRadius.circular(20), value: item.$2 / max, color: item.$3))])),
    ]);
  }
}
