import 'package:flutter/material.dart';
import 'stilo_orbit.dart';

/// A shared visual header: the content always comes from the existing screen.
class StiloSectionHero extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final IconData icon;
  final Color? accent;
  final bool compact;
  const StiloSectionHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accent ?? colors.secondary;
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              tint.withValues(alpha: .18),
              colors.surfaceContainerLow,
            ),
            colors.surfaceContainerLow,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: .08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StiloOrbitIcon(
                icon: icon,
                color: accent ?? colors.primary,
                size: compact ? 38 : 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.3,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 22 : 27,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Rounded, accessible menu rows with the original actions and coloured icons.
class StiloActionRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const StiloActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              StiloOrbitIcon(icon: icon, color: accent, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
