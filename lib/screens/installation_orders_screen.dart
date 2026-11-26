import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/installation_order_service.dart';

class InstallationOrdersScreen extends StatefulWidget {
  final UserModel user;
  const InstallationOrdersScreen({super.key, required this.user});
  @override
  State<InstallationOrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<InstallationOrdersScreen> {
  final service = InstallationOrderService();
  late Future<Map<String, dynamic>> result = service.list();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Órdenes de instalación')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: result,
      builder: (context, s) {
        if (s.hasError)
          return _Failure(
            error: s.error!,
            retry: () => setState(() => result = service.list()),
          );
        if (!s.hasData) return const LinearProgressIndicator();
        final rows = installationRows(s.data!['orders']);
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (rows.isEmpty) const Text('No tienes órdenes asignadas.'),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text('${row['proyectoTitulo'] ?? 'Instalación'}'),
                  subtitle: Text(installationStatus('${row['estado']}')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => InstallationOrderDetailScreen(
                          user: widget.user,
                          orderId: '${row['id']}',
                        ),
                      ),
                    );
                    if (mounted) setState(() => result = service.list());
                  },
                ),
              ),
            if (s.data!['limited'] == true)
              TextButton(
                onPressed: () => setState(
                  () => result = service.list(
                    afterId: s.data!['nextCursor']?.toString(),
                  ),
                ),
                child: const Text('Ver siguientes órdenes'),
              ),
          ],
        );
      },
    ),
  );
}

class InstallationOrderDetailScreen extends StatefulWidget {
  final UserModel user;
  final String orderId;
  const InstallationOrderDetailScreen({
    super.key,
    required this.user,
    required this.orderId,
  });
  @override
  State<InstallationOrderDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<InstallationOrderDetailScreen> {
  final service = InstallationOrderService();
  late Future<Map<String, dynamic>> result = service.read(widget.orderId);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de instalación'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () =>
              setState(() => result = service.read(widget.orderId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: result,
      builder: (context, s) {
        if (s.hasError)
          return _Failure(
            error: s.error!,
            retry: () => setState(() => result = service.read(widget.orderId)),
          );
        if (!s.hasData) return const LinearProgressIndicator();
        final order = installationMap(s.data!['order']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${order['proyectoTitulo'] ?? 'Instalación'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(installationStatus('${order['estado']}')),
            const SizedBox(height: 16),
            for (final line in installationRows(order['lineas']))
              Card(
                child: ListTile(
                  leading: Icon(
                    line['preparado'] == true
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                  ),
                  title: Text('${line['nombre'] ?? 'Material'}'),
                  subtitle: Text(
                    'Cantidad: ${line['cantidad'] ?? line['cantidadSolicitada'] ?? '—'}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Historial',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final event in installationRows(s.data!['events']))
              ListTile(
                title: Text(
                  '${event['accion'] ?? event['action'] ?? 'Movimiento'}',
                ),
                subtitle: Text('${event['fecha'] ?? ''}'),
              ),
          ],
        );
      },
    ),
  );
}

class _Failure extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const _Failure({required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(InstallationOrderService.message(error)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );
}
