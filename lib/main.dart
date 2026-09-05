import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/seguimiento_cotizaciones_provider.dart';
import 'screens/wrapper.dart';
import 'services/cajita_herramientas_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
  void initState() {
    super.initState();
    _startup = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await initializeDateFormatting('es').timeout(const Duration(seconds: 10));
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 25));
    }
  }

  void _retry() {
    setState(() => _startup = _initializeApp());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyApp();
        }

        return MaterialApp(
          title: 'Sauna Stilo',
          debugShowCheckedModeBanner: false,
          theme: _futureTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFF05070A),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF172530), Color(0xFF0B0F14)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0x3386E9FF)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF86E9FF), Color(0xFFB8A7FF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.black,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'SAUNA STILO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'INTELLIGENCE SYSTEM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF86E9FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 27),
                          if (!snapshot.hasError) ...[
                            const CircularProgressIndicator(
                              color: Color(0xFF86E9FF),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Preparando tu centro de operación…',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ] else ...[
                            const Text(
                              'No pudimos conectar con Sauna Stilo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Revisa tu conexión a Internet y vuelve a intentarlo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('REINTENTAR'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
        title: 'Sauna Stilo',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'MX'),
          Locale('es', 'ES'),
        ],
        theme: _futureTheme(),
        home: Wrapper(),
      ),
    );
  }
}

ThemeData _futureTheme() {
  const primary = Color(0xFF86E9FF);
  const secondary = Color(0xFFA8F6D5);
  const tertiary = Color(0xFFB8A7FF);
  const background = Color(0xFF05070A);
  const surface = Color(0xFF10151B);
  const border = Color(0xFF29323D);

  final scheme = const ColorScheme.dark(
    primary: primary,
    onPrimary: Color(0xFF031115),
    secondary: secondary,
    onSecondary: Color(0xFF06130E),
    tertiary: tertiary,
    onTertiary: Color(0xFF0B0718),
    surface: surface,
    onSurface: Colors.white,
    error: Color(0xFFFF8E9E),
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: Colors.white12,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF0D1116),
      indicatorColor: Color(0x2386E9FF),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF11161C),
      hintStyle: const TextStyle(color: Colors.white38),
      labelStyle: const TextStyle(color: Colors.white60),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: const Color(0xFF031115),
        minimumSize: const Size(44, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(44, 48),
        side: const BorderSide(color: Color(0x5586E9FF)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF171D24),
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
