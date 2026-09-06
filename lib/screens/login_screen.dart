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
  static const colorFondo = Color(0xFF000000);
  static const colorTextoPrimario = Color(0xFFF7F7F5);
  static const colorAcento = Color(0xFFB7FF2A);
  static const colorError = Colors.redAccent;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Wrapper observes Firebase Auth and opens the existing role dashboard.
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Correo o contraseña incorrectos.',
        'invalid-email' => 'El formato del correo no es válido.',
        'user-disabled' => 'Esta cuenta está desactivada. Consulta a Administración.',
        'too-many-requests' => 'Demasiados intentos. Espera un momento antes de volver a entrar.',
        'network-request-failed' => 'No pudimos conectar. Revisa tu conexión a Internet.',
        _ => 'No pudimos iniciar sesión. Inténtalo de nuevo.',
      };
      _showError(message);
    } catch (_) {
      _showError('No pudimos conectar con Sauna Stilo. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: colorError,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.65), radius: 1.15,
            colors: [Color(0xFF230C15), Color(0xFF090708), colorFondo],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset('assets/logo_saunastilo.png', height: 142),
                        const SizedBox(height: 20),
                        Center(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35101E),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF8E1538)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.hub_outlined, color: colorAcento, size: 16),
                            const SizedBox(width: 8),
                            Text('INTERFAZ 3.0', style: GoogleFonts.inter(
                              color: colorTextoPrimario, fontSize: 11,
                              fontWeight: FontWeight.w800, letterSpacing: 1.2,
                            )),
                          ]),
                        )),
                        const SizedBox(height: 20),
                        Text('Tu equipo. Tu trabajo.\nUn nuevo espacio.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: colorTextoPrimario,
                            fontSize: 29, height: 1.12, fontWeight: FontWeight.w800,
                            letterSpacing: -.7)),
                        const SizedBox(height: 12),
                        Text('Proyectos · Comunidad · Guía · Sauna IA',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5)),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111012),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0xFF42212D)),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: !_isLoading,
                              style: const TextStyle(color: colorTextoPrimario),
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: _inputDecoration(label: 'Correo electrónico', icon: Icons.alternate_email_rounded),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu correo electrónico' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              style: const TextStyle(color: colorTextoPrimario),
                              obscureText: _obscureText,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _login(),
                              decoration: _inputDecoration(
                                label: 'Contraseña', icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _obscureText ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                  icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70),
                                  onPressed: () => setState(() => _obscureText = !_obscureText),
                                ),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Ingresa tu contraseña' : null,
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorAcento, foregroundColor: colorFondo,
                                disabledBackgroundColor: Colors.white24,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                              ),
                              child: _isLoading
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: colorFondo, strokeWidth: 2.4))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Flexible(child: Text('Entrar a mi espacio', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800))),
                                    const SizedBox(width: 9),
                                    const Icon(Icons.arrow_forward_rounded, size: 20),
                                  ]),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 22),
                        Text('SAUNA STILO · INTERFAZ 3.0', textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 10,
                            fontWeight: FontWeight.w700, letterSpacing: 1.45)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, Widget? suffix}) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(color: Colors.white.withOpacity(.16)));
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: colorAcento, size: 21), suffixIcon: suffix,
      filled: true, fillColor: Colors.white.withOpacity(.035),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: border, border: border,
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: colorAcento, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: colorError)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: colorError, width: 1.4)),
    );
  }
}
