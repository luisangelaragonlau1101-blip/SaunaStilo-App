import 'package:flutter/material.dart';

/// Captures normalized vector strokes; the server binds these strokes to the
/// authenticated person, saved quantities, timestamp and snapshot hash.
class InstallationSignaturePad extends StatefulWidget {
  final ValueChanged<List<List<List<double>>>> onChanged;
  const InstallationSignaturePad({super.key, required this.onChanged});
  @override State<InstallationSignaturePad> createState() => _InstallationSignaturePadState();
}
class _InstallationSignaturePadState extends State<InstallationSignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = const Size(300, 180);
  void _notify() => widget.onChanged(_strokes.map((s) => s.map((p) => [
    (p.dx / _size.width).clamp(0.0, 1.0), (p.dy / _size.height).clamp(0.0, 1.0),
  ]).toList()).toList());
  @override Widget build(BuildContext context) => Column(children: [
    Semantics(label: 'Área para dibujar tu firma con el dedo', child: ClipRRect(
      borderRadius: BorderRadius.circular(22), child: ColoredBox(color: Colors.white,
        child: SizedBox(height: 180, width: double.infinity, child: LayoutBuilder(builder: (_, constraints) {
          _size = Size(constraints.maxWidth, 180);
          return GestureDetector(behavior: HitTestBehavior.opaque,
            onPanStart: (d) { setState(() => _strokes.add([d.localPosition])); _notify(); },
            onPanUpdate: (d) { if (_strokes.fold<int>(0, (n, s) => n + s.length) >= 3900) return; setState(() => _strokes.last.add(d.localPosition)); _notify(); },
            child: CustomPaint(painter: _SignaturePainter(_strokes)),
          );
        })),
      ),
    )),
    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () { setState(_strokes.clear); _notify(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Borrar firma'))),
  ]);
}
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);
  @override void paint(Canvas canvas, Size size) {
    final pen = Paint()..color = const Color(0xff17171c)..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) { path.lineTo(point.dx, point.dy); }
      canvas.drawPath(path, pen);
    }
  }
  @override bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
