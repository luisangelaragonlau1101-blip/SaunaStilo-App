import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import 'admin_modal_horario.dart';

class UsuariosCrudScreen extends StatefulWidget {
  const UsuariosCrudScreen({Key? key}) : super(key: key);

  @override
  State<UsuariosCrudScreen> createState() => _UsuariosCrudScreenState();
}

class _UsuariosCrudScreenState extends State<UsuariosCrudScreen> {
  Color get colorFondo => StiloColors.background;
  Color get colorTarjeta => StiloColors.surface;
  Color get colorMorado => StiloColors.accent;

  Future<bool> _esAdministradorActual() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final perfil = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    return perfil.data()?['rol'] == 'admin';
  }

  void _mostrarDialogoUsuario({UserModel? usuarioActual}) {
    bool esEdicion = usuarioActual != null;

    TextEditingController nombreCtrl = TextEditingController(text: esEdicion ? usuarioActual.nombre : '');
    TextEditingController correoCtrl = TextEditingController(text: esEdicion ? usuarioActual.correo : '');
    TextEditingController passwordTemporalCtrl = TextEditingController();
    bool ocultarPasswordTemporal = true;
    String? errorPasswordTemporal;
    String rolSeleccionado = esEdicion ? usuarioActual.rol : 'trabajador';
    DateTime? fechaCumpleanos = esEdicion ? usuarioActual.cumpleanos : null;

    TextEditingController sueldoCtrl = TextEditingController(text: esEdicion ? (usuarioActual.sueldoBaseSemanal?.toString() ?? '') : '');
    bool trabajaSabados = esEdicion ? (usuarioActual.trabajaSabados ?? false) : false;

    TextEditingController fechaCtrl = TextEditingController(
      text: fechaCumpleanos != null
          ? "${fechaCumpleanos!.day.toString().padLeft(2, '0')}/${fechaCumpleanos!.month.toString().padLeft(2, '0')}/${fechaCumpleanos!.year}"
          : ''
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colorTarjeta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(esEdicion ? 'Editar Usuario' : 'Nuevo Usuario',
                  style: GoogleFonts.montserrat(color: StiloColors.text, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: nombreCtrl,
                      style: TextStyle(color: StiloColors.text),
                      cursorColor: colorMorado,
                      decoration: InputDecoration(labelText: "Nombre", labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))))
                    ),
                    SizedBox(height: 10),
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: correoCtrl,
                      style: TextStyle(color: StiloColors.text),
                      cursorColor: colorMorado,
                      enabled: !esEdicion,
                      decoration: InputDecoration(labelText: "Correo Electrónico", labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))))
                    ),
                    SizedBox(height: 10),

                    if (!esEdicion) ...[
                      TextField(contextMenuBuilder: privacyTextMenu,
                        controller: passwordTemporalCtrl,
                        obscureText: ocultarPasswordTemporal,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: TextStyle(color: StiloColors.text),
                        cursorColor: colorMorado,
                        decoration: InputDecoration(
                          labelText: "Contraseña temporal",
                          helperText: "Mínimo 8 caracteres. Compártela de forma privada.",
                          helperStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38)),
                          errorText: errorPasswordTemporal,
                          labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: colorMorado),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24)),
                          ),
                          suffixIcon: IconButton(
                            tooltip: ocultarPasswordTemporal
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              ocultarPasswordTemporal
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: StiloColors.text.withValues(alpha: .54),
                            ),
                            onPressed: () => setStateDialog(() {
                              ocultarPasswordTemporal = !ocultarPasswordTemporal;
                            }),
                          ),
                        ),
                        onChanged: (_) {
                          if (errorPasswordTemporal != null) {
                            setStateDialog(() => errorPasswordTemporal = null);
                          }
                        },
                      ),
                      SizedBox(height: 10),
                    ],

                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: fechaCtrl,
                      readOnly: true,
                      style: TextStyle(color: StiloColors.text),
                      decoration: InputDecoration(
                        labelText: "Fecha de Cumpleaños",
                        labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))),
                        suffixIcon: Icon(Icons.calendar_today, color: colorMorado, size: 20),
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: fechaCumpleanos ?? DateTime(2000),
                          firstDate: DateTime(1900),
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

                        if (pickedDate != null) {
                          setStateDialog(() {
                            fechaCumpleanos = pickedDate;
                            fechaCtrl.text = "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
                          });
                        }
                      },
                    ),
                    SizedBox(height: 10),

                    // --- NUEVOS CAMPOS EN EL DIÁLOGO ---
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: sueldoCtrl,
                      style: TextStyle(color: StiloColors.text),
                      cursorColor: colorMorado,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Sueldo Base Semanal (\$)",
                        labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))),
                        prefixIcon: Icon(Icons.attach_money_rounded, color: StiloColors.text.withValues(alpha: .54), size: 18)
                      )
                    ),
                    SizedBox(height: 10),

                    SwitchListTile(
                      title: Text("Horario base:", style: TextStyle(color: StiloColors.text, fontSize: 14)),
                      subtitle: Text(trabajaSabados ? "Lunes - Sábado" : "Lunes - Viernes", style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
                      value: trabajaSabados,
                      activeColor: colorMorado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool valor) {
                        setStateDialog(() {
                          trabajaSabados = valor;
                        });
                      },
                    ),
                    SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: ['admin', 'trabajador', 'maestro', 'almacenista'].contains(rolSeleccionado) ? rolSeleccionado : 'trabajador',
                      dropdownColor: colorTarjeta,
                      style: TextStyle(color: StiloColors.text),
                      decoration: InputDecoration(
                        labelText: "Rol",
                        labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24)))
                      ),
                      items: ['admin', 'trabajador', 'maestro', 'almacenista']
                          .map((String rol) => DropdownMenuItem<String>(value: rol, child: Text(rol.toUpperCase())))
                          .toList(),
                      onChanged: (String? nuevoValor) => setStateDialog(() => rolSeleccionado = nuevoValor!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54)))),
                TextButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty || correoCtrl.text.isEmpty) return;
                    if (!esEdicion && passwordTemporalCtrl.text.length < 8) {
                      setStateDialog(() {
                        errorPasswordTemporal =
                            'La contraseña debe tener al menos 8 caracteres';
                      });
                      return;
                    }

                    if (!await _esAdministradorActual()) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Solo la cuenta administradora puede crear usuarios o asignar roles.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

                    final usuarioData = UserModel(
                      id: esEdicion ? usuarioActual.id : '',
                      nombre: nombreCtrl.text.trim(),
                      correo: correoCtrl.text.trim(),
                      rol: rolSeleccionado,
                      cumpleanos: fechaCumpleanos,
                      fechaRegistro: esEdicion ? usuarioActual.fechaRegistro : DateTime.now(),
                      fotoUrl: esEdicion ? usuarioActual.fotoUrl : null,

                      // Mantener horarios existentes al editar
                      horaEntrada: esEdicion ? usuarioActual.horaEntrada : null,
                      horaSalida: esEdicion ? usuarioActual.horaSalida : null,
                      toleranciaMinutos: esEdicion ? usuarioActual.toleranciaMinutos : 11,

                      // NUEVOS DATOS
                      sueldoBaseSemanal: double.tryParse(sueldoCtrl.text),
                      trabajaSabados: trabajaSabados,
                    );

                    FirebaseApp? tempApp;
                    User? usuarioAuthCreado;
                    bool perfilCreado = false;

                    try {
                      if (esEdicion) {
                        await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(usuarioActual.id)
                            .update(usuarioData.toFirestore());
                      } else {
                        tempApp = await Firebase.initializeApp(
                          name: 'AppTemporalCreacion_${DateTime.now().microsecondsSinceEpoch}',
                          options: Firebase.app().options,
                        );

                        UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
                            .createUserWithEmailAndPassword(
                          email: correoCtrl.text.trim(),
                          password: passwordTemporalCtrl.text,
                        );
                        usuarioAuthCreado = cred.user;

                        await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(cred.user!.uid)
                            .set(usuarioData.toFirestore());
                        perfilCreado = true;
                      }

                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (!perfilCreado && usuarioAuthCreado != null) {
                        try {
                          await usuarioAuthCreado.delete();
                        } catch (_) {
                          // La cuenta incompleta se podrá limpiar desde Firebase Auth.
                        }
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      await tempApp?.delete();
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

  Future<void> _eliminarUsuario(String id) async {
    TextEditingController passwordCtrl = TextEditingController();
    bool verificando = false;
    String? errorMensaje;
    bool ocultarPassword = true;

    bool confirmar = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colorTarjeta,
              title: Text('Confirmar Eliminación', style: GoogleFonts.montserrat(color: StiloColors.text)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para eliminar este usuario, ingresa tu contraseña de administrador:',
                      style: TextStyle(color: StiloColors.text.withValues(alpha: .70)),
                    ),
                    SizedBox(height: 16),
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: passwordCtrl,
                      obscureText: ocultarPassword,
                      style: TextStyle(color: StiloColors.text),
                      cursorColor: colorMorado,
                      decoration: InputDecoration(
                        labelText: "Tu Contraseña",
                        labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: StiloColors.text.withValues(alpha: .24))),
                        errorText: errorMensaje,
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarPassword ? Icons.visibility_off : Icons.visibility,
                            color: StiloColors.text.withValues(alpha: .54),
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              ocultarPassword = !ocultarPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    if (verificando) ...[
                      SizedBox(height: 16),
                      Center(child: CircularProgressIndicator(color: colorMorado)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verificando ? null : () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: TextStyle(color: StiloColors.text.withValues(alpha: .54)))
                ),
                TextButton(
                  onPressed: verificando ? null : () async {
                    if (passwordCtrl.text.isEmpty) {
                      setStateDialog(() => errorMensaje = "Ingresa tu contraseña");
                      return;
                    }

                    setStateDialog(() {
                      verificando = true;
                      errorMensaje = null;
                    });

                    try {
                      User? currentUser = FirebaseAuth.instance.currentUser;

                      if (currentUser != null && currentUser.email != null) {
                        AuthCredential credential = EmailAuthProvider.credential(
                          email: currentUser.email!,
                          password: passwordCtrl.text.trim(),
                        );

                        await currentUser.reauthenticateWithCredential(credential);
                        Navigator.pop(context, true);
                      }
                    } on FirebaseAuthException catch (e) {
                      setStateDialog(() {
                        verificando = false;
                        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                          errorMensaje = "Contraseña incorrecta";
                        } else {
                          errorMensaje = "Error: ${e.message}";
                        }
                      });
                    } catch (e) {
                      setStateDialog(() {
                        verificando = false;
                        errorMensaje = "Ocurrió un error inesperado";
                      });
                    }
                  },
                  child: Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                ),
              ],
            );
          }
        );
      },
    ) ?? false;

    if (confirmar) {
      try {
        await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario eliminado de la base de datos'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _mostrarImagenGrande(String urlImagen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            clipBehavior: Clip.none,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                urlImagen,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(color: colorMorado),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorTarjeta,
                    padding: EdgeInsets.all(20),
                    child: Icon(Icons.broken_image, color: StiloColors.text.withValues(alpha: .54), size: 50),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        title: Text("Gestión de Usuarios", style: GoogleFonts.montserrat(color: StiloColors.text))
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('fecha_registro', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: colorMorado));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var rawData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              UserModel usuario = UserModel.fromFirestore(snapshot.data!.docs[index]);

              String horaEntrada = rawData['horaEntrada'] ?? 'Sin horario';

              return Container(
                margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
                padding: EdgeInsets.all(16), // Agregamos padding interno a la tarjeta
                decoration: BoxDecoration(color: colorTarjeta, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECCIÓN SUPERIOR: Info del usuario ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty) {
                              _mostrarImagenGrande(usuario.fotoUrl!);
                            }
                          },
                          child: CircleAvatar(
                            radius: 24, // Hacemos el avatar un poco más grande
                            backgroundColor: colorMorado.withOpacity(0.2),
                            backgroundImage: usuario.fotoUrl != null ? NetworkImage(usuario.fotoUrl!) : null,
                            child: usuario.fotoUrl == null
                              ? Text(
                                  usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : 'U',
                                  style: TextStyle(color: colorMorado, fontWeight: FontWeight.bold, fontSize: 18)
                                )
                              : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        // El Expanded evita que textos largos rompan la fila
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(usuario.nombre, style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 2),
                              // El overflow evita que el correo haga saltos de línea feos
                              Text(
                                usuario.correo,
                                style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 13),
                                overflow: TextOverflow.ellipsis
                              ),
                              SizedBox(height: 8),
                              // Etiqueta visual para el ROL
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorMorado.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colorMorado.withOpacity(0.5)),
                                ),
                                child: Text(
                                  usuario.rol.toUpperCase(),
                                  style: TextStyle(color: colorMorado, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: StiloColors.text.withValues(alpha: .12), height: 1), // Línea separadora sutil
                    ),

                    // --- SECCIÓN INFERIOR: Detalles y Botones ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Sueldo Base: \$${usuario.sueldoBaseSemanal?.toStringAsFixed(2) ?? '0.00'}", style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 13)),
                              SizedBox(height: 4),
                              Text("Horario: $horaEntrada", style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 13)),
                            ],
                          ),
                        ),
                        // Ajustamos los constraints de los botones para que ocupen menos espacio horizontal
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              icon: Icon(Icons.access_time_filled_rounded, color: Color(0xFF00B0FF), size: 22),
                              onPressed: () => mostrarModalHorario(context, usuario.id, usuario.nombre)
                            ),
                            IconButton(
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              icon: Icon(Icons.edit, color: colorMorado, size: 22),
                              onPressed: () => _mostrarDialogoUsuario(usuarioActual: usuario)
                            ),
                            IconButton(
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.only(left: 8),
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 22),
                              onPressed: () => _eliminarUsuario(usuario.id)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorMorado,
        onPressed: () => _mostrarDialogoUsuario(),
        child: Icon(Icons.add, color: StiloColors.text)
      ),
    );
  }


}
