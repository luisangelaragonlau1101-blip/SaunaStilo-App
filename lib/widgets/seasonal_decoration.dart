import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../presentation/appearance.dart';

enum StiloSeason { winter, newYear, anniversary }

StiloSeason? stiloSeason(DateTime date, {DateTime? anniversary}) {
  if (anniversary != null &&
      date.month == anniversary.month &&
      date.day == anniversary.day) {
    return StiloSeason.anniversary;
  }
  if (date.month == 12) return StiloSeason.winter;
  if (date.month == 1 && date.day <= 7) return StiloSeason.newYear;
  return null;
}

/// Entirely local decoration: no assets, network, startup awaits or hit targets.
/// The work view is outside the animated painter and is not rebuilt every frame.
class SeasonalDecoration extends StatefulWidget {
  final Widget child;
  final AppearanceController? controller;
  final DateTime? date;
  final DateTime? anniversary;
  const SeasonalDecoration({
    super.key,
    required this.child,
    this.controller,
    this.date,
    this.anniversary,
  });
  @override
  State<SeasonalDecoration> createState() => _SeasonalDecorationState();
}

class _SeasonalDecorationState extends State<SeasonalDecoration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  AppearanceController get _settings =>
      widget.controller ?? AppearanceController.instance;
  bool _foreground = true;
  bool _visible = false;
  StiloSeason? _season;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    );
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SeasonalDecoration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? AppearanceController.instance).removeListener(
        _changed,
      );
      _settings.addListener(_changed);
    }
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _changed() {
    if (mounted) {
      _sync();
      setState(() {});
    }
  }

  void _sync() {
    final media = MediaQuery.maybeOf(context);
    _season = stiloSeason(
      widget.date ?? DateTime.now(),
      anniversary: widget.anniversary ?? _settings.anniversaryDate,
    );
    _visible =
        _settings.seasonalEffects &&
        _season != null &&
        _foreground &&
        media?.disableAnimations != true &&
        media?.accessibleNavigation != true &&
        TickerMode.of(context);
    if (_visible && !_motion.isAnimating) _motion.repeat();
    if (!_visible && _motion.isAnimating) _motion.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _changed();
  }

  @override
  void dispose() {
    _settings.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                key: const ValueKey('seasonal-decoration'),
                child: CustomPaint(
                  painter: _SeasonPainter(
                    _motion,
                    _season!,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonPainter extends CustomPainter {
  final Animation<double> motion;
  final StiloSeason season;
  final Color accent;
  _SeasonPainter(this.motion, this.season, this.accent)
    : super(repaint: motion);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Eighteen tiny paths keep this light even on entry-level phones.
    for (var i = 0; i < 18; i++) {
      final seed = ((i * 67 + 17) % 101) / 101;
      final y = ((motion.value + seed) % 1) * (size.height + 20) - 10;
      final x =
          ((i * 43 + 11) % 97) / 97 * size.width +
          math.sin(motion.value * math.pi * 2 + i) * 8;
      final radius = 1.4 + (i % 3) * .6;
      final paint = Paint()
        ..color = (season == StiloSeason.winter ? Colors.white : accent)
            .withValues(alpha: .18 + (i % 3) * .045);
      if (season == StiloSeason.winter) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(motion.value * math.pi + i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 2,
              height: radius * 4,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonPainter oldDelegate) =>
      oldDelegate.season != season ||
      oldDelegate.accent != accent ||
      oldDelegate.motion != motion;
}
