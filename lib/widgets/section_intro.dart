import 'package:flutter/material.dart';
import '../presentation/appearance.dart';

class SectionIntro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const SectionIntro({super.key, required this.title, required this.subtitle,
    required this.icon});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: StiloColors.surface, borderRadius: BorderRadius.circular(24),
      border: Border.all(color: StiloColors.border),
      boxShadow: [BoxShadow(color: const Color(0xFF8E1538).withValues(alpha: .16),
        blurRadius: 24, offset: const Offset(0, 8))]),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DecoratedBox(decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: StiloColors.accent))),
      const SizedBox(width: 14), Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6), Text(subtitle,
          style: TextStyle(color: StiloColors.muted, height: 1.4)),
      ])),
    ]),
  );
}
