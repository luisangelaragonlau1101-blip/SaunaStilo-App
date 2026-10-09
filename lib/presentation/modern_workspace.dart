import 'package:flutter/material.dart';
import '../widgets/stilo_orbit.dart';

class ModernWorkspaceFrame extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;
  const ModernWorkspaceFrame({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        return Scaffold(
          body: Row(
            children: [
              if (desktop)
                SafeArea(
                  child: Container(
                    width: 224,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      border: Border(
                        right: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Image.asset(
                            'assets/logo_saunastilo.png',
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView(
                            children: [
                              for (var i = 0; i < destinations.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      key: ValueKey('modern-tab-$i'),
                                      selected: i == selectedIndex,
                                      selectedTileColor: colors.primary
                                          .withValues(alpha: .10),
                                      selectedColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      leading: StiloOrbitIcon(
                                        icon:
                                            ((i == selectedIndex
                                                        ? destinations[i]
                                                                  .selectedIcon ??
                                                              destinations[i]
                                                                  .icon
                                                        : destinations[i].icon)
                                                    as Icon)
                                                .icon!,
                                        color:
                                            stiloAccents[i %
                                                stiloAccents.length],
                                        size: 40,
                                        active: i == selectedIndex,
                                      ),
                                      title: Text(
                                        destinations[i].label,
                                        style: TextStyle(
                                          fontWeight: i == selectedIndex
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      onTap: () => onSelected(i),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'SAUNA STILO\nTu equipo, conectado.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : StiloDock(
                  selectedIndex: selectedIndex,
                  destinations: destinations,
                  onSelected: onSelected,
                ),
        );
      },
    );
  }
}

class WorkspaceSectionTitle extends StatelessWidget {
  final String title, subtitle;
  const WorkspaceSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class WorkspaceTabs extends StatelessWidget {
  final Map<int, String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  const WorkspaceTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            for (final item in items.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  selected: selected == item.key,
                  child: TextButton(
                    onPressed: () => onSelected(item.key),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      foregroundColor: selected == item.key
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      backgroundColor: selected == item.key
                          ? colors.primary
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontWeight: selected == item.key
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
