import '../widgets/inline_photo.dart';
import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_detalle_cajita_screen.dart'; // Crearemos esta después

class AdminCajitasScreen extends StatelessWidget {
  const AdminCajitasScreen({super.key});

  Color get colorFondo => StiloColors.surface;
  Color get colorTarjeta => StiloColors.surface;
  Color get colorTextoPrimario => StiloColors.text;
  Color get colorNaranja => Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: IconThemeData(color: colorTextoPrimario),
        title: Text(
          'CAJITAS DE HERRAMIENTAS',
          style: GoogleFonts.inter(
            color: colorTextoPrimario,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              // Texto actualizado para ser más inclusivo
              "Selecciona un maestro o trabajador para gestionar su inventario.",
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 14),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  // ¡AQUÍ ESTÁ LA MAGIA! Filtramos por ambos roles
                  .where('rol', whereIn: ['trabajador', 'maestro'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorNaranja));
                }

                final personal = snapshot.data?.docs ?? [];

                if (personal.isEmpty) {
                  return Center(
                    child: Text(
                      // Texto actualizado
                      'No hay personal registrado.',
                      style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)),
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: personal.length,
                  itemBuilder: (context, index) {
                    final data = personal[index].data() as Map<String, dynamic>;
                    final usuarioId = personal[index].id;
                    final nombre = data['nombre'] ?? 'Sin nombre';
                    final fotoUrl = data['fotoUrl'];


                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminDetalleCajitaScreen(
                              // Pasamos el ID del usuario seleccionado (sea maestro o trabajador)
                              usuarioId: usuarioId,
                              nombreUsuario: nombre,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(color: StiloColors.background.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorNaranja.withOpacity(0.2),
                                border: Border.all(color: colorNaranja.withOpacity(0.5), width: 2),
                                image: fotoUrl != null && fotoUrl.toString().isNotEmpty
                                    ? DecorationImage(image: stiloImageProvider(fotoUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: fotoUrl == null || fotoUrl.toString().isEmpty
                                  ? Text(
                                      nombre[0].toUpperCase(),
                                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: colorNaranja),
                                    )
                                  : null,
                            ),
                            SizedBox(height: 16),
                            Text(
                              nombre,
                              style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: StiloColors.text.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Ver Cajita",
                                style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
