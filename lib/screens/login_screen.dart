import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  // Paleta de colores oficial basada en el logo
  static const Color colorFondo = Colors.black;
  static const Color colorTextoPrimario = Color(0xFFFDFDFD); // Blanco marfil del logo
  static const Color colorAcento = Color(0xFFC0C0C0); // Gris plateado sutil
  static const Color colorError = Colors.redAccent;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // FUNCIÓN LOGIN OPTIMIZADA
  Future<void> _login() async {
    // 1. Valida que los campos no estén vacíos
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 2. Intenta iniciar sesión en los servidores de Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡CONEXIÓN EXITOSA A SAUNA STILO!'),
            backgroundColor: Colors.green,
          ),
        );
        // NOTA: No hace falta usar Navigator aquí. 
        // El StreamBuilder del Wrapper detectará la sesión y cambiará la pantalla solo.
      }
    } on FirebaseAuthException catch (e) {
      // 3. Manejo de errores específicos
      String message = 'Ocurrió un error. Inténtalo de nuevo.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo no es válido.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: colorError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo, // Fondo negro azabache
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // INTEGRACIÓN DEL LOGO OFICIAL
                Image.asset(
                  'assets/logo_saunastilo.png',
                  height: 170, 
                ),
                const SizedBox(height: 30),
                
                Text(
                  'CONTROL DE PRODUCCIÓN Y PERSONAL',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel( // Tipografía Serif clásica para el título
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorTextoPrimario,
                    letterSpacing: 2.0,
                  ),
                ),
      
                const SizedBox(height: 20),

                // CAMPO DE CORREO 
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: colorTextoPrimario), // Texto blanco al escribir
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'CORREO ELECTRÓNICO',
                    labelStyle: const TextStyle(color: colorAcento),
                    prefixIcon: const Icon(Icons.email_outlined, color: colorAcento),
                    enabledBorder: OutlineInputBorder( // Borde plateado sutil
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: colorAcento, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder( // Borde blanco brillante al seleccionar
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: colorTextoPrimario, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu correo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // CAMPO DE CONTRASEÑA
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: colorTextoPrimario),
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'CONTRASEÑA',
                    labelStyle: const TextStyle(color: colorAcento),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: colorAcento),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: colorAcento,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: colorAcento, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: colorTextoPrimario, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // BOTÓN DE INGRESAR ESTILO SÓLIDO Y ELEGANTE
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTextoPrimario, // Botón blanco marfil
                    foregroundColor: colorFondo, // Texto negro azabache
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: colorFondo,
                            strokeWidth: 2,
                      ),
                    )
                      : Text(
                          'INICIAR SESIÓN',
                          style: GoogleFonts.cinzel( // Tipografía Serif para el botón
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
