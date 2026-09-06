import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/profile_social_links.dart';
import 'stilo_orbit.dart';

const networkIcons = <String, IconData>{
  'instagram': Icons.camera_alt_outlined, 'facebook': Icons.facebook_rounded,
  'tiktok': Icons.music_note_rounded, 'spotify': Icons.graphic_eq_rounded,
  'youtube': Icons.smart_display_outlined, 'x': Icons.alternate_email_rounded,
  'linkedin': Icons.work_outline_rounded, 'web': Icons.language_rounded, 'otro': Icons.link_rounded,
};

class ProfileNetworks extends StatelessWidget {
  final String profileId;
  final bool editable;
  final dynamic data;
  const ProfileNetworks({super.key, required this.profileId, required this.editable, this.data});
  @override
  Widget build(BuildContext context) {
    final links = ProfileSocialLinks.fromData(data);
    return Padding(padding: const EdgeInsets.only(top: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('MI MUNDO · REDES Y MÚSICA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .7))),
        if (editable) IconButton(tooltip: 'Editar mis redes', icon: const Icon(Icons.add_link_rounded),
          onPressed: () => showDialog<void>(context: context, barrierDismissible: false,
            builder: (_) => ProfileNetworksEditor(initial: links, save: (value) => FirebaseFirestore.instance.collection('usuarios').doc(profileId).update({'redesSociales': value}))))]),
      const Text('Opcional. Tus enlaces serán visibles para el equipo. Se abren solo al tocarlos.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5)),
      const SizedBox(height: 10),
      if (links.isEmpty) const Text('Un espacio para tus redes, tu música y lo que te inspira.', style: TextStyle(color: Colors.white60, height: 1.4)),
      Wrap(spacing: 8, runSpacing: 8, children: links.entries.map((e) {
        final color = stiloAccents[ProfileSocialLinks.platforms.keys.toList().indexOf(e.key) % stiloAccents.length];
        return ActionChip(shape: const StadiumBorder(), side: BorderSide(color: color.withOpacity(.3)),
          backgroundColor: const Color(0xFF171217), avatar: Icon(networkIcons[e.key], color: color, size: 19),
          label: Text(ProfileSocialLinks.platforms[e.key]!), onPressed: () async {
            try { if (!await launchUrl(Uri.parse(e.value), mode: LaunchMode.externalApplication)) throw StateError('open'); }
            catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace. Revisa tu navegador.'))); }
          });
      }).toList()),
    ]));
  }
}

class ProfileNetworksEditor extends StatefulWidget {
  final Map<String, String> initial;
  final Future<void> Function(Map<String, String>) save;
  const ProfileNetworksEditor({super.key, required this.initial, required this.save});
  @override
  State<ProfileNetworksEditor> createState() => _ProfileNetworksEditorState();
}
class _ProfileNetworksEditorState extends State<ProfileNetworksEditor> {
  late final _controllers = {for (final key in ProfileSocialLinks.platforms.keys) key: TextEditingController(text: widget.initial[key] ?? '')};
  final _form = GlobalKey<FormState>();
  bool _busy = false; String? _error;
  @override
  void dispose() {for (final c in _controllers.values) {c.dispose();} super.dispose();}
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), title: const Text('Tus redes. Tu estilo.'),
    content: SizedBox(width: 410, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Pega los enlaces de tus perfiles. Deja un campo vacío para quitarlo. Nunca incluyas contraseñas.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
      for (final entry in ProfileSocialLinks.platforms.entries) Padding(padding: const EdgeInsets.only(top: 12), child: TextFormField(
        controller: _controllers[entry.key], enabled: !_busy, keyboardType: TextInputType.url,
        autocorrect: false, maxLength: 500, decoration: InputDecoration(labelText: entry.value, hintText: 'https://…', counterText: '', prefixIcon: Icon(networkIcons[entry.key])),
        validator: (v) {try {ProfileSocialLinks.normalize(entry.key, v ?? ''); return null;} on FormatException catch (e) {return e.message;}})),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
    ])))),
    actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _busy ? null : () async {
        if (!_form.currentState!.validate()) return;
        setState(() {_busy = true; _error = null;});
        try {
          final values = <String, String>{};
          for (final entry in _controllers.entries) {final value = ProfileSocialLinks.normalize(entry.key, entry.value.text); if (value.isNotEmpty) values[entry.key] = value;}
          await widget.save(values);
          if (mounted) Navigator.pop(context);
        } catch (_) {if (mounted) setState(() {_busy = false; _error = 'No se confirmó el guardado. Revisa la conexión y los permisos. Tus enlaces siguen aquí.';});}
      }, child: Text(_busy ? 'Guardando…' : 'Guardar redes'))],
  ));
}
