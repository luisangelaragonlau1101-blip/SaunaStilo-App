import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void mostrarModalHorario(BuildContext context, String trabajadorId, String nombreActual) {
  final TextEditingController horaEntradaController = TextEditingController();
  final TextEditingController horaSalidaController = TextEditingController(); // NUEVO CONTROLADOR
  final TextEditingController toleranciaController = TextEditingController();

  // Cargar el horario actual si ya existe
  FirebaseFirestore.instance.collection('usuarios').doc(trabajadorId).get().then((doc) {
    if (doc.exists) {
      horaEntradaController.text = doc.data()?['horaEntrada'] ?? '08:00';
      horaSalidaController.text = doc.data()?['horaSalida'] ?? '18:00'; // NUEVO: Leer hora de salida (default 18:00)
      toleranciaController.text = (doc.data()?['toleranciaMinutos'] ?? 15).toString();
    }
  });

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true, // Para que el teclado no lo tape
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Sube con el teclado
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Horario de $nombreActual",
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            
            // --- HORA DE ENTRADA ---
            Text("Hora de entrada (HH:MM formato 24h)", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: horaEntradaController,
              style: GoogleFonts.inter(color: Colors.white),
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black,
                hintText: "Ej. 08:00",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.login_rounded, color: Color(0xFF00B0FF)),
              ),
            ),
            const SizedBox(height: 16),

            // --- HORA DE SALIDA (NUEVO) ---
            Text("Hora de salida (HH:MM formato 24h)", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: horaSalidaController,
              style: GoogleFonts.inter(color: Colors.white),
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black,
                hintText: "Ej. 18:00",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),

            // --- TOLERANCIA ---
            Text("Tolerancia (en minutos)", style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: toleranciaController,
              style: GoogleFonts.inter(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black,
                hintText: "Ej. 15",
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.timer_rounded, color: Color(0xFFFF9800)),
              ),
            ),
            const SizedBox(height: 24),

            // --- BOTÓN GUARDAR ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  int tolerancia = int.tryParse(toleranciaController.text) ?? 15;
                  
                  // NUEVO: Guardamos también la hora de salida en el documento del usuario
                  await FirebaseFirestore.instance.collection('usuarios').doc(trabajadorId).update({
                    'horaEntrada': horaEntradaController.text.trim(),
                    'horaSalida': horaSalidaController.text.trim(), // <- Guardado en base de datos
                    'toleranciaMinutos': tolerancia,
                  });
                  
                  Navigator.pop(context);
                },
                child: Text("Guardar Horario", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}