import '../presentation/appearance.dart';
export 'work_workspace_screen.dart' show EquipoTareasScreen;
import 'project_workspace_screen.dart';
import 'daily_tasks_screen.dart';
import 'extra_work_screen.dart';
import '../workflow/staff_policy.dart';
import '../widgets/project_progress_card.dart';
import '../widgets/task_creation_choice.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/offline_workspace.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../widgets/project_picker.dart';
import 'modal_asignar_actividades.dart';
import 'trabajador_modal_detalle_actividad.dart' as worker;
import 'admin_modal_detalle_actividad.dart' as admin;

class ProjectActivitiesScreen extends StatefulWidget {
  final UserModel usuario;
  final bool embedded;
  const ProjectActivitiesScreen({super.key, required this.usuario, this.embedded = false});
  @override
  State<ProjectActivitiesScreen> createState() => _ProjectActivitiesScreenState();
}
class _ProjectActivitiesScreenState extends State<ProjectActivitiesScreen> {
  String? _proyectoId;
  String _proyectoTitulo = 'Mis tareas';
  bool _soloPendientes = true;
  bool get _admin => widget.usuario.rol == AppRoles.admin;
  bool get _puedeAsignar => canAssignWork(widget.usuario.rol);

  Future<void> _crearTarea() async {
    if (!_puedeAsignar) return;
    await _seleccionarProyecto(crear: true);
  }
  Future<void> _seleccionarProyecto({bool crear = false}) async {
    final proyecto = await elegirProyecto(context, widget.usuario,
      titulo: crear ? 'Proyecto para la nueva tarea' : 'Tareas de un proyecto');
    if (!mounted || proyecto == null) return;
    setState(() { _proyectoId = proyecto.id; _proyectoTitulo = proyecto.titulo; });
    if (crear) await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, builder: (_) => ModalAsignarActividad(
        proyectoId: proyecto.id, rolUsuario: widget.usuario.rol));
  }
  void _abrir(ActividadModel tarea) {
    if (_admin || tarea.asignadoATrabajadorId == widget.usuario.id) {
      showModalBottomSheet<void>(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent, builder: (_) => _admin && tarea.asignadoATrabajadorId != widget.usuario.id
          ? admin.ModalDetalleActividad(actividad: tarea)
          : worker.ModalDetalleActividad(actividad: tarea));
    } else {
      showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text(tarea.titulo), content: SingleChildScrollView(child: Text(
          '${tarea.descripcion}\n\nEstado: ${tarea.estatus}\nEvidencias: ${tarea.totalEvidencias}\nEntrega: ${DateFormat('dd/MM HH:mm').format(tarea.fechaTermino)}\n\nLos avances los registra la persona asignada.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cerrar'))]));
    }
  }
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('actividades');
    if (_proyectoId != null) { query = query.where('proyectoId', isEqualTo: _proyectoId); }
    else if (!_admin) { query = query.where('asignadoATrabajadorId', isEqualTo: widget.usuario.id); }
    return Scaffold(backgroundColor: StiloColors.background,
      appBar: widget.embedded ? null : AppBar(title: Text('Actividades de proyectos')),
      body: Column(children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Wrap(spacing: 8, runSpacing: 6, children: [
          ActionChip(avatar: Icon(Icons.folder_open_rounded, size: 18), label: Text(_proyectoId == null ? 'Por proyecto' : _proyectoTitulo), onPressed: _seleccionarProyecto),
          if (_proyectoId != null) ActionChip(label: Text('Ver mis tareas'), onPressed: () => setState(() => _proyectoId = null)),
          FilterChip(label: Text('Pendientes'), selected: _soloPendientes, onSelected: (v) => setState(() => _soloPendientes = v)),
        ])),
        if (_puedeAsignar) Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: SizedBox(width: double.infinity,
          child: FilledButton.icon(onPressed: _crearTarea, icon: Icon(Icons.add_rounded), label: Text('Asignar actividad de proyecto')))),
        if (!_puedeAsignar) Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 10), child: Column(children: [Text('Completa tus asignaciones y añade evidencias. No puedes cambiar sus instrucciones ni asignarte tareas.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), fontSize: 12)), TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkScreen(user: widget.usuario))), icon: Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFB876)), label: Text('Reportar trabajo extra ya realizado'))])),
        if (_proyectoId != null) Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ProjectProgressCard(projectId: _proyectoId!)),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(includeMetadataChanges: true), builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No pudimos consultar estas tareas. Revisa tu conexión o pide a Administración que confirme tu asignación al proyecto.')));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final tareas = snapshot.data!.docs.map((d) => ActividadModel.fromJson(d.data(), d.id)).where((t) => !_soloPendientes || t.estatus != 'completado').toList()
            ..sort((a,b) => a.fechaTermino.compareTo(b.fechaTermino));
          if (tareas.isEmpty) return Center(child: Text(snapshot.data!.metadata.isFromCache ? 'Sin tareas guardadas en este dispositivo. Conecta para consultar el servidor.' : 'No hay tareas en esta vista.'));
          return Column(children: [OfflineDataBadge(cached: snapshot.data!.metadata.isFromCache, pending: snapshot.data!.metadata.hasPendingWrites), Expanded(child: ListView.builder(padding: EdgeInsets.fromLTRB(12, 0, 12, 24), itemCount: tareas.length, itemBuilder: (context, i) {
            final t = tareas[i];
            return Card(child: ListTile(contentPadding: EdgeInsets.all(16),
              leading: Icon(t.estatus == 'completado' ? Icons.task_alt_rounded : Icons.assignment_outlined, color: StiloColors.accent),
              title: Text(t.titulo, style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t.proyectoId.isEmpty ? 'General' : 'Proyecto'} · ${t.estatus} · ${t.totalEvidencias} evidencias\n${DateFormat('dd/MM · HH:mm').format(t.fechaTermino)}'),
              trailing: Icon(Icons.chevron_right_rounded), onTap: () => _abrir(t)));
          }))]);
        })),
      ]));
  }
}
