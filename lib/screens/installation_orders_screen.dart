import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../services/installation_order_service.dart';
import '../workflow/enterprise_permissions.dart';
import '../widgets/finance_controls.dart';
import '../widgets/installation_signature_pad.dart';

const _kinds = {
  'retornable': 'Herramienta retornable',
  'consumible': 'Material consumible',
  'equipo': 'Equipo para instalar',
};
int _quantity(dynamic v) {
  final n = int.tryParse('$v');
  if (n == null || n < 0 || n > 1000000)
    throw StateError('Usa cantidades enteras entre cero y un millón.');
  return n;
}

Future<Map<String, dynamic>?> _pickMaterial(
  BuildContext context,
  InstallationOrderService api, {
  String? orderId,
}) async {
  final catalog = await api.catalog(orderId: orderId);
  if (!context.mounted) return null;
  final rows = [
    ...installationRows(catalog['stock']),
    ...installationRows(catalog['boxes']),
    if (orderId == null)
      ...installationRows(
        catalog['templates'],
      ).map((t) => {...t, 'sourceType': 'plantilla'}),
  ];
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Seleccionar material'),
      children: [
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay artículos disponibles en el inventario.'),
          ),
        for (final row in rows)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, row),
            child: Text(
              row['sourceType'] == 'plantilla'
                  ? 'Plantilla · ${row['nombre']}'
                  : '${row['nombre']} · ${row['disponible']} disponibles${row['sourceType'] == 'cajita' ? ' · Cajita' : ''}',
            ),
          ),
      ],
    ),
  );
}

class InstallationOrdersScreen extends StatefulWidget {
  final UserModel user;
  final InstallationOrderService? service;
  const InstallationOrdersScreen({super.key, required this.user, this.service});
  @override
  State<InstallationOrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<InstallationOrdersScreen> {
  late final api = widget.service ?? InstallationOrderService();
  late Future<Map<String, dynamic>> result = api.list();
  void refresh() => setState(() {
    result = api.list();
  });
  Future<void> create() async {
    try {
      final catalog = await api.catalog();
      if (!mounted) return;
      final projects = {
        for (final p in installationRows(catalog['projects']))
          '${p['id']}': '${p['titulo']}',
      };
      final people = {
        for (final p in installationRows(catalog['people']))
          '${p['id']}': '${p['nombre']}',
      };
      if (projects.isEmpty || people.isEmpty)
        throw StateError(
          'Primero registra un proyecto y responsables activos.',
        );
      final material = await _pickMaterial(context, api);
      if (material == null || !mounted) return;
      final now = DateTime.now();
      final done = await showFinanceForm(
        context,
        title: 'Preparar instalación',
        help:
            'Selecciona responsables. Después podrás agregar más materiales al checklist.',
        fields: [
          FinanceField(
            'proyectoId',
            'Proyecto',
            initial: projects.keys.first,
            options: projects,
          ),
          FinanceField(
            'preparadorId',
            'Quién prepara',
            initial: people.keys.first,
            options: people,
          ),
          FinanceField(
            'transportistaId',
            'Quién transporta y resguarda',
            initial: people.keys.first,
            options: people,
          ),
          FinanceField(
            'receptorTallerId',
            'Quién recibe el regreso',
            initial: people.containsKey(widget.user.id)
                ? widget.user.id
                : people.keys.first,
            options: people,
          ),
          FinanceField(
            'fechaSalida',
            'Salida · AAAA-MM-DD',
            initial: now.toIso8601String().substring(0, 10),
          ),
          FinanceField(
            'fechaRegreso',
            'Regreso · AAAA-MM-DD',
            initial: now
                .add(const Duration(days: 7))
                .toIso8601String()
                .substring(0, 10),
          ),
          if (material['sourceType'] != 'plantilla')
            const FinanceField(
              'cantidad',
              'Cantidad del primer artículo',
              initial: '1',
            ),
          if (material['sourceType'] != 'plantilla')
            FinanceField(
              'tipo',
              'Tipo de artículo',
              initial: 'retornable',
              options: material['sourceType'] == 'cajita'
                  ? {'retornable': 'Herramienta retornable'}
                  : _kinds,
            ),
          const FinanceField(
            'observaciones',
            'Observaciones opcionales',
            lines: 2,
          ),
        ],
        save: (v, op) async {
          await api.mutate('create', op, {
            ...v,
            'lineas': material['sourceType'] == 'plantilla'
                ? installationRows(material['lineas'])
                : [
                    {
                      'sourceType': material['sourceType'],
                      'sourceId': material['id'],
                      'tipo': v['tipo'],
                      'cantidad': _quantity(v['cantidad']),
                    },
                  ],
          });
        },
      );
      if (done == true && mounted) refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(InstallationOrderService.message(e))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Órdenes de instalación'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton:
        EnterprisePermissions.canManageInstallations(widget.user)
        ? FloatingActionButton.extended(
            onPressed: create,
            icon: const Icon(Icons.add),
            label: const Text('Preparar instalación'),
          )
        : null,
    body: FutureBuilder<Map<String, dynamic>>(
      future: result,
      builder: (context, s) {
        if (s.hasError) return _Failure(error: s.error!, retry: refresh);
        if (!s.hasData) return const LinearProgressIndicator();
        final rows = installationRows(s.data!['orders']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
          children: [
            if (rows.isEmpty) const Text('No tienes órdenes asignadas.'),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text('${row['proyectoTitulo'] ?? 'Instalación'}'),
                  subtitle: Text(
                    '${row['folio'] ?? ''} · ${installationStatus('${row['estado']}')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => InstallationOrderDetailScreen(
                          user: widget.user,
                          orderId: '${row['id']}',
                          service: api,
                        ),
                      ),
                    );
                    if (mounted) refresh();
                  },
                ),
              ),
            if (s.data!['limited'] == true)
              TextButton(
                onPressed: () => setState(() {
                  result = api.list(afterId: s.data!['nextCursor']?.toString());
                }),
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
  final InstallationOrderService? service;
  const InstallationOrderDetailScreen({
    super.key,
    required this.user,
    required this.orderId,
    this.service,
  });
  @override
  State<InstallationOrderDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<InstallationOrderDetailScreen> {
  late final api = widget.service ?? InstallationOrderService();
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> lines = [], events = [];
  bool loading = true, busy = false;
  String? error, pendingIntent, pendingId;
  bool get manager => EnterprisePermissions.canManageInstallations(widget.user);
  bool get editor =>
      manager || (order?['editores'] as List? ?? []).contains(widget.user.id);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.read(widget.orderId);
      if (mounted)
        setState(() {
          order = installationMap(data['order']);
          lines = installationRows(order!['lineas']);
          events = installationRows(data['events']);
        });
    } catch (e) {
      if (mounted)
        setState(() {
          order = null;
          error = InstallationOrderService.message(e);
        });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> operate(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    if (busy) return false;
    final payload = {'orderId': widget.orderId, ...fields};
    final intent = jsonEncode({'action': action, ...payload});
    if (intent != pendingIntent) {
      pendingIntent = intent;
      pendingId = api.operationId();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.mutate(action, pendingId!, payload);
      pendingIntent = null;
      pendingId = null;
      if (mounted) await load();
      return true;
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editLine(int index) async {
    final line = lines[index];
    await showFinanceForm(
      context,
      title: '${line['nombre']}',
      help:
          'Solicitado: ${line['cantidad']}. Registra lo que realmente preparaste; una cantidad menor quedará como faltante.',
      fields: [
        FinanceField(
          'preparada',
          'Cantidad preparada',
          initial: '${line['preparada'] ?? 0}',
        ),
        FinanceField(
          'preparadaConfirmada',
          'Revisé este artículo',
          initial: line['preparadaConfirmada'] == true,
          toggle: true,
        ),
        FinanceField(
          'estadoFisico',
          'Estado físico',
          initial: line['estadoFisico'] ?? 'bueno',
          options: const {
            'bueno': 'Buen estado',
            'danado': 'Dañado',
            'reparacion': 'En reparación',
          },
        ),
        FinanceField(
          'observaciones',
          'Faltantes u observaciones',
          initial: line['observaciones'] ?? '',
          lines: 2,
        ),
      ],
      save: (v, op) async {
        final n = _quantity(v['preparada']);
        setState(() => lines[index] = {...line, ...v, 'preparada': n});
      },
    );
  }

  Future<void> noteAction(
    String action,
    String title, {
    String field = 'justificacion',
    Map<String, dynamic> extra = const {},
  }) async {
    await showFinanceForm(
      context,
      title: title,
      fields: [FinanceField(field, 'Observaciones / justificación', lines: 3)],
      save: (v, op) async {
        await api.mutate(action, op, {
          'orderId': widget.orderId,
          ...extra,
          ...v,
        });
      },
    );
    if (mounted) await load();
  }

  Future<void> sign(String action, String side, String hash) async {
    List<List<List<double>>> strokes = [];
    bool sending = false;
    String? message;
    final op = api.operationId();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (c, update) => PopScope(
          canPop: !sending,
          child: AlertDialog(
            title: const Text('Confirmar con mi firma'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Firma de ${widget.user.nombre}. Se guardarán tu identidad, fecha y las cantidades de esta versión.',
                    ),
                    const SizedBox(height: 12),
                    InstallationSignaturePad(onChanged: (v) => strokes = v),
                    if (message != null) Text(message!),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialog),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        update(() => sending = true);
                        try {
                          await api.mutate(action, op, {
                            'orderId': widget.orderId,
                            'side': side,
                            'snapshotHash': hash,
                            'signature': strokes,
                          });
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (e) {
                          if (c.mounted)
                            update(() {
                              sending = false;
                              message = InstallationOrderService.message(e);
                            });
                        }
                      },
                child: Text(sending ? 'Guardando…' : 'Confirmar mi firma'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> photo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 65,
      );
      if (picked == null || !mounted) return;
      setState(() => busy = true);
      await api.uploadPhoto(
        widget.orderId,
        api.operationId(),
        await picked.readAsBytes(),
        picked.name,
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openPhoto(Map<String, dynamic> photo) async {
    try {
      final data = await api.call('photo', {
        'orderId': widget.orderId,
        'path': photo['path'],
      });
      final bytes = await api.readFile(widget.orderId, '${data['path']}');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
    }
  }

  Future<void> document(String phase) async {
    try {
      final data = await api.call('document', {
        'orderId': widget.orderId,
        'phase': phase,
      });
      final bytes = await api.readFile(widget.orderId, '${data['path']}');
      await FilePicker.saveFile(
        dialogTitle: 'Guardar acta de $phase',
        fileName: 'STILO-${widget.orderId}-$phase.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
    }
  }

  Future<void> addMaterial() async {
    try {
      final m = await _pickMaterial(context, api, orderId: widget.orderId);
      if (m == null || !mounted) return;
      await showFinanceForm(
        context,
        title: 'Agregar ${m['nombre']}',
        fields: [
          const FinanceField('cantidad', 'Cantidad', initial: '1'),
          FinanceField(
            'tipo',
            'Tipo',
            initial: 'retornable',
            options: m['sourceType'] == 'cajita'
                ? {'retornable': 'Herramienta retornable'}
                : _kinds,
          ),
          const FinanceField('numeroSerie', 'Serie / identificación opcional'),
        ],
        save: (v, op) async {
          await api.mutate('add-material', op, {
            'orderId': widget.orderId,
            'expectedVersion': order!['version'],
            'material': {
              ...v,
              'sourceId': m['id'],
              'sourceType': m['sourceType'],
              'cantidad': _quantity(v['cantidad']),
            },
          });
        },
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
    }
  }

  Future<void> saveTemplate() async {
    await showFinanceForm(
      context,
      title: 'Guardar plantilla reutilizable',
      fields: [const FinanceField('nombre', 'Nombre de la plantilla')],
      save: (v, op) async {
        await api.mutate('template-save', op, {
          'templateId': 'tpl_$op',
          'nombre': v['nombre'],
          'lineas': lines,
        });
      },
    );
  }

  Future<void> editEditors() async {
    final o = order!;
    final names = {
      '${o['preparadorId']}': '${o['preparadorNombre']}',
      '${o['transportistaId']}': '${o['transportistaNombre']}',
      '${o['receptorTallerId']}': '${o['receptorTallerNombre']}',
    };
    await showFinanceForm(
      context,
      title: 'Quién puede preparar materiales',
      help:
          'Administración conserva la autorización de salida. Estos responsables pueden editar cantidades y guardar avances antes de autorizar.',
      fields: [
        for (final id in (o['participantes'] as List).whereType<String>())
          FinanceField(
            id,
            names[id] ?? id,
            initial: (o['editores'] as List? ?? []).contains(id),
            toggle: true,
          ),
      ],
      save: (v, op) async {
        await api.mutate('set-editors', op, {
          'orderId': widget.orderId,
          'editores': v.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList(),
        });
      },
    );
    if (mounted) await load();
  }

  Future<void> transfer() async {
    try {
      final catalog = await api.catalog(orderId: widget.orderId);
      if (!mounted) return;
      final candidates = {
        for (final p in installationRows(catalog['people']))
          if ((order!['participantes'] as List).contains(p['id']) &&
              p['id'] !=
                  (order!['custodioActualId'] ?? order!['transportistaId']))
            '${p['id']}': '${p['nombre']}',
      };
      if (candidates.isEmpty)
        throw StateError(
          'No hay otro responsable disponible en esta instalación.',
        );
      await showFinanceForm(
        context,
        title: 'Traspasar resguardo',
        help:
            'El cambio queda pendiente hasta que el otro técnico confirme con su propia firma.',
        fields: [
          FinanceField(
            'destinoId',
            'Técnico que recibe',
            initial: candidates.keys.first,
            options: candidates,
          ),
        ],
        save: (v, op) async {
          await api.mutate('request-transfer', op, {
            'orderId': widget.orderId,
            ...v,
          });
        },
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = InstallationOrderService.message(e));
    }
  }

  Future<void> report() async {
    await showFinanceForm(
      context,
      title: 'Reporte de instalación',
      fields: [
        const FinanceField(
          'tipo',
          'Tipo',
          initial: 'danio',
          options: {
            'danio': 'Daño',
            'perdida': 'Pérdida',
            'consumo': 'Consumo',
            'ajuste': 'Ajuste',
          },
        ),
        const FinanceField('observaciones', 'Describe lo ocurrido', lines: 3),
      ],
      save: (v, op) async {
        await api.mutate('report', op, {'orderId': widget.orderId, ...v});
      },
    );
    if (mounted) await load();
  }

  Future<void> returnOrder() async {
    final originals = installationRows(
      installationMap(order!['salida'])['lineas'],
    );
    final fields = <FinanceField>[];
    for (final l in originals) {
      final id = l['id'];
      fields.add(
        FinanceField(
          '${id}_devuelta',
          '${l['nombre']} · regresó en buen estado (salieron ${l['entregada']})',
          initial: '0',
        ),
      );
      fields.add(
        FinanceField(
          '${id}_danada',
          '${l['nombre']} · regresó dañado',
          initial: '0',
        ),
      );
      if (l['tipo'] == 'consumible') {
        fields.add(
          FinanceField(
            '${id}_utilizada',
            '${l['nombre']} · utilizado',
            initial: '0',
          ),
        );
        fields.add(
          FinanceField(
            '${id}_desperdicio',
            '${l['nombre']} · desperdicio',
            initial: '0',
          ),
        );
      }
      if (l['tipo'] == 'equipo')
        fields.add(
          FinanceField(
            '${id}_instalada',
            '${l['nombre']} · instalado',
            initial: '0',
          ),
        );
    }
    await showFinanceForm(
      context,
      title: 'Registrar devolución',
      help:
          'Registra las cantidades reales. Lo que no se contabilice quedará pendiente para revisión administrativa.',
      fields: fields,
      save: (v, op) async {
        await api.mutate('start-return', op, {
          'orderId': widget.orderId,
          'lineas': [
            for (final l in originals)
              {
                'id': l['id'],
                for (final k in [
                  'devuelta',
                  'danada',
                  'utilizada',
                  'desperdicio',
                  'instalada',
                ])
                  k: _quantity(v['${l['id']}_$k'] ?? '0'),
              },
          ],
        });
      },
    );
    if (mounted) await load();
  }

  Widget button(
    String label,
    VoidCallback action, {
    IconData icon = Icons.check_circle_outline,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: FilledButton.icon(
      onPressed: busy ? null : action,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (loading && order == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = order;
    final state = o?['estado'];
    final departure = installationMap(o?['salida']),
        returned = installationMap(o?['devolucion']);
    final signatures = installationMap(o?['firmas']),
        returnSignatures = installationMap(o?['firmasDevolucion']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist de instalación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (loading || busy) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: load,
              child: const Text('Reintentar lectura'),
            ),
          ],
          if (o != null) ...[
            Text(
              '${o['proyectoTitulo']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${o['folio']} · ${installationStatus('$state')}'),
            Text(
              'Prepara: ${o['preparadorNombre']}\nResguarda: ${o['custodioActualNombre'] ?? o['transportistaNombre']}\nRecibe en taller: ${o['receptorTallerNombre']}',
            ),
            const SizedBox(height: 12),
            Text(
              '${lines.where((l) => l['preparadaConfirmada'] == true).length} de ${lines.length} artículos preparados',
            ),
            for (var i = 0; i < lines.length; i++)
              Card(
                child: ListTile(
                  leading: Icon(
                    lines[i]['preparadaConfirmada'] == true
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text('${lines[i]['nombre']}'),
                  subtitle: Text(
                    'Preparado ${lines[i]['preparada']} / ${lines[i]['cantidad']} · ${_kinds[lines[i]['tipo']] ?? ''}',
                  ),
                  onTap:
                      !busy &&
                          editor &&
                          ['preparacion', 'lista'].contains(state)
                      ? () => editLine(i)
                      : null,
                ),
              ),
            if (editor && ['preparacion', 'lista'].contains(state)) ...[
              button('Agregar material', addMaterial, icon: Icons.add),
              button(
                'Guardar avance',
                () => operate('save-checklist', {
                  'expectedVersion': o['version'],
                  'lineas': lines,
                }),
              ),
              button(
                'Terminar preparación',
                () => operate('finish-preparation', {
                  'expectedVersion': o['version'],
                  'lineas': lines,
                }),
              ),
            ],
            if (manager && ['preparacion', 'lista'].contains(state))
              TextButton.icon(
                onPressed: busy ? null : editEditors,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Permisos del checklist'),
              ),
            if (manager && ['preparacion', 'lista'].contains(state))
              TextButton.icon(
                onPressed: busy ? null : saveTemplate,
                icon: const Icon(Icons.copy_all),
                label: const Text('Guardar lista como plantilla'),
              ),
            if (manager && state == 'lista')
              button(
                'Autorizar salida',
                () => noteAction('authorize-departure', 'Autorizar salida'),
              ),
            if (state == 'autorizada') ...[
              if (widget.user.id == o['preparadorId'] &&
                  signatures['entrega'] == null)
                button(
                  'Firmar entrega',
                  () =>
                      sign('sign-departure', 'entrega', '${departure['hash']}'),
                  icon: Icons.draw_outlined,
                ),
              if (widget.user.id == o['transportistaId'] &&
                  signatures['recibe'] == null)
                button(
                  'Firmar recepción',
                  () =>
                      sign('sign-departure', 'recibe', '${departure['hash']}'),
                  icon: Icons.draw_outlined,
                ),
            ],
            if (manager && state == 'validacion_administrativa')
              button(
                'Validar entrega y recepción por la misma persona',
                () =>
                    noteAction('validate-same-person', 'Validar responsables'),
              ),
            if (state == 'en_instalacion' &&
                (manager ||
                    widget.user.id ==
                        (o['custodioActualId'] ?? o['transportistaId'])))
              button(
                'Registrar devolución',
                returnOrder,
                icon: Icons.assignment_return,
              ),
            if (state == 'en_instalacion') ...[
              if (o['traspasoPendiente'] == null &&
                  (manager ||
                      widget.user.id ==
                          (o['custodioActualId'] ?? o['transportistaId'])))
                button('Traspasar resguardo', transfer, icon: Icons.swap_horiz),
              if (installationMap(o['traspasoPendiente'])['haciaId'] ==
                  widget.user.id)
                button(
                  'Confirmar recepción del resguardo',
                  () => sign(
                    'accept-transfer',
                    'recibe',
                    '${installationMap(o['traspasoPendiente'])['snapshotHash']}',
                  ),
                  icon: Icons.draw_outlined,
                ),
              if (o['traspasoPendiente'] != null &&
                  (manager ||
                      [
                        installationMap(o['traspasoPendiente'])['desdeId'],
                        installationMap(o['traspasoPendiente'])['haciaId'],
                      ].contains(widget.user.id)))
                TextButton(
                  onPressed: busy ? null : () => operate('cancel-transfer'),
                  child: const Text('Cancelar traspaso pendiente'),
                ),
            ],
            if (state == 'devolucion') ...[
              for (final l in installationRows(returned['lineas']))
                ListTile(
                  title: Text('${l['nombre']}'),
                  subtitle: Text(
                    'Regresó ${l['devuelta']} · dañado ${l['danada']} · faltante ${l['faltante']}',
                  ),
                ),
              if (widget.user.id ==
                      (returned['devuelveId'] ?? o['transportistaId']) &&
                  returnSignatures['devuelve'] == null)
                button(
                  'Firmar devolución',
                  () => sign('sign-return', 'devuelve', '${returned['hash']}'),
                  icon: Icons.draw_outlined,
                ),
              if (widget.user.id == o['receptorTallerId'] &&
                  returnSignatures['recibe'] == null)
                button(
                  'Firmar recepción en taller',
                  () => sign('sign-return', 'recibe', '${returned['hash']}'),
                  icon: Icons.draw_outlined,
                ),
            ],
            if (manager && state == 'diferencias')
              button(
                'Conciliar y cerrar devolución',
                () => noteAction(
                  'close-return',
                  'Resolver diferencias y cerrar',
                  field: 'resolucion',
                ),
              ),
            if (manager && state == 'cerrada')
              for (final line in installationRows(returned['lineas']))
                if (line['sourceType'] == 'cajita' &&
                    line['entregada'] == 1 &&
                    line['devuelta'] == 0 &&
                    installationMap(o['resolucionesCajita'])[line['id']] ==
                        null)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => noteAction(
                            'resolve-personal-tool',
                            'Confirmar recuperación de ${line['nombre']}',
                            field: 'resolucion',
                            extra: {'lineId': line['id']},
                          ),
                    icon: const Icon(Icons.build_circle_outlined),
                    label: Text('Registrar recuperación: ${line['nombre']}'),
                  ),
            if (!['cerrada', 'cancelada'].contains(state))
              TextButton.icon(
                onPressed: busy ? null : photo,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Agregar fotografía'),
              ),
            for (final photo in installationRows(o['fotos']))
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text('${photo['nombre'] ?? 'Fotografía'}'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openPhoto(photo),
              ),
            if (departure.isNotEmpty &&
                signatures['entrega'] != null &&
                signatures['recibe'] != null)
              TextButton.icon(
                onPressed: () => document('salida'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Acta de salida'),
              ),
            if (returnSignatures['devuelve'] != null &&
                returnSignatures['recibe'] != null)
              TextButton.icon(
                onPressed: () => document('devolucion'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Acta de devolución'),
              ),
            if ([
              'autorizada',
              'en_instalacion',
              'devolucion',
              'diferencias',
            ].contains(state))
              TextButton(
                onPressed: report,
                child: const Text('Registrar reporte o ajuste'),
              ),
            ExpansionTile(
              title: const Text('Historial de la instalación'),
              children: [
                for (final e in events)
                  ListTile(
                    title: Text('${e['accion'] ?? 'Movimiento'}'),
                    subtitle: Text(
                      '${e['usuarioNombre'] ?? ''} · ${e['fecha'] ?? ''}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
