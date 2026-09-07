import '../services/external_transfer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import 'perfil_social_screen.dart';

class PerfilesEquipoScreen extends StatefulWidget {
  final UserModel usuarioActual;

  const PerfilesEquipoScreen({super.key, required this.usuarioActual});

  @override
  State<PerfilesEquipoScreen> createState() => _PerfilesEquipoScreenState();
}

class _PerfilesEquipoScreenState extends State<PerfilesEquipoScreen> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('EQUIPO', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              onChanged: (value) => setState(() => _busqueda = value.trim().toLowerCase()),
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar trabajador o administrador',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF171717),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('No se pudo cargar el equipo. Revisa conexión y permisos.'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final usuarios = snapshot.data!.docs.where((doc) {
                  final nombre = doc.data()['nombre']?.toString().toLowerCase() ?? '';
                  return nombre.contains(_busqueda);
                }).toList(growable: false);
                usuarios.sort((a, b) {
                  final ar = a.data()['rol']?.toString() ?? '';
                  final br = b.data()['rol']?.toString() ?? '';
                  if (ar == AppRoles.admin && br != AppRoles.admin) return -1;
                  if (br == AppRoles.admin && ar != AppRoles.admin) return 1;
                  return (a.data()['nombre']?.toString() ?? '')
                      .compareTo(b.data()['nombre']?.toString() ?? '');
                });
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                  itemCount: usuarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data();
                    final nombre = data['nombre']?.toString() ?? 'Usuario';
                    final rol = data['rol']?.toString() ?? AppRoles.trabajador;
                    final foto = data['fotoUrl']?.toString() ?? '';
                    return ListTile(
                      tileColor: const Color(0xFF171717),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF8B5CF6),
                        backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                        child: foto.isEmpty
                            ? Text(nombre.isEmpty ? 'U' : nombre[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        nombre,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        rol == AppRoles.admin ? 'Perfil de administración' : rol.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: rol == AppRoles.admin
                              ? const Color(0xFFFFDE21)
                              : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PerfilSocialScreen(
                            usuarioActual: widget.usuarioActual,
                            perfilId: doc.id,
                          ),
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
