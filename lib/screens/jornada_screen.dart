import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/jornada_compacta.dart';
import 'trabajador_asistencia_screen.dart';

class JornadaScreen extends StatelessWidget {
  final UserModel usuario;
  const JornadaScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) {
    if (usuario.rol == AppRoles.admin) return Scaffold(appBar: AppBar(title: const Text('Administración')), body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Consulta las jornadas del equipo desde Inicio → Asistencias.'))));
    return Scaffold(
      appBar: AppBar(title: const Text('Mi jornada'), actions: [IconButton(tooltip: 'Historial de asistencia', icon: const Icon(Icons.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrabajadorAsistenciaScreen(trabajador: usuario))))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        JornadaCompacta(usuario: usuario, showDetails: false),
        const SizedBox(height: 16),
        const Text('La entrada, el regreso de comida y la salida requieren estar en una zona autorizada. La hora se confirma en el servidor.', style: TextStyle(color: Colors.white54, height: 1.5)),
      ]),
    );
  }
}
