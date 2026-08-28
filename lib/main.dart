import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; 
import 'firebase_options.dart'; 
import 'screens/wrapper.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'providers/seguimiento_cotizaciones_provider.dart'; 
import 'services/cajita_herramientas_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('es');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
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