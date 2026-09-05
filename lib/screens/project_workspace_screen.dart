import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../models/actividad_model.dart';
import '../services/actividades_service.dart';
import 'proyecto_chat_screen.dart';
import 'proyectos_admin_screen.dart';
import 'proyectos_trabajador_screen.dart';
import 'modal_asignar_actividades.dart';

class ProjectWorkspaceScreen extends StatelessWidget {
  final UserModel usuario;
  const ProjectWorkspaceScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) {
    final admin = usuario.rol == AppRoles.admin;
    final query = admin ? FirebaseFirestore.instance.collection('proyectos') : FirebaseFirestore.instance.collection('proyectos').where('encargados', arrayContains: usuario.id);
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Proyectos y grupos'), actions: [
      IconButton(tooltip: 'Administrar proyectos', icon: const Icon(Icons.tune_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => admin ? const ProyectosAdminScreen() : ProyectosTrabajadorScreen(esMaestro: usuario.rol == AppRoles.maestro)))),
    ]), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(), builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudieron consultar tus proyectos. Revisa Internet y los permisos de tu cuenta.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final projects = snapshot.data!.docs.map(Proyecto.fromFirestore).toList();
      return ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF180C11), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF68243B))), child: const Text('Cada proyecto tiene su propio grupo. Aquí se reúnen sus fotografías, audios, comentarios y evidencias; no necesitas crear un chat duplicado.', style: TextStyle(color: Colors.white70, height: 1.4))),
        const SizedBox(height: 16),
        if (projects.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes proyectos asignados. Administración puede añadirte al equipo de un proyecto.')),
        for (final project in projects) Card(color: const Color(0xFF111012), margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.workspaces_outline, color: Color(0xFFB7FF2A)), const SizedBox(width: 10), Expanded(child: Text(project.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)))]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(icon: const Icon(Icons.forum_outlined), label: const Text('Grupo y evidencias'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProyectoChatScreen(proyecto: project)))),
            if (admin || usuario.rol == AppRoles.maestro) OutlinedButton.icon(icon: const Icon(Icons.add_task_rounded), label: const Text('Asignar actividad'), onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => ModalAsignarActividad(proyectoId: project.id, rolUsuario: usuario.rol))),
          ]),
        ]))),
      ]);
    }));
  }
}

class ProjectTaskComposer extends StatefulWidget {
  final UserModel usuario;
  final Proyecto proyecto;
  const ProjectTaskComposer({super.key, required this.usuario, required this.proyecto});
  @override
  State<ProjectTaskComposer> createState() => _ProjectTaskComposerState();
}
class _ProjectTaskComposerState extends State<ProjectTaskComposer> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final String _requestId;
  String? _target;
  String? _error;
  bool _busy = false;
  late DateTime _deadline;
  late Future<QuerySnapshot<Map<String, dynamic>>> _people;
  @override
  void initState() {
    super.initState();
    _requestId = FirebaseFirestore.instance.collection('actividades').doc().id;
    final now = DateTime.now();
    _deadline = DateTime(now.year, now.month, now.day + 1, 19);
    _people = FirebaseFirestore.instance.collection('usuarios').get();
  }
  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.usuario.rol == AppRoles.admin) {
        final now = DateTime.now();
        await ActividadesService().crearActividad(ActividadModel(id: _requestId, proyectoId: widget.proyecto.id, titulo: _title.text.trim(), descripcion: _description.text.trim(), asignadoATrabajadorId: _target!, fechaInicio: now, fechaAsignada: now, fechaTermino: _deadline));
      } else {
        final result = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('assignProjectActivity', options: HttpsCallableOptions(timeout: const Duration(seconds: 30))).call({
          'requestId': _requestId, 'proyectoId': widget.proyecto.id, 'trabajadorId': _target,
          'titulo': _title.text.trim(), 'descripcion': _description.text.trim(), 'fechaTermino': _deadline.toUtc().toIso8601String(),
        });
        if (result.data is! Map || result.data['exito'] != true) throw StateError('El servidor no confirmó la asignación.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad guardada. El integrante la verá en sus tareas.')));
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.code == 'not-found' ? 'Administración debe activar assignProjectActivity en Firebase. Tu tarea no se ha guardado.' : e.code == 'permission-denied' ? 'Solo puedes asignar actividades dentro de tus proyectos y a sus integrantes.' : 'No se confirmó la asignación. Revisa Internet y las tareas del proyecto antes de reintentar.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se confirmó la asignación. Revisa los permisos, la conexión y las tareas existentes.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Asignar actividad · ${widget.proyecto.titulo}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
    const SizedBox(height: 18),
    TextFormField(controller: _title, maxLength: 150, enabled: !_busy, decoration: const InputDecoration(labelText: 'Actividad'), validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Describe la actividad.' : null),
    TextFormField(controller: _description, maxLength: 2000, minLines: 2, maxLines: 4, enabled: !_busy, decoration: const InputDecoration(labelText: 'Indicaciones y evidencia requerida')),
    const SizedBox(height: 12),
    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(future: _people, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton(onPressed: () => setState(() => _people = FirebaseFirestore.instance.collection('usuarios').get()), child: const Text('No se cargó el equipo. Reintentar'));
      final members = (snapshot.data?.docs ?? []).where((d) => widget.proyecto.encargados.contains(d.id) && [AppRoles.maestro, AppRoles.trabajador].contains(d.data()['rol'])).toList();
      return DropdownButtonFormField<String>(isExpanded: true, value: _target, decoration: const InputDecoration(labelText: 'Integrante del proyecto'), items: members.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['nombre']?.toString() ?? 'Integrante', overflow: TextOverflow.ellipsis))).toList(), onChanged: _busy ? null : (v) => setState(() => _target = v), validator: (v) => v == null ? 'Selecciona un integrante asignado a este proyecto.' : null);
    }),
    const SizedBox(height: 12),
    OutlinedButton.icon(icon: const Icon(Icons.event_outlined), label: Text('Entrega: ${DateFormat('dd/MM/yyyy HH:mm').format(_deadline)}'), onPressed: _busy ? null : () async {
      final day = await showDatePicker(context: context, initialDate: _deadline, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (day == null || !context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_deadline));
      if (time != null && mounted) setState(() => _deadline = DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }),
    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('La actividad requerirá evidencia. El maestro solo puede asignar a integrantes de su proyecto.', style: TextStyle(color: Colors.white60, fontSize: 12))),
    if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
    FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.add_task_rounded), label: Text(_busy ? 'Guardando…' : 'Asignar tarea')),
  ]))));
}
