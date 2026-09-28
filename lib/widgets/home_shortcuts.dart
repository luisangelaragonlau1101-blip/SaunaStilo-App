import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/app_action_catalog.dart';

class MainHomeShortcuts extends StatelessWidget {
  final UserModel user;
  final ValueChanged<int>? onTab;
  const MainHomeShortcuts({super.key, required this.user, this.onTab});
  @override
  Widget build(BuildContext context) {
    final actions = AppActionCatalog.forUser(user);
    const items = [('comunidad', 'Comunidad', 1), ('mensajes', 'Mensajes', 2), ('tareas', 'Tareas', 3), ('inventario', 'Almacén', -1), ('perfil', 'Perfil', 4)];
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final item in items)
      FilledButton.tonalIcon(
        key: ValueKey('home-${item.$1}'),
        onPressed: () {
          if (item.$3 >= 0 && onTab != null) { onTab!(item.$3); return; }
          final action = actions.firstWhere((a) => a.id == item.$1);
          Navigator.push(context, MaterialPageRoute<void>(builder: action.builder));
        },
        icon: Icon(actions.firstWhere((a) => a.id == item.$1).icon, size: 20),
        label: Text(item.$2),
      )]);
  }
}
