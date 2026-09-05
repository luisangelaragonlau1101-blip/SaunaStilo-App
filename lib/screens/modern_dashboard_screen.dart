import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'futuristic_dashboard_screen.dart';

class ModernDashboardScreen extends StatelessWidget {
  final UserModel usuario;

  const ModernDashboardScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return FuturisticDashboardScreen(usuario: usuario);
  }
}
