import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/admin_workspace_service.dart';
import '../services/app_action_catalog.dart';
import 'human_resources_screen.dart';

class BusinessWorkspaceScreen extends StatelessWidget {
  final UserModel user;
  const BusinessWorkspaceScreen({super.key, required this.user});
  @override Widget build(BuildContext context) {
    if (user.rol != AppRoles.admin) return const Scaffold(body: Center(child: Text('Este espacio es exclusivo de Administración.')));
    void open(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    final actions = AppActionCatalog.forUser(user);
    return Scaffold(appBar: AppBar(title: const Text('Gestión de la empresa')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Administración', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), const Text('Personas, ventas, abastecimiento y control interno en un solo espacio.'), const SizedBox(height: 20),
      Card(child: ListTile(contentPadding: const EdgeInsets.all(20), leading: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.primary), title: const Text('Recursos Humanos'), subtitle: const Text('Expedientes, altas, horarios, nómina e incorporación'), trailing: const Icon(Icons.chevron_right), onTap: () => open(HumanResourcesScreen(user: user)))),
      Card(child: ListTile(contentPadding: const EdgeInsets.all(20), leading: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary), title: const Text('Control financiero interno'), subtitle: const Text('Registrar ingresos y egresos; revisar el saldo registrado'), trailing: const Icon(Icons.chevron_right), onTap: () => open(BusinessLedgerScreen(user: user)))),
      for (final id in ['clientes','ventas','cotizaciones','proveedores','bandeja_admin','plan_personal','conocimiento_ia','alerta_general','voz']) ...actions.where((a) => a.id == id).map((a) => Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: Icon(a.icon, color: Theme.of(context).colorScheme.primary), title: Text(a.title), subtitle: Text(a.subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: a.builder))))),
      const SizedBox(height: 16), const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Alcance administrativo: estos registros son para el control interno de Sauna Stilo. No están conectados a Siigo Aspel y no emiten CFDI, timbran nómina ni generan contabilidad fiscal.'))),
    ]));
  }
}

class BusinessLedgerScreen extends StatefulWidget {
  final UserModel user;
  const BusinessLedgerScreen({super.key, required this.user});
  @override State<BusinessLedgerScreen> createState() => _BusinessLedgerState();
}
class _BusinessLedgerState extends State<BusinessLedgerScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String filter = 'todos';
  String money(int cents) => NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(cents / 100);
  Future<void> _create() async {
    final concept = TextEditingController(), amount = TextEditingController(), reference = TextEditingController();
    String kind = 'egreso', category = 'Operación'; DateTime date = DateTime.now(); bool busy = false; String? error;
    final id = FirebaseFirestore.instance.collection('gestion_movimientos').doc().id;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (dialog) => StatefulBuilder(builder: (c, update) => PopScope(canPop: !busy, child: AlertDialog(title: const Text('Registrar movimiento'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(initialValue: kind, items: const [DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')), DropdownMenuItem(value: 'egreso', child: Text('Egreso'))], onChanged: busy ? null : (v) => update(() => kind = v!), decoration: const InputDecoration(labelText: 'Tipo')),
      const SizedBox(height: 12), TextField(controller: concept, maxLength: 160, enabled: !busy, decoration: const InputDecoration(labelText: 'Concepto')),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: !busy, decoration: const InputDecoration(labelText: 'Importe en MXN', helperText: 'Sin separadores de miles; máximo dos decimales.')),
      const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: category, items: ['Operación','Venta','Compra','Personal','Servicio','Otro'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: busy ? null : (v) => update(() => category = v!), decoration: const InputDecoration(labelText: 'Categoría')),
      TextButton.icon(onPressed: busy ? null : () async { final picked = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null && c.mounted) update(() => date = picked); }, icon: const Icon(Icons.calendar_month), label: Text(DateFormat('dd/MM/yyyy').format(date))),
      TextField(controller: reference, maxLength: 200, enabled: !busy, decoration: const InputDecoration(labelText: 'Referencia o folio (opcional)')),
      const Text('No realiza transferencias ni pagos. No crea un comprobante fiscal.'),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(c).colorScheme.error)),
    ])), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(dialog), child: const Text('Cancelar')), FilledButton(onPressed: busy ? null : () async {
      final cents = moneyInCents(amount.text);
      if (cents == null || concept.text.trim().length < 3) { update(() => error = 'Escribe un concepto y un importe mayor que cero.'); return; }
      update(() {busy = true; error = null;});
      try { await AdminWorkspaceService().addMovement(id: id, kind: kind, concept: concept.text, cents: cents, category: category, date: date, reference: reference.text); if (dialog.mounted) Navigator.pop(dialog); }
      catch (_) { if (c.mounted) update(() {busy = false; error = 'No se confirmó el registro. Puedes reintentar sin duplicarlo.';}); }
    }, child: Text(busy ? 'Guardando…' : 'Guardar'))]))));
    concept.dispose(); amount.dispose(); reference.dispose();
  }
  @override Widget build(BuildContext context) {
    if (widget.user.rol != AppRoles.admin) return const Scaffold(body: Center(child: Text('Solo Administración.')));
    final query = FirebaseFirestore.instance.collection('gestion_movimientos').where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(month)).where('fecha', isLessThan: Timestamp.fromDate(DateTime(month.year, month.month + 1)));
    return Scaffold(appBar: AppBar(title: const Text('Control financiero interno')), floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Registrar')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), children: [
      Row(children: [IconButton(tooltip: 'Mes anterior', onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text(DateFormat('MMMM yyyy','es').format(month)))), IconButton(tooltip: 'Mes siguiente', onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))]),
      const Text('Solo incluye los movimientos capturados aquí. No se importan ni se suman automáticamente ventas, compras o nóminas de otras pantallas.'), const SizedBox(height: 16),
      Wrap(spacing: 8, children: [for (final k in ['todos','ingreso','egreso']) ChoiceChip(label: Text({'todos':'Todos','ingreso':'Ingresos','egreso':'Egresos'}[k]!), selected: filter == k, onSelected: (_) => setState(() => filter = k))]),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(), builder: (context, snapshot) {
        if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(20), child: Text('No se pudo consultar el libro. Revisa tu conexión.'));
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final rows = snapshot.data!.docs.toList()..sort((a,b) => (b.data()['fecha'] as Timestamp).compareTo(a.data()['fecha'] as Timestamp));
        int income = 0, expenses = 0;
        for (final r in rows) { final d = r.data(); final cents = (d['centavos'] as num).toInt(); if (d['tipo'] == 'ingreso') { income += cents; } else { expenses += cents; } }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ingresos ${money(income)}'), Text('Egresos ${money(expenses)}'), const Divider(), Text('Saldo registrado ${money(income - expenses)} MXN', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))]))),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Sin movimientos en este mes.')),
          for (final r in rows.where((r) => filter == 'todos' || r.data()['tipo'] == filter)) Card(child: ListTile(leading: Icon(r.data()['tipo'] == 'ingreso' ? Icons.south_west : Icons.north_east), title: Text(r.data()['concepto']), subtitle: Text('${r.data()['categoria']} · ${DateFormat('dd/MM/yyyy').format((r.data()['fecha'] as Timestamp).toDate())}\n${r.data()['referencia']}'), trailing: Text(money((r.data()['centavos'] as num).toInt())))),
        ]);
      }),
    ]));
  }
}
