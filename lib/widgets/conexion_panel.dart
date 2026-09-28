import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/online_smart_screen.dart';
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
  String _status = 'Configura este dispositivo para no perder avisos. Abre Online Smart para consultar la guía.';
  Future<void> _activate() async {
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    final result = await _push.activateFor(widget.usuario);
    if (mounted) setState(() { _status = result.message; _pushBusy = false; });
  }
  void _testAi() { Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OnlineSmartScreen(usuario: widget.usuario))); }
  @override
  void dispose() { _push.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.fromLTRB(20, 4, 20, 20),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [StiloColors.surface, StiloColors.surface]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: StiloColors.surface),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.hub_outlined, color: StiloColors.accent), SizedBox(width: 10),
        Expanded(child: Text('Tu centro de conexión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: StiloColors.text)))]),
      SizedBox(height: 12),
      Semantics(liveRegion: true, child: Text(_status, style: TextStyle(color: Color(0xFFCCCCCC), height: 1.5))),
      SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: _pushBusy ? null : _activate,
          icon: Icon(_pushBusy ? Icons.hourglass_top_rounded : Icons.notifications_active_outlined),
          label: Text(_pushBusy ? 'Registrando…' : 'Activar avisos'),
          style: FilledButton.styleFrom(minimumSize: Size(0, 48), backgroundColor: StiloColors.accent, foregroundColor: StiloColors.background)),
        OutlinedButton.icon(onPressed: _aiBusy ? null : _testAi,
          icon: Icon(_aiBusy ? Icons.hourglass_top_rounded : Icons.auto_awesome_outlined),
          label: Text(_aiBusy ? 'Verificando…' : 'Abrir Online Smart'),
          style: OutlinedButton.styleFrom(minimumSize: Size(0, 48), foregroundColor: StiloColors.accent)),
      ]),
      SizedBox(height: 10),
      Text('El sonido y los avisos con pantalla bloqueada dependen de los permisos y del modo Enfoque del teléfono.', style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA), height: 1.4)),
    ]),
  );
}
