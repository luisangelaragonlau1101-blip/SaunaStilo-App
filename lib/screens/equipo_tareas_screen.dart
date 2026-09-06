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

class EquipoTareasScreen extends StatefulWidget {
  final UserModel usuario;
  const EquipoTareasScreen({super.key, required this.usuario});
  @override
  State<EquipoTareasScreen> createState() => _EquipoTareasScreenState();
}
class _EquipoTareasScreenState extends State<EquipoTareasScreen> {
  String? _proyectoId;
  String _proyectoTitulo = 'Mis tareas';
  bool _soloPendientes = true;
  bool get _admin => widget.usuario.rol == AppRoles.admin;
  bool get _puedeAsignar => _admin || widget.usuario.rol == AppRoles.maestro;

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
        backgroundColor: Colors.transparent, builder: (_) => _admin
          ? admin.ModalDetalleActividad(actividad: tarea)
          : worker.ModalDetalleActividad(actividad: tarea));
    } else {
      showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text(tarea.titulo), content: SingleChildScrollView(child: Text(
          '${tarea.descripcion}\n\nEstado: ${tarea.estatus}\nEvidencias: ${tarea.totalEvidencias}\nEntrega: ${DateFormat('dd/MM HH:mm').format(tarea.fechaTermino)}\n\nLos avances los registra la persona asignada.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
    }
  }
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('actividades');
    if (_proyectoId != null) { query = query.where('proyectoId', isEqualTo: _proyectoId); }
    else if (!_admin) { query = query.where('asignadoATrabajadorId', isEqualTo: widget.usuario.id); }
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(title: Text(_admin ? 'Tareas del equipo' : 'Mis tareas'), actions: [
        if (_puedeAsignar) IconButton(tooltip: 'Crear y asignar tarea', onPressed: () => _seleccionarProyecto(crear: true), icon: const Icon(Icons.add_task_rounded)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Wrap(spacing: 8, runSpacing: 6, children: [
          ActionChip(avatar: const Icon(Icons.folder_open_rounded, size: 18), label: Text(_proyectoId == null ? 'Por proyecto' : _proyectoTitulo), onPressed: _seleccionarProyecto),
          if (_proyectoId != null) ActionChip(label: const Text('Ver mis tareas'), onPressed: () => setState(() => _proyectoId = null)),
          FilterChip(label: const Text('Pendientes'), selected: _soloPendientes, onSelected: (v) => setState(() => _soloPendientes = v)),
        ])),
        if (_puedeAsignar) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: SizedBox(width: double.infinity,
          child: FilledButton.icon(onPressed: () => _seleccionarProyecto(crear: true), icon: const Icon(Icons.add_rounded), label: const Text('Crear actividad y asignar tarea')))),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(includeMetadataChanges: true), builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No pudimos consultar estas tareas. Revisa tu conexión o pide a Administración que confirme tu asignación al proyecto.')));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tareas = snapshot.data!.docs.map((d) => ActividadModel.fromJson(d.data(), d.id)).where((t) => !_soloPendientes || t.estatus != 'completado').toList()
            ..sort((a,b) => a.fechaTermino.compareTo(b.fechaTermino));
          if (tareas.isEmpty) return Center(child: Text(snapshot.data!.metadata.isFromCache ? 'Sin tareas guardadas en este dispositivo. Conecta para consultar el servidor.' : 'No hay tareas en esta vista.'));
          return Column(children: [OfflineDataBadge(cached: snapshot.data!.metadata.isFromCache, pending: snapshot.data!.metadata.hasPendingWrites), Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), itemCount: tareas.length, itemBuilder: (context, i) {
            final t = tareas[i];
            return Card(child: ListTile(contentPadding: const EdgeInsets.all(16),
              leading: Icon(t.estatus == 'completado' ? Icons.task_alt_rounded : Icons.assignment_outlined, color: const Color(0xFFB7FF2A)),
              title: Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t.estatus} · ${t.totalEvidencias} evidencias\n${DateFormat('dd/MM · HH:mm').format(t.fechaTermino)}'),
              trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _abrir(t)));
          }))]);
        })),
      ]));
  }
}
