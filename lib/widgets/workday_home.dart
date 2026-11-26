import 'package:flutter/material.dart';

/// Presentation only: sections load independently and never await one another.
class WorkdayHome extends StatelessWidget {
  final bool administrator;
  final Widget header, journey, activities, installations, weekly, options;
  final Widget? enterprise, secondary;
  const WorkdayHome({
    super.key,
    this.administrator = false,
    required this.header,
    required this.journey,
    required this.activities,
    required this.installations,
    required this.weekly,
    required this.options,
    this.enterprise,
    this.secondary,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        header,
        const SizedBox(height: 18),
        if (administrator) ...[
          if (enterprise != null) enterprise!,
          activities,
          ExpansionTile(title: const Text('Mi jornada'), children: [journey]),
        ] else ...[
          journey,
          const SizedBox(height: 18),
          activities,
        ],
        const SizedBox(height: 16),
        installations,
        if (!administrator) ...[const SizedBox(height: 16), weekly],
        const SizedBox(height: 18),
        options,
        if (secondary != null) secondary!,
      ],
    ),
  );
}
