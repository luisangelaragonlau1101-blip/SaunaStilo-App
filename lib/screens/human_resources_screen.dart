import '../workflow/company_structure.dart';
import '../presentation/appearance.dart';
import '../widgets/soft_workspace.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/admin_workspace_service.dart';
import '../widgets/inventory_photo.dart';
import 'admin_asistencias_screen.dart';
import 'admin_inbox_screen.dart';
import 'admin_modal_horario.dart';
import 'perfiles_equipo_screen.dart';
import 'usuarios_crud_screen.dart';

class HumanResourcesScreen extends StatefulWidget {
  final UserModel user;
  const HumanResourcesScreen({super.key, required this.user});
  @override State<HumanResourcesScreen> createState() => _HumanResourcesState();
}
class _HumanResourcesState extends State<HumanResourcesScreen> {
  String search = '';
  bool activeOnly = true;
  String? department;
  @override Widget build(BuildContext context) {
    if (widget.user.rol != AppRoles.admin) return const Scaffold(body: Center(child: Text('Este espacio es exclusivo de Administración.')));
    void open(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(appBar: AppBar(title: const Text('Recursos Humanos')), body: ListView(padding: const EdgeInsets.all(20), children: [
      if (AppearanceController.instance.modern) const StiloSectionHero(eyebrow: 'STILO · PERSONAS', title: 'Un equipo que crece.', subtitle: 'Expedientes privados, incorporación, horarios, asistencia y nómina.', icon: Icons.groups_rounded)
      else ...[const Text('Personas y seguimiento', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Expedientes privados, incorporación, horarios, asistencia y nómina.')],
      const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: () => open(UsuariosCrudScreen()), icon: const Icon(Icons.person_add_alt), label: const Text('Altas y cuentas')),
        FilledButton.tonalIcon(onPressed: () => open(AdminAsistenciasScreen(nombreAdmin: widget.user.nombre)), icon: const Icon(Icons.receipt_long), label: const Text('Asistencia y nómina')),
        FilledButton.tonalIcon(onPressed: () => open(AdminInboxScreen(user: widget.user)), icon: const Icon(Icons.inbox_outlined), label: const Text('Solicitudes')),
        FilledButton.tonalIcon(onPressed: () => open(PerfilesEquipoScreen(usuarioActual: widget.user)), icon: const Icon(Icons.military_tech_outlined), label: const Text('Perfiles e insignias')),
      ]), const SizedBox(height: 20),
      TextField(decoration: const InputDecoration(labelText: 'Buscar persona, puesto o carrera', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => search = v.toLowerCase().trim())),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Solo cuentas activas'), value: activeOnly, onChanged: (v) => setState(() => activeOnly = v)),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('rh_expedientes').snapshots(), builder: (context, records) {
        if (records.hasError) return const Text('No se pudieron cargar los departamentos.');
        if (!records.hasData) return const LinearProgressIndicator();
        final personnel = {for (final d in records.data!.docs) d.id: d.data()};
        final areas = <String>{...companyDepartments, ...personnel.values.map((d) => (d['area'] ?? '').toString()).where((v) => v.isNotEmpty)}.toList()..sort();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Departamentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('Todos'), selected: department == null, onSelected: (_) => setState(() => department = null))),
            for (final area in areas) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(area), selected: department == area, onSelected: (_) => setState(() => department = area))),
          ])), const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('usuarios').snapshots(), builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('No se pudo consultar al equipo. Intenta abrir este espacio de nuevo.');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final people = snapshot.data!.docs.where((d) => (!activeOnly || d.data()['activo'] != false) && '${d.data()['nombre']} ${d.data()['rol']} ${personnel[d.id]?['puesto'] ?? ''} ${personnel[d.id]?['area'] ?? ''} ${personnel[d.id]?['carrera'] ?? ''}'.toLowerCase().contains(search) && (department == null || personnel[d.id]?['area'] == department)).toList()..sort((a,b) => (a.data()['nombre'] ?? '').toString().compareTo((b.data()['nombre'] ?? '').toString()));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${people.length} personas en esta vista'), const SizedBox(height: 12), for (final p in people) Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: ClipOval(child: SizedBox(width: 45, height: 45, child: (p.data()['fotoUrl'] ?? '').toString().isEmpty ? const Icon(Icons.person_outline) : InventoryPhoto(imageUrl: p.data()['fotoUrl'], fit: BoxFit.cover))), title: Text(p.data()['nombre'] ?? 'Integrante'), subtitle: Text('${personnel[p.id]?['puesto'] ?? p.data()['rol']} · ${personnel[p.id]?['area'] ?? 'Sin departamento'}${personnel[p.id]?['practicante'] == true ? '\nPrácticas · ${personnel[p.id]?['carrera'] ?? ''}' : ''} · ${p.data()['activo'] == false ? 'Inactiva' : 'Activa'}'), trailing: const Icon(Icons.chevron_right), onTap: () => open(PersonnelRecordScreen(user: widget.user, person: UserModel.fromFirestore(p)))))]);
      }),
        ]);
      }),
    ]));
  }
}

class PersonnelRecordScreen extends StatefulWidget {
  final UserModel user, person;
  const PersonnelRecordScreen({super.key, required this.user, required this.person});
  @override State<PersonnelRecordScreen> createState() => _PersonnelRecordState();
}
class _PersonnelRecordState extends State<PersonnelRecordScreen> {
  final career = TextEditingController(), school = TextEditingController(), mentor = TextEditingController();
  bool intern = false;
  final position = TextEditingController(), area = TextEditingController(), contract = TextEditingController(), notes = TextEditingController();
  DateTime? entry;
  bool induction = false, equipment = false, documents = false, loading = true, busy = false, ready = false;
  String? error;
  @override void initState() { super.initState(); if (widget.user.rol == AppRoles.admin) _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; ready = false; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('rh_expedientes').doc(widget.person.id).get(const GetOptions(source: Source.server));
      if (!mounted) return;
      final d = snapshot.data() ?? {};
      position.text = d['puesto'] ?? ''; area.text = d['area'] ?? ''; contract.text = d['contrato'] ?? ''; notes.text = d['notas'] ?? '';
      intern = d['practicante'] == true; career.text = d['carrera'] ?? ''; school.text = d['institucion'] ?? ''; mentor.text = d['tutor'] ?? '';
      entry = (d['ingreso'] as Timestamp?)?.toDate(); induction = d['induccion'] == true; equipment = d['equipoEntregado'] == true; documents = d['documentosRevisados'] == true; ready = true;
    } catch (_) { if (mounted) setState(() => error = 'No se pudo abrir el expediente. Reintenta antes de editar.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _save() async {
    if (!ready || busy) return;
    if (intern && career.text.trim().isEmpty) { setState(() => error = 'Agrega la carrera del practicante.'); return; }
    setState(() {busy = true; error = null;});
    try {
      await AdminWorkspaceService().savePersonnel(widget.person.id, {'puesto': position.text.trim(), 'area': area.text.trim(), 'contrato': contract.text.trim(), 'notas': notes.text.trim(), 'ingreso': entry == null ? null : Timestamp.fromDate(entry!), 'induccion': induction, 'equipoEntregado': equipment, 'documentosRevisados': documents, 'practicante': intern, 'carrera': career.text.trim(), 'institucion': school.text.trim(), 'tutor': mentor.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expediente guardado. Solo Administración puede verlo.')));
    } catch (_) { if (mounted) setState(() => error = 'No se confirmó el guardado. Tus cambios siguen aquí para reintentar.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Widget _suggestions(TextEditingController controller, List<String> options) => PopupMenuButton<String>(
    enabled: !busy && ready, tooltip: 'Elegir una sugerencia', icon: const Icon(Icons.expand_more),
    onSelected: (v) => setState(() => controller.text = v), itemBuilder: (_) => [for (final option in options) PopupMenuItem(value: option, child: Text(option))]);
  @override void dispose() { position.dispose(); area.dispose(); contract.dispose(); notes.dispose(); career.dispose(); school.dispose(); mentor.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (widget.user.rol != AppRoles.admin) return const Scaffold(body: Center(child: Text('Solo Administración.')));
    return Scaffold(appBar: AppBar(title: Text(widget.person.nombre)), body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Expediente privado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Esta información no se publica en el perfil social.'), const SizedBox(height: 20),
      if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), TextButton(onPressed: busy ? null : _load, child: const Text('Recargar expediente'))],
      for (final item in [(position, 'Puesto'), (area, 'Área'), (contract, 'Tipo o referencia de contrato')]) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: item.$1, maxLength: 160, enabled: !busy && ready, decoration: InputDecoration(labelText: item.$2, suffixIcon: item.$1 == contract ? null : _suggestions(item.$1, item.$1 == position ? companyPositions : companyDepartments)))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Practicante / estancia profesional'), subtitle: const Text('El puesto y el departamento conservan los permisos de su cuenta.'), value: intern, onChanged: busy || !ready ? null : (v) => setState(() => intern = v)),
      if (intern) ...[
        TextField(controller: career, maxLength: 160, enabled: !busy && ready, decoration: InputDecoration(labelText: 'Carrera', suffixIcon: _suggestions(career, internshipCareers))),
        TextField(controller: school, maxLength: 160, enabled: !busy && ready, decoration: const InputDecoration(labelText: 'Institución educativa')),
        TextField(controller: mentor, maxLength: 160, enabled: !busy && ready, decoration: const InputDecoration(labelText: 'Responsable / tutor de prácticas')),
      ],
      OutlinedButton.icon(onPressed: busy || !ready ? null : () async { final date = await showDatePicker(context: context, initialDate: entry ?? DateTime.now(), firstDate: DateTime(1980), lastDate: DateTime(2100)); if (date != null && mounted) setState(() => entry = date); }, icon: const Icon(Icons.event), label: Text(entry == null ? 'Fecha de ingreso' : 'Ingreso: ${DateFormat('dd/MM/yyyy').format(entry!)}')),
      const SizedBox(height: 16), const Text('Incorporación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      CheckboxListTile(title: const Text('Inducción completada'), value: induction, onChanged: busy ? null : (v) => setState(() => induction = v!)),
      CheckboxListTile(title: const Text('Equipo y herramientas entregados'), value: equipment, onChanged: busy ? null : (v) => setState(() => equipment = v!)),
      CheckboxListTile(title: const Text('Documentación revisada'), value: documents, onChanged: busy ? null : (v) => setState(() => documents = v!)),
      TextField(controller: notes, maxLength: 2000, minLines: 3, maxLines: 6, enabled: !busy && ready, decoration: const InputDecoration(labelText: 'Notas de seguimiento')),
      const SizedBox(height: 16), FilledButton.icon(onPressed: busy || !ready ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(busy ? 'Guardando…' : 'Guardar expediente')),
      TextButton.icon(onPressed: busy ? null : () => mostrarModalHorario(context, widget.person.id, widget.person.nombre), icon: const Icon(Icons.schedule), label: const Text('Horario de trabajo')),
    ]));
  }
}
