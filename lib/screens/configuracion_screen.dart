import '../presentation/appearance.dart';
import '../widgets/team_profile_details.dart';
import '../widgets/profile_networks.dart';
import 'streak_overview_screen.dart';
import 'payroll_records_screen.dart';
import 'admin_asistencias_screen.dart';
import 'perfiles_equipo_screen.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/media_upload_service.dart';
import 'usuarios_crud_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_modal_horario.dart'; // <-- IMPORTAMOS EL MODAL DE HORARIOS

class ConfiguracionScreen extends StatefulWidget {
  final UserModel usuario;
  final bool embedded;

  const ConfiguracionScreen({Key? key, required this.usuario, this.embedded = false}) : super(key: key);

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  Color get colorFondo => StiloColors.background;
  Color get colorTarjeta => StiloColors.surface;
  Color get colorMorado => StiloColors.accent;

  bool _subiendoFoto = false;
  final _media = MediaUploadService();

  // 📸 LÓGICA PARA SUBIR FOTO DE PERFIL
  Future<void> _actualizarFotoPerfil() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _subiendoFoto = true);
      try {
        final archivo = await _media.upload(
          bytes: await pickedFile.readAsBytes(),
          fileName: pickedFile.name.isEmpty ? 'perfil.jpg' : pickedFile.name,
          contentType: _mimeImagen(pickedFile.name),
          folder: 'perfiles/${widget.usuario.id}',
        );

        await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).update({
          'fotoUrl': archivo.url,
          'fotoRuta': archivo.path,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto actualizada correctamente', style: TextStyle(color: StiloColors.text)), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e', style: TextStyle(color: StiloColors.text)), backgroundColor: Colors.redAccent),
        );
      } finally {
        setState(() => _subiendoFoto = false);
      }
    }
  }

  String _mimeImagen(String nombre) {
    final limpio = nombre.toLowerCase();
    if (limpio.endsWith('.png')) return 'image/png';
    if (limpio.endsWith('.webp')) return 'image/webp';
    if (limpio.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  // ✏️ LÓGICA PARA EDITAR NOMBRE
  Future<void> _editarNombre(String nombreActual) async {
    TextEditingController _nombreController = TextEditingController(text: nombreActual);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorTarjeta,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar Nombre', style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.bold)),
          content: TextField(contextMenuBuilder: privacyTextMenu,
            controller: _nombreController,
            style: TextStyle(color: StiloColors.text),
            cursorColor: colorMorado,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "Escribe tu nombre",
              hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))),
            ),
            TextButton(
              onPressed: () async {
                String nuevoNombre = _nombreController.text.trim();
                if (nuevoNombre.isNotEmpty && nuevoNombre != nombreActual) {
                  await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).update({
                    'nombre': nuevoNombre,
                  });
                }
                if (mounted) Navigator.pop(context);
              },
              child: Text('Guardar', style: GoogleFonts.inter(color: colorMorado, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 📅 LÓGICA PARA EDITAR CUMPLEAÑOS
  Future<void> _editarCumpleanos(DateTime? fechaActual) async {
    DateTime initialDate = fechaActual ?? DateTime(2000);

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: colorMorado,
              onPrimary: StiloColors.text,
              surface: colorTarjeta,
              onSurface: StiloColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null && fechaSeleccionada != fechaActual) {
      await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).update({
        'cumpleanos': Timestamp.fromDate(fechaSeleccionada),
      });
    }
  }

  // 🔒 LÓGICA PARA CAMBIAR CONTRASEÑA
  Future<void> _cambiarContrasena() async {
    TextEditingController _passwordController = TextEditingController();
    bool _ocultarPassword = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colorTarjeta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Cambiar Contraseña', style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.bold)),
              content: TextField(contextMenuBuilder: privacyTextMenu,
                controller: _passwordController,
                obscureText: _ocultarPassword,
                style: TextStyle(color: StiloColors.text),
                cursorColor: colorMorado,
                decoration: InputDecoration(
                  hintText: "Nueva contraseña (mín. 8 caracteres)",
                  hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: StiloColors.text.withValues(alpha: .54)),
                    onPressed: () {
                      setStateDialog(() {
                        _ocultarPassword = !_ocultarPassword;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))),
                ),
                TextButton(
                  onPressed: () async {
                    String nuevaContrasena = _passwordController.text.trim();
                    if (nuevaContrasena.length >= 8) {
                      try {
                        await FirebaseAuth.instance.currentUser!.updatePassword(nuevaContrasena);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contraseña actualizada con éxito', style: TextStyle(color: StiloColors.text)), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: Puede que necesites volver a iniciar sesión para hacer esto.', style: TextStyle(color: StiloColors.text)), backgroundColor: Colors.redAccent),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres', style: TextStyle(color: StiloColors.text)), backgroundColor: Colors.orange),
                      );
                    }
                  },
                  child: Text('Guardar', style: GoogleFonts.inter(color: colorMorado, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('No se pudo cargar tu perfil. Vuelve a abrirlo.')));
        if (snapshot.hasData && !snapshot.data!.exists) return Scaffold(body: Center(child: Text('Tu perfil no está disponible.')));
        if (!snapshot.hasData) {
          return Scaffold(backgroundColor: colorFondo, body: Center(child: CircularProgressIndicator(color: colorMorado)));
        }

        UserModel usuarioActualizado = UserModel.fromFirestore(snapshot.data!);
        Map<String, dynamic> rawData = snapshot.data!.data() as Map<String, dynamic>;

        final inicial = usuarioActualizado.nombre.isNotEmpty ? usuarioActualizado.nombre[0].toUpperCase() : 'U';

        String mesRegistro = DateFormat('MMMM yyyy', 'es').format(usuarioActualizado.fechaRegistro);
        String fechaRegistroStr = "${mesRegistro[0].toUpperCase()}${mesRegistro.substring(1)}";

        String cumpleanosStr = usuarioActualizado.cumpleanos != null
            ? "${usuarioActualizado.cumpleanos!.day.toString().padLeft(2, '0')} de ${DateFormat('MMMM', 'es').format(usuarioActualizado.cumpleanos!)}"
            : 'Toca para agregar';

        if (usuarioActualizado.cumpleanos != null) {
          List<String> partes = cumpleanosStr.split(' de ');
          if (partes.length == 2) {
             cumpleanosStr = "${partes[0]} de ${partes[1][0].toUpperCase()}${partes[1].substring(1)}";
          }
        }

        // --- EXTRACCIÓN DEL HORARIO ASIGNADO ---
        String horaEntrada = rawData['horaEntrada'] ?? 'Sin asignar';
        int tolerancia = rawData['toleranciaMinutos'] ?? 0;
        String horarioTexto = horaEntrada == 'Sin asignar'
            ? 'Contacta al administrador'
            : '$horaEntrada hrs (Tolerancia: $tolerancia min)';
        bool isAdmin = usuarioActualizado.rol.toLowerCase() == 'admin';

        return Scaffold(
          backgroundColor: colorFondo,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      if (!widget.embedded) Container(
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: StiloColors.text.withOpacity(0.1)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: StiloColors.text, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        "Perfil y Ajustes",
                        style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: StiloColors.text),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    physics: BouncingScrollPhysics(),
                    children: [
                      ListTile(leading: Icon(Icons.palette_outlined), title: Text('Personalizar mi panel'), subtitle: Text('Colores, vista sencilla y celebraciones'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()))),
                      ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('Nómina y registros'), subtitle: Text('Horarios, bonos y descuentos guardados'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => isAdmin ? AdminAsistenciasScreen(nombreAdmin: usuarioActualizado.nombre) : PayrollRecordsScreen(user: usuarioActualizado)))),
                      ListTile(leading: Icon(Icons.local_fire_department_outlined), title: Text('Rachas de asistencia'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StreakOverviewScreen(user: usuarioActualizado)))),
                      if (isAdmin) ListTile(leading: Icon(Icons.military_tech_outlined), title: Text('Otorgar insignias al equipo'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PerfilesEquipoScreen(usuarioActual: usuarioActualizado)))),
                      // --- SECCIÓN DE PERFIL VISUAL ---
                      Center(
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            GestureDetector(
                              onTap: _subiendoFoto ? null : _actualizarFotoPerfil,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [StiloColors.accent, Color(0xFF6D28D9)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(color: colorMorado.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 5)),
                                      ],
                                      image: usuarioActualizado.fotoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(usuarioActualizado.fotoUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: _subiendoFoto
                                        ? CircularProgressIndicator(color: StiloColors.text)
                                        : (usuarioActualizado.fotoUrl == null
                                            ? Text(inicial, style: GoogleFonts.montserrat(fontSize: 40, fontWeight: FontWeight.bold, color: StiloColors.text))
                                            : null),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorTarjeta,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: StiloColors.text.withValues(alpha: .24), width: 2),
                                    ),
                                    child: Icon(Icons.camera_alt_rounded, color: StiloColors.text, size: 16),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  usuarioActualizado.nombre,
                                  style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, color: StiloColors.text),
                                ),
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _editarNombre(usuarioActualizado.nombre),
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorMorado.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit_rounded, color: colorMorado, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorMorado.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                usuarioActualizado.rol.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: colorMorado, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),
                      TeamProfileDetails(usuarioActual: usuarioActualizado, perfilId: usuarioActualizado.id, data: rawData),
                      ProfileNetworks(profileId: usuarioActualizado.id, editable: true, data: rawData['redesSociales']),
                      SizedBox(height: 40),

                      Text(
                        "MI CUENTA",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: StiloColors.text.withValues(alpha: .38), letterSpacing: 1.2),
                      ),
                      SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            _buildFilaAjuste(
                              icono: Icons.email_outlined,
                              titulo: "Correo Electrónico",
                              valor: usuarioActualizado.correo,
                              mostrarBorde: true,
                            ),
                            _buildFilaAjuste(
                              icono: Icons.cake_outlined,
                              titulo: "Cumpleaños",
                              valor: cumpleanosStr,
                              mostrarBorde: true,
                              editable: true,
                              onTap: () => _editarCumpleanos(usuarioActualizado.cumpleanos),
                            ),
                            _buildFilaAjuste(
                              icono: Icons.calendar_today_rounded,
                              titulo: "Miembro desde",
                              valor: fechaRegistroStr,
                              mostrarBorde: false,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // --- NUEVA SECCIÓN: HORARIO ASIGNADO ---
                      Text(
                        "HORARIO Y ASISTENCIA",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: StiloColors.text.withValues(alpha: .38), letterSpacing: 1.2),
                      ),
                      SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                        ),
                        child: _buildFilaAjuste(
                          icono: Icons.access_time_filled_rounded,
                          titulo: "Entrada y Tolerancia",
                          valor: horarioTexto,
                          mostrarBorde: false,
                          editable: isAdmin, // Solo si es admin puede editar su propio horario aquí
                          onTap: isAdmin ? () => mostrarModalHorario(context, usuarioActualizado.id, usuarioActualizado.nombre) : null,
                        ),
                      ),

                      SizedBox(height: 30),

                      Text(
                        "SEGURIDAD",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: StiloColors.text.withValues(alpha: .38), letterSpacing: 1.2),
                      ),
                      SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                        ),
                        child: _buildFilaAjuste(
                          icono: Icons.lock_outline_rounded,
                          titulo: "Contraseña",
                          valor: "••••••••",
                          mostrarBorde: false,
                          editable: true,
                          onTap: _cambiarContrasena,
                        ),
                      ),

                      SizedBox(height: 30),

                      if (isAdmin) ...[
                        Text(
                          "ADMINISTRACIÓN",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: StiloColors.text.withValues(alpha: .38), letterSpacing: 1.2),
                        ),
                        SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: colorTarjeta,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                          ),
                          child: _buildFilaAjuste(
                            icono: Icons.manage_accounts_rounded,
                            titulo: "Gestión de Usuarios",
                            valor: "Ver, crear, editar y asignar horarios",
                            mostrarBorde: false,
                            editable: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UsuariosCrudScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 30),
                      ],
                      GestureDetector(
                        onTap: () async {
                          await AuthService().logout();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Cerrar Sesión",
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilaAjuste({
    required IconData icono,
    required String titulo,
    required String valor,
    bool mostrarBorde = true,
    bool editable = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: mostrarBorde
              ? Border(bottom: BorderSide(color: StiloColors.text.withOpacity(0.05), width: 1))
              : null,
        ),
        child: Row(
          children: [
            Icon(icono, color: StiloColors.text.withValues(alpha: .54), size: 22),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.inter(fontSize: 14, color: StiloColors.text, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 2),
                  Text(
                    valor,
                    style: GoogleFonts.inter(fontSize: 13, color: StiloColors.text.withValues(alpha: .38)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (editable)
              Icon(Icons.edit_rounded, color: colorMorado, size: 18),
          ],
        ),
      ),
    );
  }
}
