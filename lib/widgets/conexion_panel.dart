import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/ai_assistant_service.dart';
import '../services/push_notifications_service.dart';

class ConexionPanel extends StatefulWidget {
  final UserModel usuario;
  const ConexionPanel({super.key, required this.usuario});
  @override
  State<ConexionPanel> createState() => _ConexionPanelState();
}
class _ConexionPanelState extends State<ConexionPanel> {
  final _push = PushNotificationsService();
  bool _pushBusy = false;
  bool _aiBusy = false;
  String _status = 'Configura este dispositivo para no perder avisos. La IA se verifica con una respuesta real.';
  Future<void> _activate() async {
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    final result = await _push.activateFor(widget.usuario);
    if (mounted) setState(() { _status = result.message; _pushBusy = false; });
  }
  Future<void> _testAi() async {
    if (_aiBusy) return;
    setState(() { _aiBusy = true; _status = 'Comprobando el servicio de IA…'; });
    try {
      await AiAssistantService().responder(pregunta: 'Responde solamente: Sauna IA conectada.', historial: const []);
      if (mounted) setState(() => _status = 'Sauna IA respondió correctamente. Abre el asistente para trabajar con los datos autorizados de tu cuenta.');
    } catch (error) {
      if (mounted) setState(() => _status = error is AiAssistantException ? error.message : 'No fue posible verificar la IA.');
    } finally { if (mounted) setState(() => _aiBusy = false); }
  }
  @override
  void dispose() { _push.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF152332), Color(0xFF10141B)]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF304356)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.hub_outlined, color: Color(0xFFD6E8FF)), SizedBox(width: 10),
        Expanded(child: Text('Tu centro de conexión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)))]),
      const SizedBox(height: 12),
      Semantics(liveRegion: true, child: Text(_status, style: const TextStyle(color: Color(0xFFCBDAE9), height: 1.5))),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: _pushBusy ? null : _activate,
          icon: Icon(_pushBusy ? Icons.hourglass_top_rounded : Icons.notifications_active_outlined),
          label: Text(_pushBusy ? 'Registrando…' : 'Activar avisos'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: const Color(0xFFD6E8FF), foregroundColor: const Color(0xFF111923))),
        OutlinedButton.icon(onPressed: _aiBusy ? null : _testAi,
          icon: Icon(_aiBusy ? Icons.hourglass_top_rounded : Icons.auto_awesome_outlined),
          label: Text(_aiBusy ? 'Verificando…' : 'Probar IA'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: const Color(0xFFD6E8FF))),
      ]),
      const SizedBox(height: 10),
      const Text('El sonido y los avisos con pantalla bloqueada dependen de los permisos y del modo Enfoque del teléfono.', style: TextStyle(fontSize: 12, color: Color(0xFFAABCCE), height: 1.4)),
    ]),
  );
}
