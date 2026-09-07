import '../services/external_transfer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/team_contact_service.dart';
import 'mensajes_equipo_screen.dart';
import 'trabajador_cajita_herramientas_screen.dart';

class PrestamosEquipoScreen extends StatefulWidget {
  final UserModel usuario;
  const PrestamosEquipoScreen({super.key, required this.usuario});
  @override
  State<PrestamosEquipoScreen> createState() => _PrestamosEquipoScreenState();
}
class _PrestamosEquipoScreenState extends State<PrestamosEquipoScreen> {
  String _query = '';
  String? _busy;
  final Map<String, String> _requestIds = {};
  final Set<String> _sent = {};
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Préstamos del equipo')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrabajadorCajitaHerramientasScreen(trabajadorId: widget.usuario.id))), icon: const Icon(Icons.handyman_outlined), label: const Text('Mi cajita · prestar, recibir o devolver')),
        const SizedBox(height: 12), const Text('Solicita una herramienta a quien la tiene. El préstamo solo cambia de responsable cuando se confirma la entrega en Mi cajita.', style: TextStyle(color: Colors.white60, height: 1.45)),
        const SizedBox(height: 12), TextField(contextMenuBuilder: privacyTextMenu, onChanged: (v) => setState(() => _query = v.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Buscar herramienta o compañero…', prefixIcon: Icon(Icons.search))),
      ])),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('cajitas_inventario').where('estado', isEqualTo: 'asignado').snapshots(), builder: (c, snapshot) {
        if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No se pudieron consultar las herramientas. Revisa Internet y permisos.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tools = snapshot.data!.docs.where((d) {
          final p = d.data(); final owner = p['trabajador_actual_id']?.toString() ?? '';
          return owner.isNotEmpty && owner != widget.usuario.id && (p['propietario_original_id']?.toString() ?? '').isEmpty && '${p['nombre'] ?? p['nombre_herramienta'] ?? ''} ${p['trabajador_actual_nombre'] ?? ''}'.toLowerCase().contains(_query);
        }).toList();
        if (tools.isEmpty) return const Center(child: Text('No hay herramientas disponibles en esta vista.'));
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 18), itemCount: tools.length, itemBuilder: (c, i) {
          final d = tools[i]; final p = d.data(); final name = (p['nombre'] ?? p['nombre_herramienta'] ?? 'Herramienta').toString();
          return Card(color: const Color(0xFF111012), child: ListTile(leading: const Icon(Icons.construction_outlined, color: Color(0xFFB7FF2A)), title: Text(name), subtitle: Text('La tiene ${p['trabajador_actual_nombre'] ?? 'un compañero'}'), trailing: TextButton(onPressed: _busy != null || _sent.contains(d.id) ? null : () => _request(d), child: Text(_busy == d.id ? 'Enviando…' : _sent.contains(d.id) ? 'Solicitada' : 'Solicitar'))));
        });
      })),
    ]),
  );
  Future<void> _request(QueryDocumentSnapshot<Map<String, dynamic>> tool) async {
    final p = tool.data(); final name = (p['nombre'] ?? p['nombre_herramienta'] ?? 'Herramienta').toString();
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Solicitar préstamo'), content: Text('Se enviará a ${p['trabajador_actual_nombre'] ?? 'tu compañero'} un mensaje privado solicitando $name. El aviso del teléfono depende de sus permisos y del servicio de notificaciones.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enviar solicitud'))]));
    if (yes != true || !mounted || _busy != null) return;
    setState(() => _busy = tool.id);
    try {
      final current = await tool.reference.get(const GetOptions(source: Source.server));
      if (current.data()?['estado'] != 'asignado' || current.data()?['trabajador_actual_id'] != p['trabajador_actual_id']) throw StateError('La herramienta cambió de responsable.');
      final recipient = await FirebaseFirestore.instance.collection('usuarios').doc(p['trabajador_actual_id'].toString()).get(const GetOptions(source: Source.server));
      if (!recipient.exists || recipient.data()?['activo'] == false) throw StateError('El compañero no está disponible.');
      final person = UserModel.fromFirestore(recipient); final service = TeamContactService();
      final id = _requestIds.putIfAbsent(tool.id, () => service.conversation(widget.usuario, person).collection('mensajes').doc().id);
      final notified = await service.saveMessage(user: widget.usuario, contact: person, messageId: id, onScreen: true, toolRequest: true, data: {'texto': 'Te solicito el préstamo de $name. ¿Puedes confirmarlo desde Mi cajita? La entrega debe aceptarse en la aplicación.', 'tipo': 'texto'});
      if (!mounted) return;
      setState(() => _sent.add(tool.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notified ? 'Solicitud guardada y aviso registrado. La recepción en el teléfono aún no está confirmada.' : 'Solicitud guardada en el chat. No se confirmó su aviso; no vuelvas a enviarla.')));
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConversacionPrivadaScreen(usuario: widget.usuario, contacto: person)));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se confirmó la solicitud. Revisa la herramienta y tu conexión antes de reintentar.'))); }
    finally { if (mounted) setState(() => _busy = null); }
  }
}
