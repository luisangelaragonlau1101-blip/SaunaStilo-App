import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/actividades_service.dart';
import '../services/offline_workspace.dart';
import '../models/actividad_model.dart';

class ModalAsignarActividad extends StatefulWidget {
  final String proyectoId, rolUsuario;
  final ActividadModel? actividadAEditar;
  const ModalAsignarActividad({super.key, required this.proyectoId, required this.rolUsuario, this.actividadAEditar});
  @override
  State<ModalAsignarActividad> createState() => _ModalAsignarActividadState();
}
class _ModalAsignarActividadState extends State<ModalAsignarActividad> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _body = TextEditingController();
  late String _id;
  late final String _uid;
  late final String _draftKey;
  String? _target, _error;
  bool _busy = false, _loading = true;
  List<Map<String, String>> _people = [];
  DateTime _day = DateTime.now(), _deadline = DateTime.now().add(const Duration(days: 1));
  @override
  void initState() {
    super.initState();
    final old = widget.actividadAEditar;
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _id = old?.id ?? FirebaseFirestore.instance.collection('actividades').doc().id;
    _draftKey = 'tarea:${widget.proyectoId}:${old?.id ?? 'nueva'}';
    if (old != null) {_title.text = old.titulo; _body.text = old.descripcion; _target = old.asignadoATrabajadorId; _day = old.fechaAsignada; _deadline = old.fechaTermino;}
    _load();
  }
  @override
  void dispose() {_title.dispose(); _body.dispose(); super.dispose();}
  Future<void> _load() async {
    setState(() {_loading = true; _error = null;});
    try {
      final db = FirebaseFirestore.instance;
      final admin = widget.rolUsuario == 'admin';
      var members = <String>[];
      if (widget.proyectoId.isNotEmpty) {
        final project = await db.collection('proyectos').doc(widget.proyectoId).get().timeout(const Duration(seconds: 15));
        members = (project.data()?['encargados'] as List? ?? const []).whereType<String>().toList();
        if (!project.exists || (!admin && (widget.rolUsuario != 'maestro' || !members.contains(_uid)))) {
          throw StateError('Administración debe asignarte como integrante de este proyecto.');
        }
      } else if (!admin) {
        throw StateError('Las tareas generales las asigna Administración. Como maestro, elige uno de tus proyectos.');
      }
      final people = await db.collection('usuarios').get().timeout(const Duration(seconds: 15));
      final entries = people.docs.where((d) => d.data()['activo'] != false &&
        (admin || members.contains(d.id))).map((d) => {'id': d.id, 'nombre': '${d.data()['nombre'] ?? d.data()['Nombre'] ?? 'Integrante'} · ${d.data()['rol'] ?? ''}'}).toList();
      entries.sort((a,b) => a['nombre']!.compareTo(b['nombre']!));
      if (!mounted) return;
      setState(() {_people = entries; if (!_people.any((p) => p['id'] == _target)) _target = null;});
      if (entries.isEmpty) setState(() => _error = widget.proyectoId.isEmpty ? 'No hay personas activas disponibles. Revisa las cuentas del equipo.' : 'Este proyecto no tiene integrantes activos. Administración puede agregarlos desde Proyectos.');
    } catch (e) {if (mounted) setState(() => _error = _explain(e));}
    finally {if (mounted) setState(() => _loading = false);}
  }
  String _explain(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') return 'El servidor negó el permiso. Revisa el rol y publica las reglas de esta versión; no se guardó la tarea.';
    if (e is StateError) return e.message.toString();
    return 'No se confirmó la operación. Revisa Internet. Puedes guardar un borrador en este dispositivo sin asignarlo todavía.';
  }
  Future<void> _draft({bool restore = false}) async {
    try {
      if (restore) {
        final d = await OfflineWorkspace.read(_uid, _draftKey);
        if (!mounted) return;
        if (d == null) {setState(() => _error = 'No hay borrador guardado en este dispositivo.'); return;}
        setState(() {_title.text = d['titulo'] ?? ''; _body.text = d['descripcion'] ?? ''; if (widget.actividadAEditar == null && (d['id'] ?? '').isNotEmpty) _id = d['id']!; _day = DateTime.tryParse(d['dia'] ?? '') ?? _day; _deadline = DateTime.tryParse(d['entrega'] ?? '') ?? _deadline; _target = _people.any((p) => p['id'] == d['persona']) ? d['persona'] : null;});
      } else {
        final allowed = await OfflineWorkspace.confirmDevice(context);
        if (!allowed) return;
        await OfflineWorkspace.save(_uid, _draftKey, {'titulo': _title.text, 'descripcion': _body.text, 'persona': _target ?? '', 'id': _id, 'dia': _day.toIso8601String(), 'entrega': _deadline.toIso8601String()});
        if (mounted) setState(() => _error = 'Borrador local guardado. Aún NO es una tarea asignada; vuelve a abrirlo y pulsa Guardar con conexión.');
      }
    } catch (_) {if (mounted) setState(() => _error = 'No se pudo guardar o recuperar el borrador.');}
  }
  Future<void> _save() async {
    if (_busy || _loading || !_form.currentState!.validate()) return;
    if (!_deadline.isAfter(_day)) {setState(() => _error = 'La entrega debe ser posterior al día de la tarea.'); return;}
    setState(() {_busy = true; _error = null;});
    try {
      final old = widget.actividadAEditar;
      final task = ActividadModel(id: _id, proyectoId: widget.proyectoId, titulo: _title.text.trim(), descripcion: _body.text.trim(),
        asignadoATrabajadorId: _target!, fechaInicio: old?.fechaInicio ?? _day, fechaAsignada: _day, fechaTermino: _deadline);
      if (old == null) {await ActividadesService().crearActividad(task);} else {await ActividadesService().actualizarActividad(task);}
      try {await OfflineWorkspace.remove(_uid, _draftKey);} catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarea guardada en el servidor. El aviso del teléfono se entrega por separado.')));
      Navigator.pop(context);
    } catch (e) {if (mounted) setState(() => _error = _explain(e));}
    finally {if (mounted) setState(() => _busy = false);}
  }
  Future<void> _date(bool deadline) async {
    final initial = deadline ? _deadline : _day;
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (d == null || !mounted) return;
    if (!deadline) {setState(() => _day = d); return;}
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_deadline));
    if (t != null && mounted) setState(() => _deadline = DateTime(d.year,d.month,d.day,t.hour,t.minute));
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Material(color: const Color(0xFF111012),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), child: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22,22,22,MediaQuery.viewInsetsOf(context).bottom+22), child: Form(key: _form, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.actividadAEditar == null ? 'Crear y asignar tarea' : 'Editar tarea', style: const TextStyle(fontSize: 23,fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), const Text('La tarea se confirma en el servidor. Sin conexión puedes conservar un borrador.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        Text(widget.proyectoId.isEmpty ? 'TAREA GENERAL · SIN PROYECTO' : 'TAREA VINCULADA AL PROYECTO', style: const TextStyle(color: Color(0xFFB7FF2A), fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 15),
        TextFormField(controller: _title, enabled: !_busy, maxLength: 150, decoration: const InputDecoration(labelText: 'Nombre de la tarea'), validator: (v) => (v?.trim().length ?? 0)<3 ? 'Escribe al menos 3 caracteres.' : null),
        TextFormField(controller: _body, enabled: !_busy, maxLength: 2000, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Indicaciones y evidencia requerida')),
        if (_loading) const LinearProgressIndicator() else DropdownButtonFormField<String>(initialValue: _target, key: ValueKey('$_target:${_people.length}'), isExpanded: true,
          decoration: const InputDecoration(labelText: 'Asignar a'), items: _people.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['nombre']!, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _target = v), validator: (v) => v == null ? 'Selecciona a una persona.' : null),
        Wrap(spacing: 8, children: [TextButton.icon(onPressed: _busy ? null : () => _date(false), icon: const Icon(Icons.today_outlined), label: Text('Día ${DateFormat('dd/MM').format(_day)}')),
          TextButton.icon(onPressed: _busy ? null : () => _date(true), icon: const Icon(Icons.event_available_outlined), label: Text('Entrega ${DateFormat('dd/MM HH:mm').format(_deadline)}'))]),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
        if (!_loading && _people.isEmpty) TextButton(onPressed: _busy ? null : _load, child: const Text('Volver a cargar integrantes')),
        FilledButton.icon(onPressed: _busy || _loading ? null : _save, icon: const Icon(Icons.add_task_rounded), label: Text(_busy ? 'Confirmando…' : 'Guardar y asignar')),
        Wrap(spacing: 8, children: [TextButton(onPressed: _busy ? null : () => _draft(), child: const Text('Guardar borrador local')), TextButton(onPressed: _busy ? null : () => _draft(restore:true), child: const Text('Recuperar borrador'))]),
      ]))))));
}
