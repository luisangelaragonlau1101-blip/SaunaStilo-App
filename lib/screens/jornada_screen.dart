import '../presentation/appearance.dart';
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
      appBar: AppBar(title: Text('Mi jornada'), actions: [IconButton(tooltip: 'Historial de asistencia', icon: Icon(Icons.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayrollRecordsScreen(user: usuario))))]),
      body: ListView(padding: EdgeInsets.all(20), children: [
        JornadaCompacta(usuario: usuario, showDetails: false),
        SizedBox(height: 16),
        Text('Las horas se muestran únicamente cuando el servidor confirma su guardado.', style: TextStyle(color: StiloColors.text.withValues(alpha: .54), height: 1.5)),
      ]),
    );
  }
}
