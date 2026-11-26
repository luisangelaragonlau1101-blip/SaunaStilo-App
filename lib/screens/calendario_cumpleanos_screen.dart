import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../presentation/appearance.dart';
import '../services/birthday_preferences_service.dart';
import '../services/team_profile_helpers.dart';
import '../widgets/inline_photo.dart';
import 'birthday_privacy_screen.dart';
import 'perfil_social_screen.dart';

class CalendarioCumpleanosScreen extends StatefulWidget {
  final BirthdayPreferencesService? service;
  const CalendarioCumpleanosScreen({super.key, this.service});
  @override
  State<CalendarioCumpleanosScreen> createState() =>
      _CalendarioCumpleanosScreenState();
}

class _CalendarioCumpleanosScreenState
    extends State<CalendarioCumpleanosScreen> {
  final _defaultService = BirthdayPreferencesService();
  List<Map<String, dynamic>> _rows = [];
  String _search = '';
  bool _monthOnly = false,
      _busy = false,
      _loaded = false,
      _sessionChanged = false;
  String? _error;
  int _generation = 0;
  StreamSubscription<User?>? _auth;
  @override
  void initState() {
    super.initState();
    if (widget.service == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted && (uid == null || user?.uid != uid)) {
          ++_generation;
          setState(() {
            _rows = [];
            _loaded = false;
            _busy = false;
            _sessionChanged = true;
            _error = 'La sesión cambió. Abre el calendario con tu cuenta.';
          });
        }
      });
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_busy || _sessionChanged) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (widget.service ?? _defaultService).call(
        'birthdays',
      );
      final raw = result['rows'] ?? result['items'];
      final rows = raw is List
          ? raw
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .where((r) => _birth(r) != null)
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted && generation == _generation)
        setState(() {
          _rows = rows;
          _loaded = true;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _rows = [];
          _loaded = false;
          _error =
              'No pudimos consultar el calendario. Revisa la conexión y los permisos.';
        });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  DateTime? _birth(Map<String, dynamic> row) {
    final month = row['month'], day = row['day'];
    if (month is! num ||
        day is! num ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31)
      return null;
    final date = DateTime(2000, month.toInt(), day.toInt());
    return date.month == month && date.day == day ? date : null;
  }

  @override
  void dispose() {
    ++_generation;
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = mexicoToday();
    final people =
        _rows
            .where(
              (r) =>
                  (r['nombre'] ?? r['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_search) &&
                  (!_monthOnly || _birth(r)!.month == today.month),
            )
            .toList()
          ..sort(
            (a, b) => nextTeamBirthday(
              _birth(a)!,
              today,
            ).compareTo(nextTeamBirthday(_birth(b)!, today)),
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumpleaños del equipo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar cumpleaños',
            onPressed: _busy || _sessionChanged ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(Icons.celebration_outlined, size: 38),
            const SizedBox(height: 12),
            const Text(
              'Celebramos a nuestra gente',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Aquí aparecen únicamente las fechas que cada persona decidió compartir contigo. Se muestra día y mes, sin año de nacimiento.',
            ),
            TextButton.icon(
              onPressed: _sessionChanged
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BirthdayPrivacyScreen(service: widget.service),
                        ),
                      );
                      if (mounted) await _load();
                    },
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Mi cumpleaños y privacidad'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar a una persona…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (s) =>
                  setState(() => _search = s.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Próximos'),
                  selected: !_monthOnly,
                  onSelected: (_) => setState(() => _monthOnly = false),
                ),
                ChoiceChip(
                  label: const Text('Este mes'),
                  selected: _monthOnly,
                  onSelected: (_) => setState(() => _monthOnly = true),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LinearProgressIndicator(),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _busy || _sessionChanged ? null : _load,
                child: const Text('Reintentar'),
              ),
            ],
            if (_loaded && people.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'No hay cumpleaños compartidos en esta vista.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final row in people) _person(row, today),
          ],
        ),
      ),
    );
  }

  Widget _person(Map<String, dynamic> row, DateTime today) {
    final birthday = _birth(row)!;
    final days = nextTeamBirthday(birthday, today).difference(today).inDays;
    final name = (row['nombre'] ?? row['name'] ?? 'Integrante').toString();
    final photo = (row['fotoUrl'] ?? row['photoUrl'] ?? '').toString();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundImage: photo.isEmpty ? null : stiloImageProvider(photo),
          child: photo.isEmpty ? const Icon(Icons.cake_outlined) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${DateFormat('d MMMM', 'es').format(birthday)} · ${days == 0
              ? '¡Hoy celebramos!'
              : days == 1
              ? 'Mañana'
              : 'En $days días'}',
        ),
        trailing: Icon(
          days == 0 ? Icons.celebration_outlined : Icons.chevron_right_rounded,
          color: StiloColors.accent,
        ),
        onTap: widget.service != null
            ? null
            : () => _openProfile((row['id'] ?? '').toString()),
      ),
    );
  }

  Future<void> _openProfile(String id) async {
    if (id.isEmpty) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final me = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (!me.exists ||
          !mounted ||
          FirebaseAuth.instance.currentUser?.uid != uid)
        return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PerfilSocialScreen(
            usuarioActual: UserModel.fromFirestore(me),
            perfilId: id,
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el perfil.')),
        );
    }
  }
}
