import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/team_notes_service.dart';
import '../services/profile_social_links.dart';
import 'stilo_orbit.dart';

class TeamNotesStrip extends StatefulWidget {
  final UserModel user;
  const TeamNotesStrip({super.key, required this.user});
  @override
  State<TeamNotesStrip> createState() => _TeamNotesStripState();
}
class _TeamNotesStripState extends State<TeamNotesStrip> {
  late final _service = TeamNotesService();
  late final _notes = _service.watch();
  void _edit(Map<String, dynamic>? data) => showDialog<void>(context: context, barrierDismissible: false,
    builder: (_) => TeamNoteEditor(initial: data, save: (draft) => _service.save(widget.user, draft),
      remove: data == null ? null : () => _service.remove(widget.user.id)));
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _notes, builder: (context, snapshot) {
    final docs = snapshot.data?.docs.toList() ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    docs.sort((a, b) {
      int rank(QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data()['fecha'] is Timestamp ? (d.data()['fecha'] as Timestamp).millisecondsSinceEpoch : 0;
      return rank(b).compareTo(rank(a));
    });
    Map<String, dynamic>? own;
    for (final d in docs) {if (d.id == 'nota_equipo_${widget.user.id}') own = d.data();}
    final canEdit = snapshot.hasData && !snapshot.hasError;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 5), child: Row(children: [
        const Icon(Icons.bubble_chart_rounded, color: Color(0xFFFF729C), size: 18), const SizedBox(width: 8),
        const Expanded(child: Text('Notas del equipo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        TextButton(onPressed: canEdit ? () => _edit(own) : null, child: Text(own == null ? 'Crear nota' : 'Mi nota')),
      ])),
      if (snapshot.hasError) const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 10), child: Text('No se pudieron leer las notas. Tus chats siguen disponibles.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)))
      else if (!snapshot.hasData) const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: LinearProgressIndicator())
      else SizedBox(height: 108, child: ListView.separated(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8), itemCount: docs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (context, i) {
          if (i == 0) return SizedBox(width: 98, child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(24), onTap: () => _edit(own), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const StiloOrbitIcon(icon: Icons.add_rounded, color: Color(0xFFB7FF2A), size: 46), const SizedBox(height: 7),
            Text(own == null ? 'Tu nota o canción' : 'Editar mi nota', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]))));
          final d = docs[i - 1].data();
          return TeamNotePreview(data: d, color: stiloAccents[(i - 1) % stiloAccents.length], onTap: () {
            if (docs[i - 1].id == 'nota_equipo_${widget.user.id}') {_edit(d); return;}
            showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              builder: (_) => TeamNoteDetails(data: d));
          });
        })),
    ]);
  });
}

class TeamNotePreview extends StatelessWidget {
  final Map<String, dynamic> data; final Color color; final VoidCallback onTap;
  const TeamNotePreview({super.key, required this.data, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(width: 164, child: Material(color: const Color(0xFF161116),
    borderRadius: BorderRadius.circular(25), child: InkWell(borderRadius: BorderRadius.circular(25), onTap: onTap,
      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(.36)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(.10), Colors.transparent])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon((data['musicaUrl'] ?? '').toString().isEmpty ? Icons.chat_bubble_outline_rounded : Icons.music_note_rounded, size: 16, color: color), const SizedBox(width: 6),
            Expanded(child: Text(data['autorNombre']?.toString() ?? 'Integrante', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 7),
          Expanded(child: Text((data['musicaUrl']?.toString() ?? '').isNotEmpty ? '♫ ${(data['musicaTitulo']?.toString() ?? '').isEmpty ? 'Canción compartida' : data['musicaTitulo']}' : data['notaTexto']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.white70))),
        ])),
    )));
}

class TeamNoteDetails extends StatelessWidget {
  final Map<String, dynamic> data;
  const TeamNoteDetails({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    String url = '';
    try {url = ProfileSocialLinks.music(data['musicaUrl']?.toString() ?? '');} on FormatException { /* Never launch unsafe stored content. */ }
    final link = url;
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const StiloOrbitIcon(icon: Icons.music_note_rounded, color: Color(0xFFC798FF), size: 58), const SizedBox(height: 14),
      Text(data['autorNombre']?.toString() ?? 'Integrante', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12), SelectableText(data['notaTexto']?.toString() ?? '', style: const TextStyle(fontSize: 18, height: 1.5)),
      if (link.isNotEmpty) ...[const SizedBox(height: 18), FilledButton.icon(icon: const Icon(Icons.play_arrow_rounded), label: Text((data['musicaTitulo']?.toString() ?? '').isEmpty ? 'Abrir canción' : data['musicaTitulo'].toString()), onPressed: () async {
        try {if (!await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)) throw StateError('open');}
        catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la canción.')));}
      }), Text(Uri.parse(link).host, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const Text('Canción compartida por esta persona; no es su reproducción en vivo. Se abre en el servicio de música sin reproducirse automáticamente.', style: TextStyle(color: Colors.white54, fontSize: 11))],
      const SizedBox(height: 18), const Text('Compartida con el equipo de Sauna Stilo.', style: TextStyle(color: Colors.white38, fontSize: 12)),
    ])));
  }
}

class TeamNoteEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final Future<void> Function(TeamNoteDraft) save;
  final Future<void> Function()? remove;
  const TeamNoteEditor({super.key, this.initial, required this.save, this.remove});
  @override
  State<TeamNoteEditor> createState() => _TeamNoteEditorState();
}
class _TeamNoteEditorState extends State<TeamNoteEditor> {
  late final _text = TextEditingController(text: widget.initial?['notaTexto']?.toString() ?? '');
  late final _song = TextEditingController(text: widget.initial?['musicaTitulo']?.toString() ?? '');
  late final _url = TextEditingController(text: widget.initial?['musicaUrl']?.toString() ?? '');
  bool _busy = false; String? _error;
  @override
  void dispose() {_text.dispose(); _song.dispose(); _url.dispose(); super.dispose();}
  Future<void> _save() async {
    try {
      final draft = TeamNoteDraft(text: _text.text, song: _song.text, url: _url.text).validated();
      setState(() {_busy = true; _error = null;});
      await widget.save(draft);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {setState(() => _error = e.message);}
    catch (_) {if (mounted) setState(() {_busy = false; _error = 'No se confirmó la publicación. Tu nota sigue aquí; revisa conexión y permisos.';});}
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), title: const Text('Una nota. Una canción. Tú.'),
    content: SizedBox(width: 390, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Visible para todo el equipo en Chats y Comunidad. Se conserva hasta que la cambies o elimines.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
      const SizedBox(height: 14), TextField(controller: _text, enabled: !_busy, maxLength: 180, maxLines: 3, decoration: const InputDecoration(labelText: 'Tu nota', hintText: '¿Qué quieres compartir?')),
      TextField(controller: _song, enabled: !_busy, maxLength: 100, decoration: const InputDecoration(labelText: 'Canción y artista (opcional)', prefixIcon: Icon(Icons.music_note_rounded))),
      TextField(controller: _url, enabled: !_busy, maxLength: 500, autocorrect: false, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Enlace de la canción (opcional)', hintText: 'Spotify, YouTube, Apple Music o SoundCloud', prefixIcon: Icon(Icons.link_rounded))),
      const Padding(padding: EdgeInsets.only(top: 10), child: Text('En Spotify: Compartir → Copiar enlace. Pégalo aquí con el nombre de la canción. Mostrar lo que suena en vivo requiere una conexión autorizada de Spotify; este enlace no da acceso a tu cuenta.', style: TextStyle(fontSize: 11, color: Colors.white54))),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
    ]))),
    actions: [
      if (widget.remove != null) TextButton(onPressed: _busy ? null : () async {
        final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('¿Eliminar tu nota?'), content: const Text('Dejará de aparecer en Chats y Comunidad.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Conservar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))]));
        if (yes != true || !mounted) return;
        setState(() => _busy = true);
        try {await widget.remove!(); if (mounted) Navigator.pop(context);}
        catch (_) {if (mounted) setState(() {_busy = false; _error = 'No se confirmó la eliminación.';});}
      }, child: const Text('Quitar nota')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Guardando…' : 'Compartir')),
    ],
  ));
}
