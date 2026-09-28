import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/jornada_compacta.dart';
import 'payroll_records_screen.dart';

class JornadaScreen extends StatelessWidget {
  final UserModel usuario;
  const JornadaScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Mi jornada'), actions: [IconButton(tooltip: 'Historial de asistencia', icon: const Icon(Icons.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayrollRecordsScreen(user: usuario))))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        JornadaCompacta(usuario: usuario, showDetails: false),
        const SizedBox(height: 16),
        const Text('Las horas se muestran únicamente cuando el servidor confirma su guardado.', style: TextStyle(color: Colors.white54, height: 1.5)),
      ]),
    );
  }
}
