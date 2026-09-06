import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../services/media_upload_service.dart';
import '../services/team_contact_service.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/audio_note_button.dart';
import '../widgets/team_notes_strip.dart';
import '../widgets/message_dictation_button.dart';
import 'proyecto_chat_screen.dart';

class MensajesEquipoScreen extends StatefulWidget {
  final UserModel usuario;
  const MensajesEquipoScreen({super.key, required this.usuario});
  @override
  State<MensajesEquipoScreen> createState() => _MensajesEquipoScreenState();
}
class _MensajesEquipoScreenState extends State<MensajesEquipoScreen> {
  String _query = '';
  void _open(UserModel contact, {bool call = false}) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConversacionPrivadaScreen(usuario: widget.usuario, contacto: contact, iniciarLlamada: call)));
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 2, child: Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Chats y llamadas'), bottom: const TabBar(labelColor: Color(0xFFB7FF2A), indicatorColor: Color(0xFFB7FF2A), tabs: [Tab(text: 'Personas'), Tab(text: 'Por proyecto')])),
    body: TabBarView(children: [
      Column(children: [
        TeamNotesStrip(user: widget.usuario),
        Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: const InputDecoration(hintText: 'Buscar a una persona…', prefixIcon: Icon(Icons.search_rounded)), onChanged: (v) => setState(() => _query = v.trim().toLowerCase()))),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('usuarios').snapshots(), builder: (context, snapshot) {
          if (snapshot.hasError) return const _ChatStatus('No se pudo leer el equipo. Revisa conexión y permisos.');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final people = snapshot.data!.docs.where((d) => d.id != widget.usuario.id && d.data()['activo'] != false).map(UserModel.fromFirestore).where((p) => p.nombre.toLowerCase().contains(_query)).toList()..sort((a,b) => a.nombre.compareTo(b.nombre));
          if (people.isEmpty) return const _ChatStatus('No hay integrantes que coincidan con la búsqueda.');
          return ListView.builder(itemCount: people.length, itemBuilder: (context, i) {
            final person = people[i];
            return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), leading: _Avatar(person), title: Text(person.nombre, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(person.rol, style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: () => _open(person), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Escribir a ${person.nombre}', icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFB7FF2A)), onPressed: () => _open(person)),
              IconButton(tooltip: 'Llamar a ${person.nombre}', icon: const Icon(Icons.call_outlined, color: Color(0xFFD7859D)), onPressed: () => _open(person, call: true)),
            ]));
          });
        })),
      ]),
      _groups(),
    ]),
  ));
  Widget _groups() {
    final db = FirebaseFirestore.instance;
    final query = widget.usuario.rol == AppRoles.admin ? db.collection('proyectos') : db.collection('proyectos').where('encargados', arrayContains: widget.usuario.id);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(), builder: (context, snapshot) {
      if (snapshot.hasError) return const _ChatStatus('No se pudieron cargar los grupos de tus proyectos.');
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final projects = snapshot.data!.docs.map(Proyecto.fromFirestore).toList();
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Padding(padding: EdgeInsets.only(bottom: 18), child: Text('Un grupo por proyecto, con los integrantes asignados. Abre el grupo para compartir fotografías, audios, comentarios y avances.', style: TextStyle(color: Colors.white70, height: 1.4))),
        if (projects.isEmpty) const _ChatStatus('Administración debe asignarte a un proyecto para que aparezca su grupo.'),
        for (final p in projects) Card(color: const Color(0xFF111012), child: ListTile(leading: const Icon(Icons.workspaces_outline, color: Color(0xFFB7FF2A)), title: Text(p.titulo), subtitle: const Text('Abrir grupo y evidencias'), trailing: const Icon(Icons.arrow_forward_rounded), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProyectoChatScreen(proyecto: p))))),
      ]);
    });
  }
}

class ConversacionPrivadaScreen extends StatefulWidget {
  final UserModel usuario;
  final UserModel contacto;
  final bool iniciarLlamada;
  const ConversacionPrivadaScreen({super.key, required this.usuario, required this.contacto, this.iniciarLlamada = false});
  @override
  State<ConversacionPrivadaScreen> createState() => _ConversacionPrivadaScreenState();
}
class _ConversacionPrivadaScreenState extends State<ConversacionPrivadaScreen> {
  static const _accent = Color(0xFFB7FF2A);
  final _text = TextEditingController();
  final _service = TeamContactService();
  final _media = MediaUploadService();
  final _files = <_PendingFile>[];
  bool _busy = false;
  bool _onScreen = true;
  late Future<void> _ready;
  String? _draftId;
  Uint8List? _audioDraft;
  String? _audioDraftId;
  MediaUploadResult? _audioUpload;
  DocumentReference<Map<String, dynamic>> get _conversation => _service.conversation(widget.usuario, widget.contacto);
  CollectionReference<Map<String, dynamic>> get _messages => _conversation.collection('mensajes');
  @override
  void initState() {
    super.initState();
    _ready = _service.ensureConversation(widget.usuario, widget.contacto);
    if (widget.iniciarLlamada) _ready.then((_) { if (mounted) _call(true); }).catchError((Object _) {});
  }
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  void _notice(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(titleSpacing: 0, title: Row(children: [_Avatar(widget.contacto, radius: 18), const SizedBox(width: 8), Expanded(child: Text(widget.contacto.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))]), actions: [
      IconButton(tooltip: 'Llamar', onPressed: _busy ? null : () => _call(true), icon: const Icon(Icons.call_outlined, color: _accent)),
      IconButton(tooltip: 'Videollamada', onPressed: _busy ? null : () => _call(false), icon: const Icon(Icons.videocam_outlined, color: Color(0xFFD7859D))),
    ]),
    body: FutureBuilder<void>(future: _ready, builder: (context, ready) {
      if (ready.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const _ChatStatus('No se pudo abrir esta conversación. Revisa tu sesión y conexión.'), FilledButton(onPressed: () => setState(() => _ready = _service.ensureConversation(widget.usuario, widget.contacto)), child: const Text('Reintentar'))]));
      if (ready.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      return Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _messages.orderBy('fecha', descending: true).snapshots(), builder: (context, snapshot) {
          if (snapshot.hasError) return const _ChatStatus('No se pudieron leer los mensajes. No se ha borrado tu conversación.');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const _ChatStatus('Escribe, dicta o envía una nota de voz para comenzar.');
          return ListView.builder(reverse: true, padding: const EdgeInsets.all(14), itemCount: docs.length, itemBuilder: (context, i) => _bubble(docs[i].data()));
        })),
        if (_busy) const LinearProgressIndicator(),
        if (_files.isNotEmpty) SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [for (final f in _files) Padding(padding: const EdgeInsets.only(right: 6), child: InputChip(label: Text(f.name, overflow: TextOverflow.ellipsis), onDeleted: _busy ? null : () => setState(() => _files.remove(f))))])),
        SafeArea(top: false, child: Container(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), color: const Color(0xFF111012), child: Column(children: [
          Row(children: [Switch(value: _onScreen, activeTrackColor: const Color(0xFF668F19), onChanged: _busy ? null : (v) => setState(() => _onScreen = v)), const Expanded(child: Text('Mostrar aviso personal en su pantalla', style: TextStyle(color: Colors.white70, fontSize: 11)))]),
          TextField(controller: _text, enabled: !_busy, minLines: 1, maxLines: 4, maxLength: 4000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Escribe o dicta un mensaje…', counterText: '')),
          Row(children: [
            IconButton(tooltip: 'Fotografías', onPressed: _busy ? null : _pickImages, icon: const Icon(Icons.add_photo_alternate_outlined)),
            IconButton(tooltip: 'Archivos o videos', onPressed: _busy ? null : _pickFiles, icon: const Icon(Icons.attach_file_rounded)),
            IconButton(tooltip: 'Emojis y stickers', onPressed: _busy ? null : _emoji, icon: const Icon(Icons.emoji_emotions_outlined)),
            MessageDictationButton(controller: _text, enabled: !_busy),
            IgnorePointer(ignoring: _busy, child: AudioNoteButton(color: _accent, onAudioReady: _audio)),
            const Spacer(),
            IconButton.filled(tooltip: 'Enviar mensaje', onPressed: _busy ? null : _send, icon: const Icon(Icons.arrow_upward_rounded)),
          ]),
        ]))),
      ]);
    }),
  );
  Widget _bubble(Map<String, dynamic> d) {
    final own = d['autorId'] == widget.usuario.id;
    final text = d['texto']?.toString() ?? '';
    final audio = d['audioUrl']?.toString() ?? '';
    final meeting = d['reunionUrl']?.toString() ?? '';
    final raw = d['archivos'];
    final files = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    return Align(alignment: own ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 430), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: own ? const Color(0xFF29101B) : const Color(0xFF151315), borderRadius: BorderRadius.circular(20), border: Border.all(color: own ? const Color(0xFF632A3E) : Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (text.isNotEmpty) SelectableText(text, style: TextStyle(fontSize: d['sticker'] == true ? 34 : 14, height: 1.4)),
      for (final f in files) _attachment(f),
      if (audio.isNotEmpty) AudioMessagePlayer(url: audio, durationSeconds: (d['duracionSegundos'] as num?)?.toInt() ?? 0, color: _accent),
      if (meeting.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: FilledButton.icon(icon: const Icon(Icons.call_outlined), label: const Text('Entrar a la llamada'), onPressed: () => _openUrl(meeting, meeting: true))),
      const SizedBox(height: 6),
      Text(d['fecha'] is Timestamp ? DateFormat('dd/MM HH:mm').format((d['fecha'] as Timestamp).toDate()) : 'Guardando…', style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ])));
  }
  Widget _attachment(Map f) {
    final url = f['url']?.toString() ?? '';
    if (f['tipo'] == 'imagen') return Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(onTap: () => _openUrl(url), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(url, width: 280, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('No se pudo cargar la foto. Toca para abrirla.')))));
    return Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(onPressed: () => _openUrl(url), icon: Icon(f['tipo'] == 'video' ? Icons.play_circle_outline : Icons.description_outlined), label: Text(f['nombre']?.toString() ?? 'Abrir archivo', overflow: TextOverflow.ellipsis)));
  }
  Future<void> _pickImages() async {
    try { final images = await ImagePicker().pickMultiImage(); for (final image in images) { final bytes = await image.readAsBytes(); _addFile(image.name, bytes); } if (mounted) setState(() {}); } catch (_) { _notice('No se pudieron leer las fotografías seleccionadas.'); }
  }
  Future<void> _pickFiles() async {
    try { final files = await FilePicker.pickFiles(allowMultiple: true); for (final file in files) { if (!mounted) return; if (await file.length() > 16 * 1024 * 1024) { _notice('Cada archivo debe pesar menos de 16 MB.'); continue; } final bytes = await file.readAsBytes(); if (!mounted) return; _addFile(file.name, bytes); } if (mounted) setState(() {}); } catch (_) { _notice('No se pudieron leer los archivos seleccionados.'); }
  }
  void _addFile(String name, Uint8List bytes) {
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > MediaUploadService.maxBytesPerFile) { _notice('$name está vacío o supera 50 MB.'); return; }
    _files.add(_PendingFile(name, bytes));
  }
  Future<void> _send() async {
    if (_busy || (_text.text.trim().isEmpty && _files.isEmpty)) return;
    setState(() => _busy = true);
    _draftId ??= _messages.doc().id;
    try {
      final uploaded = <Map<String, dynamic>>[];
      for (final file in _files) {
        final result = await _media.upload(bytes: file.bytes, fileName: file.name, contentType: file.mime, folder: 'mensajes/${_conversation.id}/$_draftId');
        uploaded.add({'url': result.url, 'ruta': result.path, 'nombre': file.name, 'tipo': file.type});
      }
      final notified = await _service.saveMessage(user: widget.usuario, contact: widget.contacto, messageId: _draftId!, onScreen: _onScreen, data: {'texto': _text.text.trim(), 'archivos': uploaded, 'tipo': uploaded.isEmpty ? 'texto' : 'multimedia'});
      if (!mounted) return;
      _text.clear(); _files.clear(); _draftId = null;
      if (!notified) _notice('Mensaje guardado. No se confirmó el envío de su aviso; no hace falta reenviar el mensaje.');
    } catch (_) { _notice('No se confirmó el envío. El texto y los adjuntos siguen aquí para reintentar.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _audio(Uint8List wav, int seconds) async {
    if (!mounted || _busy) throw StateError('Espera a que termine el envío actual.');
    if (!identical(_audioDraft, wav)) {_audioDraft = wav; _audioDraftId = _messages.doc().id; _audioUpload = null;}
    setState(() => _busy = true);
    try {
      final id = _audioDraftId!;
      final upload = _audioUpload ??= await _media.upload(bytes: wav, fileName: 'audio_$id.wav', contentType: 'audio/wav', folder: 'mensajes/${_conversation.id}/$id');
      final notified = await _service.saveMessage(user: widget.usuario, contact: widget.contacto, messageId: id, onScreen: _onScreen, data: {'texto': '', 'audioUrl': upload.url, 'audioRuta': upload.path, 'duracionSegundos': seconds, 'archivos': <Map<String, dynamic>>[], 'tipo': 'audio'});
      _audioDraft = null; _audioDraftId = null; _audioUpload = null;
      if (!notified) _notice('Audio guardado; el aviso no fue confirmado.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _call(bool audioOnly) async {
    if (_busy || !mounted) return;
    final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('¿Llamar a ${widget.contacto.nombre}?'), content: const Text('Se enviará una invitación privada. Después puedes entrar a la sala desde el chat. El timbrado depende del permiso y volumen de su teléfono.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Llamar'))]));
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = _messages.doc().id;
      final url = 'https://meet.jit.si/SaunaStilo-$id';
      final notified = await _service.saveMessage(user: widget.usuario, contact: widget.contacto, messageId: id, call: true, data: {'texto': audioOnly ? 'Invitación a llamada de voz.' : 'Invitación a videollamada.', 'reunionUrl': audioOnly ? '$url#config.startWithVideoMuted=true' : url, 'tipo': audioOnly ? 'llamada' : 'videollamada', 'archivos': <Map<String, dynamic>>[]});
      _notice(notified ? 'Invitación registrada. Entra a la llamada desde el chat. La entrega al teléfono aún debe confirmarse.' : 'Invitación guardada, pero no se confirmó su aviso.');
    } catch (_) { _notice('No se pudo registrar la invitación de llamada.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _emoji() async {
    final value = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 12, runSpacing: 12, children: ['👍','❤️','🔥','👏','✅','💪','🛠️','♨️','📸','🚐','🎉','😂'].map((e) => InkWell(onTap: () => Navigator.pop(c,e), child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: const TextStyle(fontSize: 32))))).toList()))));
    if (value != null && mounted) { _text.text += value; _text.selection = TextSelection.collapsed(offset: _text.text.length); }
  }
  Future<void> _openUrl(String value, {bool meeting = false}) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || (meeting && uri.host != 'meet.jit.si')) { _notice('Enlace no permitido.'); return; }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) _notice('No se pudo abrir el enlace. Revisa los permisos del navegador.');
  }
}
class _PendingFile {
  final String name;
  final Uint8List bytes;
  _PendingFile(this.name, this.bytes);
  String get type => RegExp(r'\.(jpg|jpeg|png|webp|heic)$', caseSensitive: false).hasMatch(name) ? 'imagen' : RegExp(r'\.(mp4|mov|webm|m4v)$', caseSensitive: false).hasMatch(name) ? 'video' : 'archivo';
  String get mime {
    final ext = name.split('.').last.toLowerCase();
    return {'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp','heic':'image/heic','mp4':'video/mp4','mov':'video/quicktime','webm':'video/webm','m4v':'video/mp4','pdf':'application/pdf','wav':'audio/wav','mp3':'audio/mpeg'}[ext] ?? 'application/octet-stream';
  }
}
class _Avatar extends StatelessWidget {
  final UserModel person;
  final double radius;
  const _Avatar(this.person, {this.radius = 23});
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: radius, backgroundColor: const Color(0xFF321320), backgroundImage: person.fotoUrl?.isNotEmpty == true ? NetworkImage(person.fotoUrl!) : null, child: person.fotoUrl?.isNotEmpty == true ? null : Text(person.nombre.isEmpty ? 'S' : person.nombre[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)));
}
class _ChatStatus extends StatelessWidget {
  final String text;
  const _ChatStatus(this.text);
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4))));
}
