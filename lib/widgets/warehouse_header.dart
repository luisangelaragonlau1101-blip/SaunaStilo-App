import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'stilo_orbit.dart';

/// Consistent warehouse identity without replacing the company logo or data.
class WarehouseHeader extends StatelessWidget {
  final String title, subtitle;
  final bool compact;
  const WarehouseHeader({super.key, required this.title, required this.subtitle, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: EdgeInsets.all(compact ? 16 : 22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [StiloColors.surface, StiloColors.surface, StiloColors.background]),
      border: Border.all(color: Color(0xFF8E1538).withOpacity(.65)),
      boxShadow: [BoxShadow(color: Color(0x228E1538), blurRadius: 20, offset: Offset(0, 5))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [StiloOrbitIcon(icon: Icons.warehouse_outlined, color: stiloAccents[0], size: compact ? 38 : 48), SizedBox(width: 12),
        Expanded(child: Text('SAUNA STILO · ALMACÉN', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)))]),
      SizedBox(height: 12), Text(title, style: TextStyle(color: StiloColors.text, fontSize: compact ? 20 : 26, fontWeight: FontWeight.w800, height: 1.15)),
      SizedBox(height: 7), Text(subtitle, style: TextStyle(color: StiloColors.text.withValues(alpha: .60), fontSize: 13, height: 1.4)),
    ]),
  );
}
