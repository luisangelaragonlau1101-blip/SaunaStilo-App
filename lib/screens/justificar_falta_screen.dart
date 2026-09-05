import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/asistencia_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/team_profile_helpers.dart';

// No automatic attendance or approval is created by opening this form.
class JustificarFaltaScreen extends StatefulWidget {
  final UserModel usuario;
  const JustificarFaltaScreen({super.key, required this.usuario});
  @override
  State<JustificarFaltaScreen> createState() => _JustificarFaltaScreenState();
}
class _JustificarFaltaScreenState extends State<JustificarFaltaScreen> {
  final _reason = TextEditingController();
  DateTime _date = mexicoToday();
  bool _busy = false;
  String? _error;
  XFile? _evidence;
  Uint8List? _preview;
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  Query<Map<String, dynamic>> get _own => FirebaseFirestore.instance.collection('asistencias').where('trabajadorId', isEqualTo: widget.usuario.id);
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Justificar una falta')), body: ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Explica lo ocurrido', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8), const Text('Tu solicitud será revisada por Administración. Enviarla no equivale a aprobarla ni modifica tus horas de entrada o salida.', style: TextStyle(color: Colors.white60, height: 1.45)),
    const SizedBox(height: 16), OutlinedButton.icon(onPressed: _busy ? null : () async { final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: mexicoToday()); if (date != null && mounted) setState(() => _date = date); }, icon: const Icon(Icons.event_outlined), label: Text(DateFormat('dd/MM/yyyy').format(_date))),
    const SizedBox(height: 10), TextField(controller: _reason, enabled: !_busy, minLines: 4, maxLines: 8, maxLength: 2000, decoration: const InputDecoration(labelText: 'Motivo', hintText: 'Describe el motivo de tu ausencia…', alignLabelWithHint: true)),
    OutlinedButton.icon(onPressed: _busy ? null : _pickEvidence, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_evidence == null ? 'Agregar evidencia (opcional)' : 'Cambiar evidencia')),
    if (_preview != null) Column(children: [Image.memory(_preview!, height: 120), TextButton(onPressed: _busy ? null : () => setState(() { _evidence = null; _preview = null; }), child: const Text('Quitar evidencia'))]),
    const Text('La evidencia se guarda en un espacio restringido a tu cuenta y Administración. No la envíes en chats generales.', style: TextStyle(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 14), FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send_outlined), label: Text(_busy ? 'Enviando…' : 'Enviar a revisión')),
    if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
    const SizedBox(height: 24), const Text('MIS SOLICITUDES', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _own.snapshots(), builder: (c, snapshot) {
      if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(14), child: Text('No se pudo cargar el historial. Revisa tu conexión y los permisos.'));
      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(14), child: LinearProgressIndicator());
      final docs = snapshot.data!.docs.where((d) => (d.data()['motivoFalta']?.toString() ?? '').isNotEmpty).toList()..sort((a, b) => b.id.compareTo(a.id));
      if (docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('Todavía no tienes solicitudes.', style: TextStyle(color: Colors.white54)));
      return Column(children: docs.take(50).map((d) {final p = d.data(); return Card(color: const Color(0xFF111012), child: ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text(p['fecha'] is Timestamp ? DateFormat('dd/MM/yyyy').format((p['fecha'] as Timestamp).toDate()) : 'Solicitud'), subtitle: Text('${p['motivoFalta']}\n${(p['estatusJustificacion'] ?? 'pendiente_revision').toString().replaceAll('_', ' ')}')));}).toList());
    }),
  ]));
  Future<void> _pickEvidence() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError('La foto supera 5 MB.');
      if (mounted) setState(() { _evidence = file; _preview = bytes; });
    } catch (_) { if (mounted) setState(() => _error = 'No se pudo leer la foto. Usa JPG, PNG o WebP de menos de 5 MB.'); }
  }
  Future<void> _send() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty || reason.length > 2000) {setState(() => _error = 'Escribe un motivo de hasta 2000 caracteres.'); return;}
    if (FirebaseAuth.instance.currentUser?.uid != widget.usuario.id || _date.isAfter(mexicoToday())) {setState(() => _error = 'Revisa tu sesión y la fecha.'); return;}
    setState(() {_busy = true; _error = null;});
    try {
      await AsistenciaService().enviarJustificacion(trabajadorId: widget.usuario.id, fechaAsistencia: _date, motivo: reason, evidenciaUrl: _evidence?.path);
      if (!mounted) return;
      _reason.clear();
      setState(() { _evidence = null; _preview = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Justificación guardada, pendiente de revisión por Administración.')));
    } catch (_) {if (mounted) setState(() => _error = 'No se confirmó el guardado. Revisa conexión, permisos o si la fecha ya fue aprobada. Tu motivo sigue aquí.');}
    finally {if (mounted) setState(() => _busy = false);}
  }
}
