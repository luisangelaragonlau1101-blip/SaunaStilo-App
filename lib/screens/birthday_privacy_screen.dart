import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/birthday_preferences_service.dart';

class BirthdayPrivacyScreen extends StatefulWidget {
  final BirthdayPreferencesService? service;
  const BirthdayPrivacyScreen({super.key, this.service});
  @override
  State<BirthdayPrivacyScreen> createState() => _BirthdayPrivacyScreenState();
}

class _BirthdayPrivacyScreenState extends State<BirthdayPrivacyScreen> {
  final _defaultService = BirthdayPreferencesService();
  DateTime? _birthday;
  String _visibility = 'privado';
  bool _greetings = false,
      _loaded = false,
      _busy = false,
      _sessionChanged = false;
  String? _error;
  String _operation = '';
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
            _birthday = null;
            _loaded = false;
            _busy = false;
            _sessionChanged = true;
            _error = 'La sesión cambió. Abre nuevamente tu perfil.';
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
        'readBirthday',
      );
      if (mounted && generation == _generation)
        setState(() {
          _birthday = DateTime.tryParse((result['birthday'] ?? '').toString());
          _visibility =
              [
                'privado',
                'equipo',
                'administracion',
              ].contains(result['visibility'])
              ? result['visibility'].toString()
              : 'privado';
          _greetings = result['greetings'] == true;
          _loaded = true;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(
          () => _error =
              'No pudimos consultar tu configuración. Reintenta con conexión.',
        );
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: 'Tu cumpleaños',
    );
    if (selected != null && mounted && !_sessionChanged)
      setState(() {
        _birthday = selected;
        _operation = '';
      });
  }

  Future<void> _save() async {
    if (_busy || !_loaded || _sessionChanged) return;
    _operation = _operation.isEmpty
        ? 'birthday_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}'
        : _operation;
    final generation = ++_generation;
    final birthday = _birthday;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.service ?? _defaultService).call('saveBirthday', {
        'operationId': _operation,
        'birthday': birthday == null
            ? null
            : '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
        'visibility': _visibility,
        'greetings': _greetings,
      });
      if (mounted && generation == _generation) {
        _operation = '';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu cumpleaños y su privacidad quedaron guardados.'),
          ),
        );
      }
    } catch (_) {
      if (mounted && generation == _generation)
        setState(
          () => _error =
              'No se confirmó el cambio. Puedes reintentar con la misma operación.',
        );
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cumpleaños y privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.cake_outlined, size: 44),
          const SizedBox(height: 16),
          const Text(
            'Tú decides con quién celebrarlo',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu fecha completa se guarda en tu registro privado. Si eliges compartirla, el calendario del equipo solo muestra día y mes.',
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (!_loaded && !_sessionChanged)
              TextButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
          ],
          if (_loaded) ...[
            const SizedBox(height: 18),
            ListTile(
              key: const ValueKey('birthday-date'),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Mi cumpleaños'),
              subtitle: Text(
                _birthday == null
                    ? 'Sin fecha registrada'
                    : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
              ),
              onTap: _busy ? null : _choose,
              trailing: _birthday == null
                  ? const Icon(Icons.edit_outlined)
                  : IconButton(
                      tooltip: 'Quitar mi fecha',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _birthday = null;
                              _operation = '';
                            }),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('birthday-visibility-$_visibility'),
              initialValue: _visibility,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Quién puede ver mi cumpleaños',
              ),
              items: const [
                DropdownMenuItem(value: 'privado', child: Text('Solo yo')),
                DropdownMenuItem(
                  value: 'administracion',
                  child: Text('Yo y Administración'),
                ),
                DropdownMenuItem(
                  value: 'equipo',
                  child: Text('El equipo · día y mes'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null)
                        setState(() {
                          _visibility = value;
                          _operation = '';
                        });
                    },
            ),
            SwitchListTile(
              key: const ValueKey('birthday-greetings'),
              title: const Text('Felicitaciones de cumpleaños'),
              subtitle: const Text(
                'Permitir avisos según la visibilidad que elegiste.',
              ),
              value: _greetings,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _greetings = v;
                      _operation = '';
                    }),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('birthday-save'),
              onPressed: _busy || _sessionChanged ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_busy ? 'Guardando…' : 'Guardar privacidad'),
            ),
          ],
        ],
      ),
    ),
  );
}
