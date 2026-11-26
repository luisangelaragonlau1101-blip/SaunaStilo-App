import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/admin_workspace_service.dart';
import '../services/enterprise_finance_service.dart';

const financeCategories = ['Por clasificar', 'Fabricación de saunas', 'Instalaciones', 'Madera', 'Material eléctrico', 'Herramientas', 'Maquinaria', 'Nueva bodega', 'Viáticos', 'Gastos generales', 'Equipos y calefactores', 'Consumibles'];

Future<bool?> showFinanceEntry(BuildContext context, {required EnterpriseFinanceService service, String kind = 'egreso', List<Map<String, dynamic>> accounts = const [], List<Map<String, dynamic>> projects = const [], Map<String, dynamic>? purchase, bool financial = true}) => showModalBottomSheet<bool>(
  context: context, isScrollControlled: true, useSafeArea: true,
  builder: (_) => FinanceEntrySheet(service: service, kind: kind, accounts: accounts, projects: projects, purchase: purchase, financial: financial),
);

class FinanceEntrySheet extends StatefulWidget {
  const FinanceEntrySheet({super.key, required this.service, this.kind = 'egreso', this.accounts = const [], this.projects = const [], this.purchase, this.financial = true});
  final EnterpriseFinanceService service;
  final String kind;
  final List<Map<String, dynamic>> accounts, projects;
  final Map<String, dynamic>? purchase;
  final bool financial;
  @override State<FinanceEntrySheet> createState() => _FinanceEntryState();
}
class _FinanceEntryState extends State<FinanceEntrySheet> {
  final amount = TextEditingController(), concept = TextEditingController(), supplier = TextEditingController(), customer = TextEditingController(), note = TextEditingController(), invoiceTotal = TextEditingController(), retainedVat = TextEditingController(), retainedIsr = TextEditingController();
  final operation = EnterpriseFinanceService.operationId();
  String invoice = 'necesito', account = 'banco_principal', payment = 'transferencia', subtype = 'compra', category = 'Por clasificar', treatment = 'pendiente', project = '', nature = 'operacion';
  int vatRate = 1600;
  bool busy = false;
  String? error;
  DateTime day = DateTime.now();
  final List<({String name, Uint8List bytes, Map<String, dynamic>? saved})> photos = [];
  @override void initState() {
    super.initState();
    subtype = widget.kind == 'ingreso' ? 'anticipo' : 'compra';
    final p = widget.purchase;
    if (p != null) { amount.text = ((p['centavosEstimados'] as num? ?? 0) / 100).toStringAsFixed(2); concept.text = (p['producto'] ?? '').toString(); supplier.text = (p['proveedor'] ?? '').toString(); project = (p['proyectoId'] ?? '').toString(); }
  }
  @override void dispose() { for (final c in [amount, concept, supplier, customer, note, invoiceTotal, retainedVat, retainedIsr]) { c.dispose(); } super.dispose(); }
  Future<void> _photo(bool camera) async {
    try {
      if (photos.length >= 8) throw StateError('Puedes agregar hasta ocho comprobantes.');
      Uint8List? bytes; String? name;
      if (camera) { final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1800); if (image != null) { bytes = await image.readAsBytes(); name = image.name; } }
      else { final picked = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']); if (picked != null) { bytes = await picked.single.readAsBytes(); name = picked.single.name; } }
      if (bytes != null && name != null) {
        if (bytes.length > 10 * 1024 * 1024) throw StateError('El comprobante puede pesar hasta 10 MB.');
        if (mounted) setState(() { photos.add((name: name!, bytes: bytes!, saved: null)); error = null; });
      }
    } catch (e) { if (mounted) setState(() => error = e is StateError ? e.message.toString() : 'No pudimos abrir la cámara. Puedes adjuntar una foto guardada.'); }
  }
  Future<void> _save() async {
    final cents = moneyInCents(amount.text);
    if (cents == null) { setState(() => error = 'Escribe un importe mayor que cero, sin separadores de miles.'); return; }
    setState(() { busy = true; error = null; });
    try {
      final files = <Map<String, dynamic>>[];
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final file = photo.saved ?? await widget.service.upload(bytes: photo.bytes, name: photo.name, operation: operation);
        photos[i] = (name: photo.name, bytes: photo.bytes, saved: file); files.add(file);
      }
      final total = invoiceTotal.text.trim().isEmpty ? cents : moneyInCents(invoiceTotal.text);
      if (total == null || total < cents) throw StateError('El total del comprobante debe ser igual o mayor al importe recibido o pagado.');
      await widget.service.call(widget.purchase == null ? 'recordMovement' : 'convertPurchase', {
        'operationId': operation, 'tipo': widget.kind, 'centavos': cents, 'concepto': concept.text.trim(), 'fecha': day.toUtc().toIso8601String(), 'facturaOpcion': invoice, 'cuentaId': account, 'medioPago': payment,
        'cliente': customer.text.trim(), 'proveedor': supplier.text.trim(), 'proyectoId': project, 'subtipo': subtype, 'categoria': category, 'naturaleza': nature, 'observaciones': note.text.trim(), 'archivos': files,
        if (widget.purchase != null) 'purchaseId': widget.purchase!['id'],
        'fiscal': {'tratamiento': treatment, 'tasaBps': vatRate, 'totalCentavos': total, 'retencionIvaCentavos': retainedVat.text.trim().isEmpty ? 0 : moneyInCents(retainedVat.text) ?? -1, 'retencionIsrCentavos': retainedIsr.text.trim().isEmpty ? 0 : moneyInCents(retainedIsr.text) ?? -1},
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() { busy = false; error = EnterpriseFinanceService.message(e); }); }
  }
  Widget _select(String label, String value, Map<String, String> options, ValueChanged<String> change) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: DropdownButtonFormField<String>(initialValue: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(), onChanged: busy ? null : (v) => setState(() => change(v!))));
  @override Widget build(BuildContext context) {
    final income = widget.kind == 'ingreso';
    final accounts = {'banco_principal': 'Cuenta bancaria empresarial', 'caja': 'Caja de efectivo', for (final a in widget.accounts.where((a) => a['tipo'] != 'sin_clasificar')) a['id'].toString(): a['nombre'].toString()};
    return PopScope(canPop: !busy, child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: SizedBox(height: MediaQuery.sizeOf(context).height * .9, child: ListView(padding: const EdgeInsets.all(22), children: [
      Row(children: [Expanded(child: Text(income ? 'Registrar ingreso' : 'Registrar gasto', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800))), IconButton(onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      Text(income ? 'Captura lo que efectivamente recibiste.' : 'Importe, foto y estado de factura. Lo demás es opcional.'), const SizedBox(height: 18),
      TextField(key: const ValueKey('finance-amount'), controller: amount, enabled: !busy, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800), decoration: InputDecoration(prefixText: '\$ ', labelText: income ? 'Cantidad recibida' : 'Importe pagado', suffixText: 'MXN')),
      const SizedBox(height: 16),
      if (!income) ...[
        Wrap(spacing: 10, runSpacing: 10, children: [FilledButton.tonalIcon(onPressed: busy ? null : () => _photo(true), icon: const Icon(Icons.camera_alt_rounded), label: const Text('Fotografiar ticket')), OutlinedButton.icon(onPressed: busy ? null : () => _photo(false), icon: const Icon(Icons.attach_file), label: const Text('Adjuntar'))]),
        for (var i = 0; i < photos.length; i++) ListTile(leading: const Icon(Icons.receipt_long), title: Text(photos[i].name), trailing: IconButton(onPressed: busy ? null : () => setState(() => photos.removeAt(i)), icon: const Icon(Icons.close))),
        const SizedBox(height: 10), const Text('Estado de la factura', style: TextStyle(fontWeight: FontWeight.w700)),
        ...{'necesito': 'Necesito factura', 'tengo': 'Ya tengo factura', 'revisar': 'No requiere factura / revisar'}.entries.map((e) => RadioListTile<String>(value: e.key, groupValue: invoice, onChanged: busy ? null : (v) => setState(() => invoice = v!), title: Text(e.value), dense: true, contentPadding: EdgeInsets.zero)),
      ] else ...[
        _select('Tipo de ingreso', subtype, const {'anticipo': 'Anticipo', 'parcialidad': 'Parcialidad', 'liquidacion': 'Liquidación', 'venta': 'Pago de cliente', 'aportacion': 'Aportación del titular', 'deposito': 'Depósito por clasificar', 'devolucion': 'Devolución', 'otro': 'Otro ingreso'}, (v) => subtype = v),
        TextField(controller: customer, enabled: !busy, decoration: const InputDecoration(labelText: 'Cliente (opcional)')),
      ],
      _select(income ? 'Cuenta de destino' : 'Cuenta de pago', account, accounts, (v) => account = v),
      _select('Medio de pago', payment, const {'transferencia': 'Transferencia', 'efectivo': 'Efectivo', 'tarjeta': 'Tarjeta', 'deposito': 'Depósito bancario', 'por_clasificar': 'Por clasificar'}, (v) { payment = v; if (v == 'efectivo') account = 'caja'; }),
      ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Agregar detalles opcionales'), children: [
        TextField(controller: concept, enabled: !busy, maxLength: 160, decoration: const InputDecoration(labelText: 'Concepto')),
        if (!income) TextField(controller: supplier, enabled: !busy, decoration: const InputDecoration(labelText: 'Proveedor')),
        _select('Proyecto', project, {'': 'General / sin proyecto', for (final p in widget.projects) p['id'].toString(): (p['titulo'] ?? 'Proyecto').toString()}, (v) => project = v),
        _select('Categoría', category, {for (final c in financeCategories) c: c}, (v) => category = v),
        if (!income) _select('Naturaleza', nature, const {'operacion': 'Gasto operativo', 'inversion': 'Inversión en activo'}, (v) => nature = v),
        TextButton.icon(onPressed: busy ? null : () async { final value = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (value != null && mounted) setState(() => day = value); }, icon: const Icon(Icons.event), label: Text(DateFormat('dd/MM/yyyy').format(day))),
        TextField(controller: note, enabled: !busy, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones')),
        if (income) OutlinedButton.icon(onPressed: busy ? null : () => _photo(false), icon: const Icon(Icons.attach_file), label: Text('Comprobantes: ${photos.length}')),
      ]),
      if (widget.financial) ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Clasificación fiscal'), subtitle: const Text('Puede quedar pendiente para Contabilidad.'), children: [
        _select('Tratamiento', treatment, const {'pendiente': 'Pendiente de clasificación', 'gravado': 'Gravado', 'tasa_cero': 'Tasa cero', 'exento': 'Exento', 'no_objeto': 'No objeto'}, (v) => treatment = v),
        if (treatment == 'gravado') _select('Tasa de IVA', vatRate.toString(), const {'1600': '16 %', '800': '8 % (solo cuando corresponda)'}, (v) => vatRate = int.parse(v)),
        TextField(controller: invoiceTotal, enabled: !busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total del comprobante', helperText: 'Vacío: mismo importe recibido o pagado. Permite parcialidades.')),
        TextField(controller: retainedVat, enabled: !busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'IVA retenido, si aplica')),
        TextField(controller: retainedIsr, enabled: !busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'ISR retenido, si aplica')),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Pagar en efectivo no implica exención. La deducibilidad y el acreditamiento requieren revisión.')),
      ]),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 14), FilledButton.icon(key: const ValueKey('finance-save'), onPressed: busy ? null : _save, icon: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(busy ? 'Guardando…' : 'Guardar'))),
      const SizedBox(height: 12),
    ]))));
  }
}
