import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/installation_orders_screen.dart' deferred as screens;
import '../services/installation_order_service.dart';
import '../workflow/enterprise_permissions.dart';
import 'deferred_workspace.dart';

/// A bounded summary. The full checklist and reports download only on demand.
class InstallationHomeCard extends StatefulWidget {
  final UserModel user;
  final Stream<List<Map<String, dynamic>>>? orders;
  const InstallationHomeCard({super.key, required this.user, this.orders});
  @override State<InstallationHomeCard> createState() => _InstallationHomeCardState();
}
class _InstallationHomeCardState extends State<InstallationHomeCard> {
  Stream<List<Map<String, dynamic>>>? _orders;
  @override void initState() { super.initState(); _connect(); }
  @override void didUpdateWidget(covariant InstallationHomeCard old) {
    super.didUpdateWidget(old);
    if (old.user.id != widget.user.id || old.user.rol != widget.user.rol || old.orders != widget.orders) _connect();
  }
  void _connect() {
    _orders = widget.orders;
    if (!widget.user.activo || _orders != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.user.activo) return;
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('instalacion_ordenes');
      if (!EnterprisePermissions.canManageInstallations(widget.user)) q = q.where('participantes', arrayContains: widget.user.id);
      q = q.where('estado', whereIn: ['preparacion','lista','autorizada','validacion_administrativa','en_instalacion','devolucion','diferencias']).limit(3);
      setState(() => _orders = q.snapshots(includeMetadataChanges: true).map((s) => s.docs.map((d) => <String,dynamic>{'id':d.id,...d.data(),'cached':s.metadata.isFromCache}).toList()));
    });
  }
  void _open([String? id]) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeferredWorkspace(
    title: 'Instalaciones', load: screens.loadLibrary,
    builder: (_) => id == null ? screens.InstallationOrdersScreen(user: widget.user) : screens.InstallationOrderDetailScreen(user: widget.user, orderId: id),
  )));
  @override Widget build(BuildContext context) {
    if (!widget.user.activo) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String,dynamic>>>(stream: _orders, builder: (context,s) {
      if (s.hasError) return Card(child: ListTile(leading: const Icon(Icons.handyman_outlined), title: const Text('Checklist de instalación'), subtitle: const Text('No se pudo actualizar. Abre tus órdenes para reintentar.'), onTap: _open));
      if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(EnterprisePermissions.canManageInstallations(widget.user) ? 'Instalaciones activas' : 'Mi checklist de instalación', style: const TextStyle(fontSize: 21,fontWeight: FontWeight.w800)),
        if (s.data!.any((r) => r['cached'] == true)) const Text('Copia local · sincronizando',style: TextStyle(fontSize: 12)),
        for (final order in s.data!) Card(child: ListTile(
          leading: const Icon(Icons.fact_check_outlined), title: Text(order['proyectoTitulo']?.toString() ?? 'Instalación'),
          subtitle: Text('${installationStatus(order['estado']?.toString() ?? '')} · ${installationMap(order['progreso'])['preparados'] ?? 0} de ${installationMap(order['progreso'])['total'] ?? 0} preparados'),
          trailing: const Icon(Icons.chevron_right), onTap: () => _open(order['id'].toString()),
        )),
        TextButton.icon(onPressed: _open, icon: const Icon(Icons.arrow_forward), label: const Text('Ver todas las órdenes y devoluciones')),
      ]);
    });
  }
}
