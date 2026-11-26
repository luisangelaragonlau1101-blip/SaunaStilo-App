import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../workflow/enterprise_permissions.dart';
import '../widgets/finance_controls.dart';
import '../services/birthday_preferences_service.dart';

const _permissions = {
  'finanzas': 'Administración financiera / Contabilidad',
  'autorizarCompras': 'Autorizar compras',
  'solicitarCompras': 'Solicitar compras y registrar gastos',
  'instalaciones': 'Administrar órdenes y autorizar salidas',
  'coordinarInstalaciones': 'Coordinar instalaciones asignadas',
  'direccion': 'Consultar finanzas y reportes de Dirección',
};

class EnterprisePermissionsScreen extends StatefulWidget {
  final UserModel user;
  const EnterprisePermissionsScreen({super.key, required this.user});
  @override
  State<EnterprisePermissionsScreen> createState() => _AccessState();
}

class _AccessState extends State<EnterprisePermissionsScreen> {
  List<Map<String, dynamic>> people = [];
  bool busy = false;
  String? error;
  bool get allowed => widget.user.activo && widget.user.rol == AppRoles.admin;
  @override
  void initState() {
    super.initState();
    if (allowed) load();
  }

  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> fields,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != widget.user.id) throw StateError('La sesión cambió.');
    final result = await FirebaseFunctions.instance
        .httpsCallable('enterpriseAccess')
        .call<Object?>({'action': action, ...fields});
    if (FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('La sesión cambió.');
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await call('list', {});
      if (mounted)
        setState(
          () => people = (d['items'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList(),
        );
    } catch (e) {
      if (mounted)
        setState(() {
          people = [];
          error = e.toString();
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> person) async {
    await showFinanceForm(
      context,
      title: 'Permisos de ${person['nombre']}',
      help:
          'Los cambios se validan en Firebase y conservan una auditoría. La autorización de registro manual permite marcar la jornada sin GPS.',
      fields: [
        for (final p in _permissions.entries)
          FinanceField(
            p.key,
            p.value,
            initial: (person['permisosEmpresa'] as List? ?? []).contains(p.key),
            toggle: true,
          ),
        FinanceField(
          'manual',
          'Permitir registros manuales sin GPS',
          initial: person['asistenciaManualPermitida'] == true,
          toggle: true,
        ),
        FinanceField(
          'lunch',
          'Hora de comida · HH:MM',
          initial: person['horaComida'] ?? '15:00',
        ),
        FinanceField(
          'minutes',
          'Duración de comida en minutos',
          initial: '${person['minutosComida'] ?? 70}',
        ),
      ],
      save: (v, op) async {
        final minutes = int.tryParse('${v['minutes']}');
        if (minutes == null || minutes < 10 || minutes > 180)
          throw StateError('La comida debe durar entre 10 y 180 minutos.');
        await call('save', {
          'operationId': op,
          'userId': person['id'],
          'permissions': [
            for (final k in EnterprisePermissions.keys)
              if (v[k] == true) k,
          ],
          'manualAttendance': v['manual'] == true,
          'lunchTime': v['lunch'],
          'lunchMinutes': minutes,
        });
      },
    );
    if (mounted) await load();
  }

  Future<void> protectHistoricalBirthdays() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = BirthdayPreferencesService();
      String? cursor;
      var migrated = 0;
      do {
        if (FirebaseAuth.instance.currentUser?.uid != widget.user.id) {
          throw StateError('La sesión cambió.');
        }
        final result = await service.call('migrateBirthdayPrivacy', {
          if (cursor != null) 'cursor': cursor,
        });
        migrated += (result['migrated'] as num? ?? 0).toInt();
        cursor = result['nextCursor'] as String?;
      } while (cursor != null && mounted);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$migrated fechas protegidas. Cada persona puede elegir quién ve su cumpleaños.',
            ),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed)
      return const Scaffold(
        body: Center(
          child: Text('Solo Administración configura estos permisos.'),
        ),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Funciones y permisos')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (busy) const LinearProgressIndicator(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Privacidad del calendario'),
                  const Text(
                    'Conserva las fechas anteriores en un registro privado. Cada integrante decide si comparte su cumpleaños con el equipo.',
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : protectHistoricalBirthdays,
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Proteger cumpleaños históricos'),
                  ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Reintentar')),
          ],
          for (final p in people)
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text('${p['nombre']}'),
                subtitle: Text(
                  '${p['rol']} · ${p['activo'] == true ? 'Cuenta activa' : 'Cuenta desactivada'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : () => edit(p),
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  final UserModel user;
  const NotificationPreferencesScreen({super.key, required this.user});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesState();
}

class _NotificationPreferencesState
    extends State<NotificationPreferencesScreen> {
  static const labels = {
    'tareas': 'Tareas, entregas y correcciones',
    'compras': 'Solicitudes y respuestas de compras',
    'finanzas': 'Facturas y avisos financieros',
    'instalaciones': 'Preparación, firmas y devoluciones',
    'jornada': 'Entrada, comida y salida',
    'cumpleanos': 'Felicitaciones de cumpleaños',
    'generales': 'Avisos generales',
  };
  final values = {for (final key in labels.keys) key: true};
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  DocumentReference<Map<String, dynamic>> get ref {
    if (FirebaseAuth.instance.currentUser?.uid != widget.user.id)
      throw StateError('La sesión cambió.');
    return FirebaseFirestore.instance
        .collection('preferencias_notificaciones')
        .doc(widget.user.id);
  }

  Future<void> load() async {
    try {
      final data = (await ref.get()).data() ?? {};
      if (mounted)
        setState(() {
          for (final key in labels.keys) values[key] = data[key] != false;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = 'No pudimos consultar tus preferencias.';
          loading = false;
        });
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.set({...values, 'actualizadoEn': FieldValue.serverTimestamp()});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferencias guardadas.')),
        );
    } catch (e) {
      if (mounted)
        setState(
          () => error = 'No se confirmó el cambio. Revisa conexión y permisos.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preferencias de avisos')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Elige los avisos que quieres recibir. Los permisos del dispositivo se administran aparte en tu cuenta.',
        ),
        if (loading || busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        for (final e in labels.entries)
          if (e.key != 'finanzas' ||
              EnterprisePermissions.canViewFinance(widget.user))
            SwitchListTile(
              title: Text(e.value),
              value: values[e.key]!,
              onChanged: loading || busy
                  ? null
                  : (v) => setState(() => values[e.key] = v),
            ),
        FilledButton(
          onPressed: loading || busy ? null : save,
          child: const Text('Guardar preferencias'),
        ),
      ],
    ),
  );
}
