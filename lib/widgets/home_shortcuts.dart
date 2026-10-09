import '../presentation/appearance.dart';
import 'stilo_orbit.dart';
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
    if (AppearanceController.instance.modern) {
      return LayoutBuilder(builder: (context, constraints) {
        final minimumWidth = 90 * MediaQuery.textScalerOf(context).scale(1);
        final columns = (constraints.maxWidth / minimumWidth).floor().clamp(1, 5);
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(spacing: 8, runSpacing: 16, children: [for (var i = 0; i < items.length; i++)
          SizedBox(width: width, child: Material(color: Colors.transparent,
            child: InkWell(key: ValueKey('home-${items[i].$1}'), borderRadius: BorderRadius.circular(32), onTap: () {
              final item = items[i];
              if (item.$3 >= 0 && onTab != null) { onTab!(item.$3); return; }
              Navigator.push(context, MaterialPageRoute<void>(builder: actions.firstWhere((a) => a.id == item.$1).builder));
            }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: Column(children: [
              StiloOrbitIcon(icon: actions.firstWhere((a) => a.id == items[i].$1).icon, color: stiloAccents[i % stiloAccents.length], size: 62),
              const SizedBox(height: 10), Text(items[i].$2, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ])))))
        ]);
      });
    }
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
