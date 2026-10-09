import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StiloPalette {
  final String id, label;
  final Color accent, background;
  final bool light;
  const StiloPalette(this.id, this.label, this.accent, this.background, {this.light = false});
}
const stiloPalettes = [
  StiloPalette('stilo', 'Stilo original', Color(0xFFB7FF2A), Color(0xFF050506)),
  StiloPalette('vino', 'Vino ejecutivo', Color(0xFFECA6B7), Color(0xFF10090D)),
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
  bool celebrations = true, compact = false, modern = true;
  int _generation = 0;
  Future<void>? _writes;
  String? get userId => _uid;
  StiloPalette get palette => stiloPalettes.firstWhere((p) => p.id == _palette, orElse: () => stiloPalettes.first);
  Future<void> bindUser(String? uid) async {
    final generation = ++_generation;
    _uid = uid; _palette = 'stilo'; celebrations = true; compact = false; modern = true;
    notifyListeners();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      _palette = prefs.getString('stilo.appearance.$uid.palette') ?? 'stilo';
      celebrations = prefs.getBool('stilo.appearance.$uid.celebrations') ?? true;
      compact = prefs.getBool('stilo.appearance.$uid.compact') ?? false;
      modern = prefs.getBool('stilo.appearance.$uid.modern') ?? true;
      notifyListeners();
    } catch (_) { /* Defaults remain usable if device storage is unavailable. */ }
  }
  Future<void> save({String? paletteId, bool? festive, bool? simple, bool? contemporary}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Inicia sesión para guardar tu estilo.');
    if (paletteId != null && !stiloPalettes.any((p) => p.id == paletteId)) throw ArgumentError('Color desconocido.');
    final generation = _generation;
    final nextModern = contemporary ?? modern;
    final nextPalette = paletteId ?? _palette, nextCelebrations = festive ?? celebrations, nextCompact = simple ?? compact;
    final operation = (_writes ?? Future<void>.value()).catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('stilo.appearance.$uid.palette', nextPalette);
      final savedFestive = await prefs.setBool('stilo.appearance.$uid.celebrations', nextCelebrations);
      final savedCompact = await prefs.setBool('stilo.appearance.$uid.compact', nextCompact);
      final savedModern = await prefs.setBool('stilo.appearance.$uid.modern', nextModern);
      if (!saved || !savedFestive || !savedCompact || !savedModern) throw StateError('No se pudo guardar el estilo en este dispositivo.');
      if (generation != _generation) return;
      _palette = nextPalette; celebrations = nextCelebrations; compact = nextCompact; modern = nextModern; notifyListeners();
    });
    _writes = operation;
    await operation;
  }
}

final _themeCache = <String, ThemeData>{};
ThemeData stiloTheme(StiloPalette palette) => _themeCache.putIfAbsent('${palette.id}.${AppearanceController.instance.modern}', () {
  final base = _makeStiloTheme(palette);
  if (!AppearanceController.instance.modern) return base;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter', bodyColor: base.colorScheme.onSurface, displayColor: base.colorScheme.onSurface),
    appBarTheme: base.appBarTheme.copyWith(centerTitle: false, titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.6, color: base.colorScheme.onSurface)),
    visualDensity: VisualDensity.standard,
    cardTheme: base.cardTheme.copyWith(elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34), side: BorderSide(color: base.colorScheme.outlineVariant.withValues(alpha: .55)))),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: base.colorScheme.outlineVariant.withValues(alpha: .55))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: base.colorScheme.primary, width: 1.4))),
    filledButtonTheme: FilledButtonThemeData(style: base.filledButtonTheme.style?.copyWith(shape: const WidgetStatePropertyAll(StadiumBorder()), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: base.outlinedButtonTheme.style?.copyWith(shape: const WidgetStatePropertyAll(StadiumBorder()), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 14)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(48, 48))),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(shape: const StadiumBorder(), elevation: 2, extendedPadding: const EdgeInsets.symmetric(horizontal: 24)),
    chipTheme: base.chipTheme.copyWith(side: BorderSide(color: base.colorScheme.outlineVariant.withValues(alpha: .5)), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
    listTileTheme: base.listTileTheme.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    dialogTheme: DialogThemeData(backgroundColor: base.colorScheme.surfaceContainerLow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: base.colorScheme.surfaceContainerLow, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(36)))),
    pageTransitionsTheme: PageTransitionsTheme(builders: {for (final platform in TargetPlatform.values) platform: const CupertinoPageTransitionsBuilder()}),
  );
});
ThemeData _makeStiloTheme(StiloPalette palette) {
  if (palette.id == 'stilo') return _originalStiloTheme();
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

// The original black, wine and neon theme stays the default.
ThemeData _originalStiloTheme() {
  const primary = Color(0xFFB7FF2A); // verde neón: acciones
  const secondary = Color(0xFF8E1538); // vino: identidad/premium
  const tertiary = Color(0xFFC13CFF); // violeta eléctrico: IA
  const background = Color(0xFF050506);
  const surface = Color(0xFF111012);
  const border = Color(0xFF30272D);
  final scheme = const ColorScheme.dark(
    primary: primary, onPrimary: Color(0xFF071000),
    secondary: secondary, onSecondary: Colors.white,
    tertiary: tertiary, onTertiary: Colors.white,
    surface: surface, onSurface: Colors.white,
    surfaceContainerLow: surface, surfaceContainerHighest: Color(0xFF151216),
    onSurfaceVariant: Colors.white60, outline: border, outlineVariant: border,
    error: Color(0xFFFF536A),
  );
  return ThemeData(
    brightness: Brightness.dark, useMaterial3: true, colorScheme: scheme,
    scaffoldBackgroundColor: background, canvasColor: background, dividerColor: Colors.white12,
    appBarTheme: const AppBarTheme(backgroundColor: background, foregroundColor: Colors.white, surfaceTintColor: Colors.transparent, elevation: 0),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0D0C0E), indicatorColor: Color(0x338E1538), elevation: 0),
    cardTheme: CardThemeData(color: surface, surfaceTintColor: Colors.transparent, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: border))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFF151216), hintStyle: const TextStyle(color: Colors.white38), labelStyle: const TextStyle(color: Colors.white60),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: primary, width: 1.2)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: primary, foregroundColor: const Color(0xFF071000), minimumSize: const Size(44, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w900), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: primary, minimumSize: const Size(44, 48), side: const BorderSide(color: Color(0x88B7FF2A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xFF1C171B), contentTextStyle: TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating),
  );
}

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override State<AppearanceScreen> createState() => _AppearanceState();
}
class _AppearanceState extends State<AppearanceScreen> {
  bool busy = false;
  String? error;
  Future<void> change({String? palette, bool? festive, bool? simple, bool? contemporary}) async {
    setState(() {busy = true; error = null;});
    try { await AppearanceController.instance.save(paletteId: palette, festive: festive, simple: simple, contemporary: contemporary); }
    catch (_) { if (mounted) setState(() => error = 'No se guardó el cambio. Intenta otra vez.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: AppearanceController.instance, builder: (context, _) {
    final settings = AppearanceController.instance;
    return Scaffold(appBar: AppBar(title: const Text('Mi estilo')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Hazlo tuyo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), const Text('Stilo original es el tema predeterminado de Sauna Stilo. Cambiarlo es opcional y se guarda para tu cuenta en este dispositivo.'),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [for (final p in stiloPalettes) ChoiceChip(key: ValueKey('palette-${p.id}'), selected: settings.palette.id == p.id,
        avatar: CircleAvatar(backgroundColor: p.accent, child: settings.palette.id == p.id ? Icon(Icons.check, size: 15, color: ThemeData.estimateBrightnessForColor(p.accent) == Brightness.dark ? Colors.white : Colors.black) : null),
        label: Text(p.label), onSelected: busy ? null : (_) => change(palette: p.id))]),
      const SizedBox(height: 24), Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SAUNA STILO', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 10), const Text('Tu espacio, a tu manera.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14), const Text('Así se verán tus paneles y accesos principales.'),
      ]))),
      SwitchListTile(title: const Text('Interfaz moderna'), subtitle: const Text('Navegación adaptable y nuevos accesos. Desactívala para volver a la interfaz original.'), value: settings.modern, onChanged: busy ? null : (v) => change(contemporary: v)),
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
