import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/offline_workspace.dart';
import 'widgets/screen_security_guard.dart';
import 'providers/seguimiento_cotizaciones_provider.dart';
import 'screens/wrapper.dart';
import 'services/cajita_herramientas_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const SaunaStiloBootstrap());
}

class SaunaStiloBootstrap extends StatefulWidget {
  const SaunaStiloBootstrap({super.key});
  @override
  State<SaunaStiloBootstrap> createState() => _SaunaStiloBootstrapState();
}

class _SaunaStiloBootstrapState extends State<SaunaStiloBootstrap> {
  late Future<void> _startup;
  @override
  void initState() { super.initState(); _startup = _initializeApp(); }
  Future<void> _initializeApp() async {
    await initializeDateFormatting('es').timeout(const Duration(seconds: 10));
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 25));
    }
    await OfflineWorkspace.configure();
  }
  void _retry() => setState(() => _startup = _initializeApp());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(future: _startup, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) return const MyApp();
      return MaterialApp(
        title: 'Sauna Stilo', debugShowCheckedModeBanner: false, theme: _futureTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF050506),
          body: SafeArea(child: Center(child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo_saunastilo.png', height: 150, fit: BoxFit.contain),
              const SizedBox(height: 28),
              if (!snapshot.hasError)
                const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Color(0xFFB7FF2A), strokeWidth: 2.4))
              else ...[
                const Text('No pudimos conectar.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('REINTENTAR')),
              ],
            ]),
          ))),
        ),
      );
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SeguimientoCotizacionesProvider()),
        ChangeNotifierProvider(create: (_) => CajitaInventarioProvider()),
      ],
      child: MaterialApp(
        title: 'Sauna Stilo', debugShowCheckedModeBanner: false,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('es', 'MX'), Locale('es', 'ES')],
        theme: _futureTheme(), builder: (context, child) => ScreenSecurityGuard(child: child ?? const SizedBox.shrink()), home: Wrapper(),
      ),
    );
  }
}

ThemeData _futureTheme() {
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
