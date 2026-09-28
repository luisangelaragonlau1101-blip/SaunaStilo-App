import '../widgets/inline_photo.dart';
import '../presentation/appearance.dart';
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
      backgroundColor: StiloColors.background,
      appBar: AppBar(
        backgroundColor: StiloColors.background,
        title: Text('EQUIPO', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: TextField(contextMenuBuilder: privacyTextMenu,
              onChanged: (value) => setState(() => _busqueda = value.trim().toLowerCase()),
              style: GoogleFonts.inter(color: StiloColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar trabajador o administrador',
                hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38)),
                prefixIcon: Icon(Icons.search_rounded, color: StiloColors.text.withValues(alpha: .54)),
                filled: true,
                fillColor: StiloColors.surface,
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
                if (snapshot.hasError) return Center(child: Text('No se pudo cargar el equipo. Revisa conexión y permisos.'));
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
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
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 100),
                  itemCount: usuarios.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = usuarios[index];
                    final data = doc.data();
                    final nombre = data['nombre']?.toString() ?? 'Usuario';
                    final rol = data['rol']?.toString() ?? AppRoles.trabajador;
                    final foto = data['fotoUrl']?.toString() ?? '';
                    return ListTile(
                      tileColor: StiloColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: StiloColors.accent,
                        backgroundImage: foto.isNotEmpty ? stiloImageProvider(foto) : null,
                        child: foto.isEmpty
                            ? Text(nombre.isEmpty ? 'U' : nombre[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        nombre,
                        style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        rol == AppRoles.admin ? 'Perfil de administración' : rol.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: rol == AppRoles.admin
                              ? Color(0xFFFFDE21)
                              : StiloColors.text.withValues(alpha: .38),
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: StiloColors.text.withValues(alpha: .38)),
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
