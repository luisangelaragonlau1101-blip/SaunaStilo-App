import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'presentation/appearance.dart';
import 'screens/local_party_screen.dart';

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
                Builder(builder: (nav) => TextButton.icon(onPressed: () => Navigator.of(nav).push(MaterialPageRoute<void>(builder: (_) => const LocalPartyScreen())), icon: const Icon(Icons.sports_esports_rounded), label: const Text('Juegos sin conexión · hasta 4'))),
              ],
            ]),
          ))),
        ),
      );
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override State<MyApp> createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _auth;
  @override void initState() {
    super.initState();
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) => AppearanceController.instance.bindUser(user?.uid));
  }
  @override void dispose() { _auth?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SeguimientoCotizacionesProvider()),
        ChangeNotifierProvider(create: (_) => CajitaInventarioProvider()),
      ],
      child: AnimatedBuilder(animation: AppearanceController.instance, builder: (context, _) => MaterialApp(
        title: 'Sauna Stilo', debugShowCheckedModeBanner: false,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('es', 'MX'), Locale('es', 'ES')],
        theme: stiloTheme(AppearanceController.instance.palette), builder: (context, child) => ScreenSecurityGuard(child: child ?? const SizedBox.shrink()), home: Wrapper(),
      )),
    );
  }
}

ThemeData _futureTheme() => stiloTheme(stiloPalettes.first);
