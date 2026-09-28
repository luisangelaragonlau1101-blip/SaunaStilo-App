import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StiloPalette {
  final String id, label;
  final Color accent, background;
  final bool light;
  const StiloPalette(this.id, this.label, this.accent, this.background, {this.light = false});
}
const stiloPalettes = [
  StiloPalette('stilo', 'Stilo', Color(0xFFB7FF2A), Color(0xFF08090B)),
  StiloPalette('rosa', 'Rosa', Color(0xFFFF81B5), Color(0xFF21101B)),
  StiloPalette('rojo', 'Rojo', Color(0xFFFF8291), Color(0xFF250E14)),
  StiloPalette('oscuro', 'Oscuro', Color(0xFFB8C5D9), Color(0xFF0C1016)),
  StiloPalette('blanco', 'Blanco', Color(0xFF6128A0), Color(0xFFFAF9FC), light: true),
  StiloPalette('gris', 'Gris', Color(0xFF334155), Color(0xFFECEFF3), light: true),
  StiloPalette('morado', 'Morado', Color(0xFFD0A6FF), Color(0xFF1B102C)),
];

/// Only visual preferences. Never stores attendance, roles or work records.
class AppearanceController extends ChangeNotifier {
  static final instance = AppearanceController();
  String? _uid;
  String _palette = 'stilo';
  bool celebrations = true, compact = false;
  int _generation = 0;
  Future<void>? _writes;
  String? get userId => _uid;
  StiloPalette get palette => stiloPalettes.firstWhere((p) => p.id == _palette, orElse: () => stiloPalettes.first);
  Future<void> bindUser(String? uid) async {
    final generation = ++_generation;
    _uid = uid; _palette = 'stilo'; celebrations = true; compact = false;
    notifyListeners();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      _palette = prefs.getString('stilo.appearance.$uid.palette') ?? 'stilo';
      celebrations = prefs.getBool('stilo.appearance.$uid.celebrations') ?? true;
      compact = prefs.getBool('stilo.appearance.$uid.compact') ?? false;
      notifyListeners();
    } catch (_) { /* Defaults remain usable if device storage is unavailable. */ }
  }
  Future<void> save({String? paletteId, bool? festive, bool? simple}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Inicia sesión para guardar tu estilo.');
    if (paletteId != null && !stiloPalettes.any((p) => p.id == paletteId)) throw ArgumentError('Color desconocido.');
    final generation = _generation;
    final nextPalette = paletteId ?? _palette, nextCelebrations = festive ?? celebrations, nextCompact = simple ?? compact;
    final operation = (_writes ?? Future<void>.value()).catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('stilo.appearance.$uid.palette', nextPalette);
      final savedFestive = await prefs.setBool('stilo.appearance.$uid.celebrations', nextCelebrations);
      final savedCompact = await prefs.setBool('stilo.appearance.$uid.compact', nextCompact);
      if (!saved || !savedFestive || !savedCompact) throw StateError('No se pudo guardar el estilo en este dispositivo.');
      if (generation != _generation) return;
      _palette = nextPalette; celebrations = nextCelebrations; compact = nextCompact; notifyListeners();
    });
    _writes = operation;
    await operation;
  }
}

final _themeCache = <String, ThemeData>{};
ThemeData stiloTheme(StiloPalette palette) => _themeCache.putIfAbsent(palette.id, () => _makeStiloTheme(palette));
ThemeData _makeStiloTheme(StiloPalette palette) {
  final scheme = ColorScheme.fromSeed(seedColor: palette.accent, brightness: palette.light ? Brightness.light : Brightness.dark).copyWith(primary: palette.accent);
  final onPrimary = ThemeData.estimateBrightnessForColor(palette.accent) == Brightness.dark ? Colors.white : const Color(0xFF151019);
  final colors = scheme.copyWith(onPrimary: onPrimary);
  return ThemeData(useMaterial3: true, colorScheme: colors, scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    appBarTheme: AppBarTheme(backgroundColor: palette.background, foregroundColor: colors.onSurface, surfaceTintColor: Colors.transparent, elevation: 0),
    cardTheme: CardThemeData(color: colors.surfaceContainerLow, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: colors.outlineVariant))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: colors.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: colors.surfaceContainerLow, indicatorColor: colors.primaryContainer),
  );
}

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override State<AppearanceScreen> createState() => _AppearanceState();
}
class _AppearanceState extends State<AppearanceScreen> {
  bool busy = false;
  String? error;
  Future<void> change({String? palette, bool? festive, bool? simple}) async {
    setState(() {busy = true; error = null;});
    try { await AppearanceController.instance.save(paletteId: palette, festive: festive, simple: simple); }
    catch (_) { if (mounted) setState(() => error = 'No se guardó el cambio. Intenta otra vez.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: AppearanceController.instance, builder: (context, _) {
    final settings = AppearanceController.instance;
    return Scaffold(appBar: AppBar(title: const Text('Mi estilo')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Hazlo tuyo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), const Text('Elige el color de tus paneles. Se guarda para tu cuenta en este dispositivo.'),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [for (final p in stiloPalettes) ChoiceChip(key: ValueKey('palette-${p.id}'), selected: settings.palette.id == p.id,
        avatar: CircleAvatar(backgroundColor: p.accent, child: settings.palette.id == p.id ? Icon(Icons.check, size: 15, color: ThemeData.estimateBrightnessForColor(p.accent) == Brightness.dark ? Colors.white : Colors.black) : null),
        label: Text(p.label), onSelected: busy ? null : (_) => change(palette: p.id))]),
      const SizedBox(height: 24), Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SAUNA STILO', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 10), const Text('Tu espacio, a tu manera.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14), const Text('Así se verán tus paneles y accesos principales.'),
      ]))),
      SwitchListTile(title: const Text('Inicio sencillo'), subtitle: const Text('Oculta el resumen adicional; conserva tus accesos y tu jornada.'), value: settings.compact, onChanged: busy ? null : (v) => change(simple: v)),
      SwitchListTile(title: const Text('Celebraciones'), subtitle: const Text('Detalles de temporada y una felicitación en tu cumpleaños.'), value: settings.celebrations, onChanged: busy ? null : (v) => change(festive: v)),
      if (busy) const LinearProgressIndicator(), if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]));
  });
}

/// Shared semantic colors for screens migrated from the original dark palette.
class StiloColors {
  static ColorScheme get scheme => stiloTheme(AppearanceController.instance.palette).colorScheme;
  static Color get text => scheme.onSurface;
  static Color get muted => scheme.onSurfaceVariant;
  static Color get background => AppearanceController.instance.palette.background;
  static Color get surface => scheme.surfaceContainerLow;
  static Color get border => scheme.outlineVariant;
  static Color get accent => scheme.primary;
}
