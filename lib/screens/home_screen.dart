import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'SAUNA STILO',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFFDFDFD),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFDFDFD)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BIENVENIDO,',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFC0C0C0),
                fontSize: 16,
              ),
            ),
            Text(
              user?.email?.toUpperCase() ?? 'USUARIO',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFFDFDFD),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            
            // AQUÍ ES DONDE ENTRARÁN LOS ROLES MÁS ADELANTE
            const Center(
              child: Text(
                'CARGANDO PANEL DE CONTROL...',
                style: TextStyle(color: Colors.white54, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}