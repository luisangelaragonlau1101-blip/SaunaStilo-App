import '../presentation/appearance.dart';
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
      final colors = Theme.of(context).colorScheme;
      return LayoutBuilder(builder: (context, constraints) {
        final minimumWidth = 140 * MediaQuery.textScalerOf(context).scale(1);
        final columns = (constraints.maxWidth / minimumWidth).floor().clamp(1, 5);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items)
          SizedBox(width: width, child: Material(color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: colors.outlineVariant)),
            clipBehavior: Clip.antiAlias, child: InkWell(key: ValueKey('home-${item.$1}'), onTap: () {
              if (item.$3 >= 0 && onTab != null) { onTab!(item.$3); return; }
              Navigator.push(context, MaterialPageRoute<void>(builder: actions.firstWhere((a) => a.id == item.$1).builder));
            }, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                child: Icon(actions.firstWhere((a) => a.id == item.$1).icon, size: 24, color: colors.primary)),
              const SizedBox(height: 18), Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4), Icon(Icons.north_east_rounded, size: 16, color: colors.onSurfaceVariant),
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
