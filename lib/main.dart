import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; 
import 'firebase_options.dart'; 
import 'screens/wrapper.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'providers/seguimiento_cotizaciones_provider.dart'; 
import 'services/cajita_herramientas_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaunaStiloBootstrap());
}

/// Dibuja una pantalla inmediatamente y realiza la inicialización en segundo
/// plano. Así, una conexión lenta o un error de Firebase nunca deja la web en
/// blanco sin explicación.
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
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFD6A85F),
                          size: 72,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'SAUNA STILO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!snapshot.hasError) ...[
                          const CircularProgressIndicator(
                            color: Color(0xFFD6A85F),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Preparando tu espacio de trabajo…',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ] else ...[
                          const Text(
                            'No pudimos conectar con Sauna Stilo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Revisa tu conexión a internet y vuelve a intentarlo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD6A85F),
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ],
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
        title: 'SaunaStilo',
        debugShowCheckedModeBanner: false,
        
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'), 
        ],

        theme: ThemeData(
          brightness: Brightness.dark, 
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFDFDFD), 
            secondary: Color(0xFFC0C0C0), 
            surface: Colors.black, 
          ),
          scaffoldBackgroundColor: Colors.black, 
          useMaterial3: true,
        ),
        home: Wrapper(), 
      ),
    );
  }
}
