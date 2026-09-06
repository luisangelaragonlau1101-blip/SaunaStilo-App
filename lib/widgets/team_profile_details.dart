import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/team_profile_helpers.dart';
import 'stilo_orbit.dart';

const recognitionIcons = <String, IconData>{'calidad': Icons.verified_rounded, 'sauna': Icons.local_fire_department_rounded, 'equipo': Icons.groups_rounded, 'maestria': Icons.handyman_rounded, 'seguridad': Icons.shield_rounded, 'innovacion': Icons.auto_awesome_rounded, 'puntualidad': Icons.timer_rounded, 'lugar': Icons.location_on_rounded};

class TeamProfileDetails extends StatelessWidget {
  final UserModel usuarioActual;
  final String perfilId;
  final Map<String, dynamic> data;
  const TeamProfileDetails({super.key, required this.usuarioActual, required this.perfilId, required this.data});
  bool get _admin => usuarioActual.rol == AppRoles.admin;
  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance.collection('usuarios').doc(perfilId);
  @override
  Widget build(BuildContext context) {
    final interests = profileTags(data['intereses']);
    final colors = profileTags(data['coloresFavoritos']);
    final badges = data['insigniasAdmin'] is List ? (data['insigniasAdmin'] as List).whereType<Map>().toList() : <Map>[];
    final places = data['lugaresInstalacion'] is List ? (data['lugaresInstalacion'] as List).whereType<Map>().toList() : <Map>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      _section(context, 'LO QUE ME GUSTA', Icons.favorite_outline_rounded, () => _editInterests(context), editable: _admin || usuarioActual.id == perfilId),
      const Text('Información opcional, compartida con el equipo.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 10),
      if (interests.isEmpty && colors.isEmpty) const Text('Aún no ha agregado sus gustos.', style: TextStyle(color: Colors.white60)),
      Wrap(spacing: 7, runSpacing: 5, children: [
        for (final interest in interests) Chip(avatar: const Icon(Icons.favorite_border, size: 16), label: Text(interest)),
        for (final color in colors) Chip(avatar: const Icon(Icons.palette_outlined, size: 16), label: Text(color)),
      ]),
      const SizedBox(height: 16),
      _section(context, 'INSIGNIAS DE ADMINISTRACIÓN', Icons.workspace_premium_outlined, () => _add(context, 'insigniasAdmin', 'Otorgar insignia', 'Nombre de la insignia', 'Motivo del reconocimiento', badges.length), editable: _admin),
      if (badges.isEmpty) const Text('Sin reconocimientos manuales todavía.', style: TextStyle(color: Colors.white60)),
      for (final b in badges) _entry(context, b, 'insigniasAdmin', Icons.verified_outlined),
      const SizedBox(height: 16),
      _section(context, 'ESTADOS Y LUGARES DE INSTALACIÓN', Icons.location_on_outlined, () => _add(context, 'lugaresInstalacion', 'Agregar lugar', 'Estado y ciudad donde participó', 'Proyecto o participación (opcional)', places.length), editable: _admin),
      if (places.isEmpty) const Text('Administración puede agregar la trayectoria de esta persona.', style: TextStyle(color: Colors.white60)),
      for (final p in places) _entry(context, p, 'lugaresInstalacion', Icons.place_outlined),
    ]);
  }
  Widget _section(BuildContext context, String title, IconData icon, VoidCallback action, {required bool editable}) => Row(children: [
    Icon(icon, size: 19, color: const Color(0xFFB7FF2A)), const SizedBox(width: 8),
    Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5))),
    if (editable) IconButton(tooltip: title == 'LO QUE ME GUSTA' ? 'Editar mis gustos' : 'Agregar', onPressed: action, icon: Icon(title == 'LO QUE ME GUSTA' ? Icons.edit_outlined : Icons.add_circle_outline)),
  ]);
  Widget _entry(BuildContext context, Map item, String field, IconData icon) => Card(color: const Color(0xFF171217), child: ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    leading: StiloOrbitIcon(icon: recognitionIcons[item['icono']] ?? icon, color: stiloAccents[(item['acento'] is int && item['acento'] >= 0 ? item['acento'] as int : (item['nombre']?.toString().length ?? 0)) % stiloAccents.length], size: 44, active: true),
    title: Text(item['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: (item['detalle']?.toString() ?? '').isEmpty ? null : Text(item['detalle'].toString()),
    trailing: !_admin ? null : IconButton(tooltip: 'Quitar de este perfil', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () async {
      final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('¿Quitar este registro?'), content: Text(item['nombre']?.toString() ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar'))]));
      if (yes == true && context.mounted) {
        try { await _ref.update({field: FieldValue.arrayRemove([Map<String, dynamic>.from(item)])}); }
        catch (_) { if (context.mounted) _notice(context, 'No se confirmó el cambio. Revisa tu conexión y los permisos de Administración.'); }
      }
    }),
  ));
  Future<void> _editInterests(BuildContext context) async {
    final interests = TextEditingController(text: profileTags(data['intereses']).join(', '));
    final colors = TextEditingController(text: profileTags(data['coloresFavoritos']).join(', '));
    await _form(context, title: 'Mis gustos', first: interests, firstLabel: 'Intereses y cosas que me gustan', firstMax: 400, second: colors, secondLabel: 'Colores favoritos, separados por comas', secondMax: 160, requiredFirst: false, save: () => _ref.update({'intereses': interests.text.trim(), 'coloresFavoritos': colors.text.trim()}));
    interests.dispose(); colors.dispose();
  }
  Future<void> _add(BuildContext context, String field, String title, String label, String detail, int count) async {
    if (!_admin) return;
    if (count >= 60) { _notice(context, 'Este perfil alcanzó 60 registros. Quita uno antes de agregar otro.'); return; }
    final first = TextEditingController(); final second = TextEditingController();
    String iconKey = field == 'lugaresInstalacion' ? 'lugar' : 'calidad'; int accent = 0;
    await _form(context, title: title, first: first, firstLabel: label, firstMax: 100, second: second, secondLabel: detail, secondMax: 200, requiredFirst: true, styleChanged: (icon, color) {iconKey = icon; accent = color;}, initialIcon: iconKey, save: () => _ref.update({field: FieldValue.arrayUnion([{'nombre': first.text.trim(), 'detalle': second.text.trim(), 'icono': iconKey, 'acento': accent, 'otorgadoPor': usuarioActual.id, 'registradoEn': DateTime.now().toUtc().toIso8601String()}])}));
    first.dispose(); second.dispose();
  }
  Future<void> _form(BuildContext context, {required String title, required TextEditingController first, required String firstLabel, required int firstMax, required TextEditingController second, required String secondLabel, required int secondMax, required bool requiredFirst, required Future<void> Function() save, void Function(String, int)? styleChanged, String initialIcon = 'calidad'}) async {
    bool busy = false; String? error; String chosenIcon = initialIcon; int chosenAccent = 0;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (dialog) => StatefulBuilder(builder: (c, update) => PopScope(canPop: !busy, child: AlertDialog(
      title: Text(title), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: first, maxLength: firstMax, enabled: !busy, decoration: InputDecoration(labelText: firstLabel)),
        TextField(controller: second, maxLength: secondMax, enabled: !busy, maxLines: 2, decoration: InputDecoration(labelText: secondLabel)),
        if (styleChanged != null) ...[
          const Text('Elige el símbolo y su color', style: TextStyle(color: Colors.white70)),
          Wrap(spacing: 6, runSpacing: 8, children: [for (final e in recognitionIcons.entries) IconButton(tooltip: e.key, onPressed: busy ? null : () {update(() => chosenIcon = e.key); styleChanged(chosenIcon, chosenAccent);}, icon: StiloOrbitIcon(icon: e.value, color: stiloAccents[chosenAccent], size: 36, active: chosenIcon == e.key))]),
          Wrap(spacing: 8, children: List.generate(stiloAccents.length, (i) => IconButton(tooltip: 'Color ${i + 1}', onPressed: busy ? null : () {update(() => chosenAccent = i); styleChanged(chosenIcon, chosenAccent);}, icon: Icon(chosenAccent == i ? Icons.check_circle_rounded : Icons.circle, color: stiloAccents[i])))),
        ],
        const Text('No incluyas domicilios de clientes, contraseñas ni información privada.', style: TextStyle(fontSize: 11, color: Colors.white54)),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
      ])), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(dialog), child: const Text('Cancelar')), FilledButton(onPressed: busy ? null : () async {
        if (requiredFirst && first.text.trim().isEmpty) { update(() => error = 'Escribe un nombre.'); return; }
        update(() {busy = true; error = null;});
        try { await save(); if (dialog.mounted) Navigator.pop(dialog); }
        catch (_) { if (dialog.mounted) update(() {busy = false; error = 'No se guardó. Revisa Internet y los permisos del servidor; el texto sigue aquí.';}); }
      }, child: Text(busy ? 'Guardando…' : 'Guardar'))],
    ))));
  }
  void _notice(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
