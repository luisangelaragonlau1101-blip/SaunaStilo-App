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

  static const Color colorFondo = Color(0xFF050505);
  static const Color colorTextoPrimario = Color(0xFFF8F8F6);
  static const Color colorAcento = Color(0xFFD6A85F);
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
      backgroundColor: colorFondo,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.65),
            radius: 1.15,
            colors: [Color(0xFF29231B), Color(0xFF0A0908), colorFondo],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/logo_saunastilo.png', height: 142),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: colorAcento.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colorAcento.withOpacity(0.42)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: colorAcento, size: 16),
                              const SizedBox(width: 7),
                              Text(
                                'NUEVA VERSIÓN',
                                style: GoogleFonts.inter(
                                  color: colorAcento,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Todo Sauna Stilo,\nen un solo lugar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: colorTextoPrimario,
                          fontSize: 29,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Equipo · Proyectos · Comunidad · Inteligencia artificial',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11100F).withOpacity(0.94),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white.withOpacity(0.11)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: colorTextoPrimario),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: _inputDecoration(
                                label: 'Correo electrónico',
                                icon: Icons.alternate_email_rounded,
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Ingresa tu correo electrónico'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(color: colorTextoPrimario),
                              obscureText: _obscureText,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!_isLoading) _login();
                              },
                              decoration: _inputDecoration(
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => setState(() => _obscureText = !_obscureText),
                                ),
                              ),
                              validator: (value) => value == null || value.isEmpty
                                  ? 'Ingresa tu contraseña'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorTextoPrimario,
                                foregroundColor: colorFondo,
                                disabledBackgroundColor: Colors.white24,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: colorFondo,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Entrar a mi espacio',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        const Icon(Icons.arrow_forward_rounded, size: 20),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'SAUNA STILO · OPERACIONES 2.0',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
      prefixIcon: Icon(icon, color: colorAcento, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.045),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: border,
      border: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: colorAcento, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: colorError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: colorError, width: 1.4),
      ),
    );
  }
}
