import '../presentation/appearance.dart';
import 'package:flutter/material.dart';

List<Color> get stiloAccents => <Color>[
  StiloColors.accent, Color(0xFFFF729C), StiloColors.accent,
  Color(0xFFFFB876), Color(0xFF7CE3BD),
];

/// Shared, rounded brand treatment. No remote artwork or replacement company logo.
class StiloOrbitIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool active;
  const StiloOrbitIcon({super.key, required this.icon, required this.color, this.size = 48, this.active = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180),
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color.withOpacity(active ? .26 : .13), StiloColors.surface]),
      border: Border.all(color: color.withOpacity(active ? .85 : .35), width: active ? 1.4 : 1),
      boxShadow: [BoxShadow(color: color.withOpacity(active ? .18 : .06), blurRadius: active ? 18 : 9)],
    ),
    child: Stack(alignment: Alignment.center, children: [
      Positioned(top: size * .08, left: size * .2, right: size * .2,
        child: Container(height: size * .19, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [StiloColors.text.withOpacity(.13), Colors.transparent])))),
      Icon(icon, color: color, size: size * .47),
    ]),
  );
}

class StiloDock extends StatelessWidget {
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;
  const StiloDock({super.key, required this.selectedIndex, required this.destinations, required this.onSelected});
  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: Container(
    margin: EdgeInsets.fromLTRB(10, 5, 10, 8),
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 9),
    decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(38),
      border: Border.all(color: StiloColors.surface),
      boxShadow: [BoxShadow(color: Color(0x248E1538), blurRadius: 22, offset: Offset(0, -3))]),
    child: Row(children: List.generate(destinations.length, (i) {
      final item = destinations[i]; final selected = i == selectedIndex;
      final icon = (selected ? item.selectedIcon ?? item.icon : item.icon) as Icon;
      return Expanded(child: Semantics(button: true, selected: selected, label: item.label,
        child: Tooltip(message: item.label, child: Material(color: Colors.transparent,
          child: InkWell(key: ValueKey('stilo-tab-$i'), borderRadius: BorderRadius.circular(30),
            onTap: () => onSelected(i), child: Padding(padding: EdgeInsets.symmetric(vertical: 2),
              child: ExcludeSemantics(child: Column(mainAxisSize: MainAxisSize.min, children: [
                StiloOrbitIcon(icon: icon.icon!, color: stiloAccents[i % stiloAccents.length], size: 43, active: selected),
                SizedBox(height: 6),
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? StiloColors.text : StiloColors.text.withValues(alpha: .60))),
              ]))))))));
    })),
  ));
}

class AdminOperationsCard extends StatelessWidget {
  final VoidCallback onAttendance;
  final VoidCallback onTeam;
  const AdminOperationsCard({super.key, required this.onAttendance, required this.onTeam});
  @override
  Widget build(BuildContext context) => Container(padding: EdgeInsets.all(18),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(colors: [StiloColors.surface, StiloColors.surface]),
      border: Border.all(color: StiloColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [StiloOrbitIcon(icon: Icons.admin_panel_settings_rounded, color: Color(0xFFFF729C)),
        SizedBox(width: 12), Expanded(child: Text('Panel de Administración', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))]),
      SizedBox(height: 12),
      Text('Revisa los registros y las solicitudes del equipo desde Administración.', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.45)),
      SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: onAttendance, icon: Icon(Icons.fact_check_outlined), label: Text('Ver asistencias')),
        OutlinedButton.icon(onPressed: onTeam, icon: Icon(Icons.groups_rounded), label: Text('Ver equipo')),
      ]),
    ]),
  );
}
