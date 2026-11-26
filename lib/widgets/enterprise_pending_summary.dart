import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/app_action_catalog.dart';

/// Counts are fetched only when the administrator expands the summary.
class EnterprisePendingSummary extends StatefulWidget {
  final UserModel user;
  final Future<Map<String, dynamic>> Function()? load;
  const EnterprisePendingSummary({super.key, required this.user, this.load});
  @override
  State<EnterprisePendingSummary> createState() =>
      _EnterprisePendingSummaryState();
}

class _EnterprisePendingSummaryState extends State<EnterprisePendingSummary> {
  Future<Map<String, dynamic>>? _summary;
  bool _expanded = false;
  Future<Map<String, dynamic>> _load() async {
    if (widget.load != null) return widget.load!();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != widget.user.id) throw StateError('La sesión cambió.');
    final response = await FirebaseFunctions.instance
        .httpsCallable('enterpriseFinance')
        .call<Object?>({'action': 'homeSummary'});
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('La sesión cambió.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  void didUpdateWidget(covariant EnterprisePendingSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.rol != widget.user.rol) {
      _summary = null;
      _expanded = false;
    }
  }

  void _open(String id) {
    final action = AppActionCatalog.forUser(
      widget.user,
    ).where((a) => a.id == id).firstOrNull;
    if (action != null)
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: action.builder));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.activo || widget.user.rol != AppRoles.admin)
      return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        key: ValueKey('enterprise-summary-${widget.user.id}'),
        leading: const Icon(Icons.business_center_outlined),
        title: const Text(
          'Mi empresa',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Pendientes, instalaciones y finanzas'),
        onExpansionChanged: (value) => setState(() {
          _expanded = value;
          if (value) _summary ??= _load();
        }),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_expanded)
            FutureBuilder<Map<String, dynamic>>(
              future: _summary,
              builder: (context, snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(),
                  if (snapshot.hasError) ...[
                    const Text('No se pudieron actualizar los pendientes.'),
                    TextButton(
                      onPressed: () => setState(() => _summary = _load()),
                      child: const Text('Reintentar'),
                    ),
                  ],
                  if (snapshot.hasData)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${snapshot.data!['facturasPendientes'] ?? '—'} facturas pendientes · '
                        '${snapshot.data!['comprasPendientes'] ?? '—'} compras por autorizar',
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _open('finanzas'),
                        icon: const Icon(Icons.account_balance_outlined),
                        label: const Text('Administración financiera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open('compras'),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Gestión de compras'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open('instalaciones_control'),
                        icon: const Icon(Icons.handyman_outlined),
                        label: const Text('Instalaciones y devoluciones'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open('avances_equipo'),
                        icon: const Icon(Icons.insights),
                        label: const Text('Avance del equipo'),
                      ),
                      TextButton(
                        onPressed: () => _open('gestion'),
                        child: const Text('Toda la gestión de la empresa'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
