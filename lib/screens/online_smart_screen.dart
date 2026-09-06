import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../widgets/official_voice_reply.dart';
import '../services/local_guide.dart';
import 'online_smart_embed_stub.dart' if (dart.library.html) 'online_smart_embed_web.dart';

class OnlineSmartScreen extends StatefulWidget {
  final UserModel usuario;
  final bool modoGuia;
  const OnlineSmartScreen({super.key, required this.usuario, this.modoGuia = false});
  @override
  State<OnlineSmartScreen> createState() => _OnlineSmartScreenState();
}

class _OnlineSmartScreenState extends State<OnlineSmartScreen> {
  int _revision = 0;
  bool _voiceOpen = false;
  Future<void> _voiceRequested(String text) async {
    if (!mounted || _voiceOpen || ModalRoute.of(context)?.isCurrent != true) return;
    _voiceOpen = true;
    try {await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => OfficialVoiceReply(text: text));}
    finally {_voiceOpen = false;}
  }
  Uri get _uri => Uri.https('ollin-smart-vxs23c.v2.appdeploy.ai', '/', {
    'workspace': 'sauna-stilo',
    if (['http', 'https'].contains(Uri.base.scheme)) 'voiceParent': Uri.base.origin,
    'role': [AppRoles.admin, AppRoles.maestro, AppRoles.almacenista, AppRoles.trabajador].contains(widget.usuario.rol) ? widget.usuario.rol : AppRoles.trabajador,
    // Role is display guidance only, never authentication or access to company records.
    'view': widget.modoGuia ? 'guia' : 'asistente',
    'reload': '$_revision',
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Online Smart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Recargar asistente', icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() => _revision++)),
          IconButton(tooltip: 'Abrir guía fuera de la app', icon: const Icon(Icons.open_in_new_rounded), onPressed: () async {
            final opened = await launchUrl(_uri, mode: LaunchMode.externalApplication);
            if (!opened && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir. Revisa Internet e intenta nuevamente.')));
          }),
        ],
        bottom: const TabBar(indicatorColor: Color(0xFFB7FF2A), labelColor: Color(0xFFB7FF2A), unselectedLabelColor: Colors.white60,
          tabs: [Tab(text: 'Asistente'), Tab(text: 'Manual de uso')]),
      ),
      body: TabBarView(children: [
        onlineSmartEmbed(_uri, onVoiceRequest: _voiceRequested),
        ListView(padding: const EdgeInsets.all(18), children: [
          const Text('SAUNA STILO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          const Text('Online Smart, inteligencia artificial mexicana creada por ANGEL ZALDÍVAR. El manual siguiente funciona sin consultar IA.', style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 14),
          for (final question in const ['¿Cómo registro mi entrada?', '¿Dónde encuentro mis tareas?', '¿Cómo envío una evidencia?', '¿Dónde pido una herramienta?', '¿Cómo envío un mensaje?', '¿Cómo hago una llamada?', '¿Cómo grabo mi voz?'])
            ExpansionTile(title: Text(question), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
              Text(LocalGuide.answer(question, widget.usuario.rol) ?? 'En Inicio abre Proyectos, Chats o Todas las opciones. En Asistente puedes preguntar el paso que necesitas.', style: const TextStyle(color: Colors.white70, height: 1.5)),
            ]),
          const Padding(padding: EdgeInsets.all(16), child: Text('El asistente integrado recibe únicamente lo que escribes en su conversación. No consulta expedientes privados ni realiza registros por ti. Escuchar usa la voz del dispositivo. Voz de Ángel solicita una síntesis autorizada desde Sauna Stilo y requiere activación; no comparte credenciales con la guía.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5))),
        ]),
      ]),
    ),
  );
}
