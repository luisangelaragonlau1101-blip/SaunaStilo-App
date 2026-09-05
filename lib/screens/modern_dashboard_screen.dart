import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'operations_shell.dart';

class ModernDashboardScreen extends StatelessWidget {
  final UserModel usuario;
  const ModernDashboardScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) => OperationsShell(key: ValueKey('${usuario.id}:${usuario.rol}'), usuario: usuario);
}
