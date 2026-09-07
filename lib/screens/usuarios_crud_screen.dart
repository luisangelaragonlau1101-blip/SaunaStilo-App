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
  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF1E1E1E);
  static const Color colorMorado = Color(0xFF8B5CF6);

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
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: nombreCtrl, 
                      style: const TextStyle(color: Colors.white), 
                      cursorColor: colorMorado, 
                      decoration: const InputDecoration(labelText: "Nombre", labelStyle: TextStyle(color: Colors.white54), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
                    ),
                    const SizedBox(height: 10),
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: correoCtrl, 
                      style: const TextStyle(color: Colors.white), 
                      cursorColor: colorMorado, 
                      enabled: !esEdicion, 
                      decoration: const InputDecoration(labelText: "Correo Electrónico", labelStyle: TextStyle(color: Colors.white54), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
                    ),
                    const SizedBox(height: 10),

                    if (!esEdicion) ...[
                      TextField(contextMenuBuilder: privacyTextMenu,
                        controller: passwordTemporalCtrl,
                        obscureText: ocultarPasswordTemporal,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: colorMorado,
                        decoration: InputDecoration(
                          labelText: "Contraseña temporal",
                          helperText: "Mínimo 8 caracteres. Compártela de forma privada.",
                          helperStyle: const TextStyle(color: Colors.white38),
                          errorText: errorPasswordTemporal,
                          labelStyle: const TextStyle(color: Colors.white54),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: colorMorado),
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          suffixIcon: IconButton(
                            tooltip: ocultarPasswordTemporal
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              ocultarPasswordTemporal
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
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
                      const SizedBox(height: 10),
                    ],
                    
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: fechaCtrl,
                      readOnly: true, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Fecha de Cumpleaños",
                        labelStyle: TextStyle(color: Colors.white54),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
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
                                colorScheme: const ColorScheme.dark(
                                  primary: colorMorado,
                                  onPrimary: Colors.white,
                                  surface: colorTarjeta,
                                  onSurface: Colors.white,
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
                    const SizedBox(height: 10),
                    
                    // --- NUEVOS CAMPOS EN EL DIÁLOGO ---
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: sueldoCtrl, 
                      style: const TextStyle(color: Colors.white), 
                      cursorColor: colorMorado, 
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Sueldo Base Semanal (\$)", 
                        labelStyle: TextStyle(color: Colors.white54), 
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)), 
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        prefixIcon: Icon(Icons.attach_money_rounded, color: Colors.white54, size: 18)
                      )
                    ),
                    const SizedBox(height: 10),
                    
                    SwitchListTile(
                      title: Text("Horario base:", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(trabajaSabados ? "Lunes - Sábado" : "Lunes - Viernes", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      value: trabajaSabados,
                      activeColor: colorMorado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool valor) {
                        setStateDialog(() {
                          trabajaSabados = valor;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    DropdownButtonFormField<String>(
                      value: ['admin', 'trabajador', 'maestro', 'almacenista'].contains(rolSeleccionado) ? rolSeleccionado : 'trabajador',
                      dropdownColor: colorTarjeta, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Rol", 
                        labelStyle: TextStyle(color: Colors.white54), 
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
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
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54))),
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
                          const SnackBar(
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
              title: Text('Confirmar Eliminación', style: GoogleFonts.montserrat(color: Colors.white)),
              content: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Para eliminar este usuario, ingresa tu contraseña de administrador:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(contextMenuBuilder: privacyTextMenu,
                      controller: passwordCtrl,
                      obscureText: ocultarPassword,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: colorMorado,
                      decoration: InputDecoration(
                        labelText: "Tu Contraseña",
                        labelStyle: const TextStyle(color: Colors.white54),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: colorMorado)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        errorText: errorMensaje, 
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
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
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator(color: colorMorado)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verificando ? null : () => Navigator.pop(context, false), 
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54))
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
                  child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
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
            const SnackBar(content: Text('Usuario eliminado de la base de datos'), backgroundColor: Colors.green),
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
          insetPadding: const EdgeInsets.all(10), 
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
                  return const Center(
                    child: CircularProgressIndicator(color: colorMorado),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorTarjeta,
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.broken_image, color: Colors.white54, size: 50),
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
        title: Text("Gestión de Usuarios", style: GoogleFonts.montserrat(color: Colors.white))
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('fecha_registro', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: colorMorado));
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var rawData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              UserModel usuario = UserModel.fromFirestore(snapshot.data!.docs[index]);
              
              String horaEntrada = rawData['horaEntrada'] ?? 'Sin horario';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                padding: const EdgeInsets.all(16), // Agregamos padding interno a la tarjeta
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
                                  style: const TextStyle(color: colorMorado, fontWeight: FontWeight.bold, fontSize: 18)
                                )
                              : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // El Expanded evita que textos largos rompan la fila
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(usuario.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              // El overflow evita que el correo haga saltos de línea feos
                              Text(
                                usuario.correo, 
                                style: const TextStyle(color: Colors.white54, fontSize: 13), 
                                overflow: TextOverflow.ellipsis 
                              ),
                              const SizedBox(height: 8),
                              // Etiqueta visual para el ROL
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorMorado.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colorMorado.withOpacity(0.5)),
                                ),
                                child: Text(
                                  usuario.rol.toUpperCase(),
                                  style: const TextStyle(color: colorMorado, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.white12, height: 1), // Línea separadora sutil
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
                              Text("Sueldo Base: \$${usuario.sueldoBaseSemanal?.toStringAsFixed(2) ?? '0.00'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text("Horario: $horaEntrada", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        // Ajustamos los constraints de los botones para que ocupen menos espacio horizontal
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              icon: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF00B0FF), size: 22), 
                              onPressed: () => mostrarModalHorario(context, usuario.id, usuario.nombre)
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              icon: const Icon(Icons.edit, color: colorMorado, size: 22), 
                              onPressed: () => _mostrarDialogoUsuario(usuarioActual: usuario)
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.only(left: 8),
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 22), 
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
        child: const Icon(Icons.add, color: Colors.white)
      ),
    );
  }


}
