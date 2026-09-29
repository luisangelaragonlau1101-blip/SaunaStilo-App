import 'package:flutter/material.dart';
import '../presentation/appearance.dart';
import 'company_assistant_panel.dart';

/// Above the root Navigator, so pushed pages keep the same assistant access.
class GlobalAssistantLayer extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final String? userId;
  const GlobalAssistantLayer({super.key, required this.child, required this.navigatorKey, this.userId});
  @override State<GlobalAssistantLayer> createState() => _GlobalAssistantLayerState();
}
class _GlobalAssistantLayerState extends State<GlobalAssistantLayer> {
  bool _open = false, _left = false;
  double _bottom = 108;
  Future<void> _show() async {
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (_open || context == null || widget.userId == null) return;
    setState(() => _open = true);
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
        builder: (sheet) => SizedBox(height: MediaQuery.sizeOf(sheet).height * .88,
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
              const Expanded(child: Text('Online Smart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Cerrar asistente', onPressed: () => Navigator.pop(sheet), icon: const Icon(Icons.close)),
            ])),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom), child: CompanyAssistantPanel())),
          ])));
    } finally { if (mounted) setState(() => _open = false); }
  }
  @override Widget build(BuildContext context) => Stack(children: [
    widget.child,
    if (widget.userId != null && !_open && MediaQuery.viewInsetsOf(context).bottom == 0)
      Positioned(left: _left ? 16 : null, right: _left ? null : 16,
        bottom: _bottom.clamp(90.0, (MediaQuery.sizeOf(context).height - 180).clamp(90.0, double.infinity)).toDouble(),
        child: GestureDetector(onPanUpdate: (d) => setState(() {
          _bottom = (_bottom - d.delta.dy).clamp(90.0, (MediaQuery.sizeOf(context).height - 180).clamp(90.0, double.infinity)).toDouble();
          if (d.globalPosition.dx < MediaQuery.sizeOf(context).width / 2) _left = true; else _left = false;
        }), child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFF8E1538).withValues(alpha: .5), blurRadius: 22, spreadRadius: 2)]),
          child: FloatingActionButton.small(heroTag: 'global-online-smart', tooltip: 'Online Smart · texto y audio · arrastra para mover',
            backgroundColor: StiloColors.surface, foregroundColor: StiloColors.accent,
            onPressed: _show, child: const Icon(Icons.auto_awesome_rounded)))),
      ),
  ]);
}
