import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/proyecto_model.dart'; 
import '../models/actividad_model.dart'; 
import '../models/asistencia_model.dart'; 
import '../services/proyecto_service.dart'; 
import '../services/asistencia_service.dart';

import 'login_screen.dart';
import 'inventario_admin_screen.dart';
import 'inventario_trabajador_screen.dart'; 
import 'admin_clientes_screen.dart'; 
import 'incubadora_ideas_screen.dart'; 
import 'proyectos_admin_screen.dart';    
import 'proyectos_trabajador_screen.dart';               
import 'admin_ventas_main_screen.dart';
import 'admin_tipos_madera.dart'; 
import 'proveedores_screen.dart'; 
import 'seguimiento_cotizaciones_screen.dart'; 
import 'package:intl/intl.dart';
import 'configuracion_screen.dart';
import 'admin_solicitudes_herramientas_screen.dart';
import 'trabajador_tipos_madera.dart';
import 'trabajador_cajita_herramientas_screen.dart'; 
import 'admin_cajitas_screen.dart';
import 'calendario_cumpleanos_screen.dart';
import 'asistente_ia_screen.dart';
import 'blog_interno_screen.dart';
import 'notificaciones_screen.dart';
import 'reconocimientos_screen.dart';
import '../services/notificaciones_service.dart';

// --- PANTALLAS DE ASISTENCIAS ---
import 'trabajador_asistencia_screen.dart';
import 'admin_asistencias_screen.dart';
import 'racha_asistencias_screen.dart';
import 'admin_rachas_screen.dart'; 

// MODALES PARA EL DETALLE DE LAS ACTIVIDADES
import 'admin_modal_detalle_actividad.dart' as admin_view; 
import 'trabajador_modal_detalle_actividad.dart' as trabajador_view;

import 'proyectos_almacenista_screen.dart'; 



// --- FUNCIÓN GLOBAL PARA MOSTRAR LA IMAGEN EN GRANDE ---
void _mostrarImagenGrande(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.85),
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        elevation: 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, color: Colors.white54, size: 100);
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}


class Wrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  Wrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // 1. EL CONTENIDO DINÁMICO DE TU APP
          Positioned.fill(
            child: StreamBuilder<User?>(
              stream: _authService.userStream,
              builder: (context, authSnapshot) {
                Widget currentScreen;

                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  currentScreen = const _LoadingScreen(
                    mensaje: "Conectando con SaunaStilo...", 
                    key: ValueKey('loading_auth')
                  );
                } else if (!authSnapshot.hasData || authSnapshot.data == null) {
                  currentScreen = LoginScreen(key: const ValueKey('login'));
                } else {
                  currentScreen = StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('usuarios').doc(authSnapshot.data!.uid).snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const _LoadingScreen(
                          mensaje: "Preparando tu espacio...", 
                          key: ValueKey('loading_db')
                        );
                      }
                      
                      if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                        final usuario = UserModel.fromFirestore(userSnapshot.data!);
                        
                        if (usuario.rol == 'admin') {
                          return AdminDashboard(adminUser: usuario, key: const ValueKey('admin_dash'));
                        } else if (usuario.rol == 'almacenista') {
                          return AlmacenistaDashboard(usuario: usuario, key: const ValueKey('almacenista_dash'));
                        } else {
                          return OperativoDashboard(usuario: usuario, key: const ValueKey('operativo_dash'));
                        }
                      }
                      
                      return const _ErrorScreen(
                        mensaje: "Perfil no encontrado en la base de datos.", 
                        key: ValueKey('error_screen')
                      );
                    },
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: currentScreen,
                );
              },
            ),
          ),

          // 2. TU FIRMA FLOTANTE GLOBAL
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const MjoyDreamsFooter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ErrorScreen extends StatelessWidget {
  final String mensaje;
  const _ErrorScreen({Key? key, required this.mensaje}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(mensaje, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () => AuthService().logout(),
              icon: const Icon(Icons.logout, size: 18),
              label: Text("Cerrar sesión e intentar de nuevo", style: GoogleFonts.inter()),
            )
          ],
        ),
      ),
    );
  }
}


class _LoadingScreen extends StatefulWidget {
  final String mensaje;
  const _LoadingScreen({Key? key, required this.mensaje}) : super(key: key);

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2, 
                  colors: [
                    Color(0xFF1E1E1E), 
                    Color(0xFF000000), 
                  ],
                  stops: [0.0, 0.7], 
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.8), 
                  radius: 0.9,
                  colors: [
                    const Color(0xFF2A1B38).withOpacity(0.4), 
                    const Color(0xFF000000).withOpacity(0.0), 
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                            stops: [0.0, 0.15, 0.85, 1.0], 
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.1, 0.9, 1.0], 
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            'assets/logo_saunastilo.png',
                            height: 140, 
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.hot_tub_rounded, color: Color(0xFF8B5CF6), size: 80);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  const SizedBox(height: 30),
                  Text(
                    widget.mensaje, 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, letterSpacing: 0.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- PANEL DE CONTROL ADMIN ---
class AdminDashboard extends StatefulWidget {
  final UserModel adminUser;

  const AdminDashboard({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color colorFondo = Color(0xFF000000); 
  static const Color colorRosa = Color(0xFFFF3399);
  static const Color colorAzul = Color(0xFF00B0FF);
  static const Color colorAmarillo = Color(0xFFFFDE21);
  static const Color colorMorado = Color(0xFF8B5CF6); 
  static const Color colorVerde = Color(0xFF00E676); 
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorCyan = Color(0xFF00E5FF); 

  Future<void> _actualizarPantalla() async {
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.adminUser.nombre.isNotEmpty ? widget.adminUser.nombre : 'Admin'; 
    final ProyectoService _proyectoService = ProyectoService();

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: RefreshIndicator(
          color: colorMorado,
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: _actualizarPantalla,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/logo_saunastilo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => const Icon(Icons.hot_tub_rounded, color: colorMorado),
                        ),
                      ),
                      StreamBuilder<List<Proyecto>>(
                        stream: _proyectoService.getProyectos(),
                        builder: (context, snapshot) {
                          int activos = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'en_proceso').length : 0;
                          int pendientes = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'pendiente').length : 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProyectosAdminScreen(filtroInicial: 'en_proceso')),
                                  );
                                },
                                child: _buildDuoBadge(Icons.bolt_rounded, "$activos", colorAmarillo),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProyectosAdminScreen(filtroInicial: 'pendiente')),
                                  );
                                },
                                child: _buildDuoBadge(Icons.hourglass_empty_rounded, "$pendientes", colorCyan),
                              ),
                              const SizedBox(width: 12),
                              
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('solicitudes_herramientas')
                                    .where('estatus', isEqualTo: 'pendiente')
                                    .snapshots(),
                                builder: (context, snapshotTools) {
                                  int solicitudesPendientes = snapshotTools.hasData ? snapshotTools.data!.docs.length : 0;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.build_circle_outlined, color: colorRosa, size: 20),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const AdminSolicitudesHerramientasScreen()),
                                            );
                                          },
                                          tooltip: 'Solicitudes de Herramientas',
                                        ),
                                      ),
                                      
                                      if (solicitudesPendientes > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              solicitudesPendientes > 9 ? '9+' : '$solicitudesPendientes',
                                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ConfiguracionScreen(usuario: widget.adminUser),
                                      ),
                                    );
                                  },
                                  tooltip: 'Ajustes y Usuarios',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (widget.adminUser.fotoUrl != null && widget.adminUser.fotoUrl!.isNotEmpty) {
                                  _mostrarImagenGrande(context, widget.adminUser.fotoUrl!);
                                }
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                  color: Colors.white.withOpacity(0.1),
                                  image: widget.adminUser.fotoUrl != null && widget.adminUser.fotoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(widget.adminUser.fotoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: widget.adminUser.fotoUrl == null || widget.adminUser.fotoUrl!.isEmpty
                                    ? Text(
                                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                                        style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bienvenid@,", 
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nombre, 
                                    style: GoogleFonts.montserrat(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                          onPressed: () => AuthService().logout(),
                          tooltip: 'Cerrar Sesión',
                        ),
                      )
                    ],
                  ),
                ),
                
                StreamBuilder<List<Proyecto>>(
                  stream: _proyectoService.getProyectos(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator(color: colorMorado)),
                      );
                    }

                    final proyectosEnProceso = snapshot.data?.where((p) => p.estatus == 'en_proceso').toList() ?? [];

                    if (proyectosEnProceso.isEmpty) {
                      return const SizedBox.shrink(); 
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "PROYECTOS EN CURSO",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: colorVerde, letterSpacing: 1),
                                ),
                                const Icon(Icons.flag_rounded, color: colorVerde, size: 20),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 95, 
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: proyectosEnProceso.length,
                                itemBuilder: (context, index) {
                                  return _ProyectoDuoCard(
                                    proyecto: proyectosEnProceso[index],
                                    colorAmarillo: colorAmarillo,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Text(
                    "Panel de Control",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                
           GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05, 
                  children: [
                    const _MenuCard(titulo: "INVENTARIO", icono: Icons.inventory_2_rounded, color: colorAzul, destino: InventarioAdminScreen()),
                    const _MenuCard(titulo: "CLIENTES", icono: Icons.people_alt_rounded, color: colorRosa, destino: AdminClientesScreen()),
                    const _MenuCard(titulo: "VENTAS", icono: Icons.point_of_sale_rounded, color: colorAmarillo, destino: VentasScreen()),
                    _MenuCard(titulo: "PROYECTOS", icono: Icons.construction_rounded, color: colorVerde, destino: ProyectosAdminScreen()),
                    const _MenuCard(titulo: "CUMPLEAÑOS", icono: Icons.cake_rounded, color: colorRosa, destino: CalendarioCumpleanosScreen()),
                    
                    _MenuCard(
                      titulo: "ASISTENCIAS", 
                      icono: Icons.fact_check_rounded, 
                      color: colorMorado, 
                      destino: AdminAsistenciasScreen(nombreAdmin: widget.adminUser.nombre) 
                    ),
                    
                    const _MenuCard(titulo: "MADERAS", icono: Icons.forest_rounded, color: colorMorado, destino: CatalogoSaunasScreen()),
                    _MenuCard(titulo: "PROVEEDORES", icono: Icons.local_shipping_rounded, color: colorNaranja, destino: ProveedoresScreen()),
                    const _MenuCard(titulo: "COTIZA...", icono: Icons.request_quote_rounded, color: colorCyan, destino: SeguimientoCotizacionesScreen()),
                    const _MenuCard(titulo: "NUEVA IDEA", icono: Icons.lightbulb_outline_rounded, color: Color(0xFFA78BFA), destino: IncubadoraIdeasScreen()),
                    const _MenuCard(titulo: "CAJITAS", icono: Icons.home_repair_service_rounded, color: Color(0xFFFF9800), destino: AdminCajitasScreen()),
                    _MenuCard(titulo: "RACHAS", icono: Icons.local_fire_department_rounded, color: const Color(0xFFFF5722), destino: AdminRachasScreen(adminUser: widget.adminUser)),
                    _MenuCard(titulo: "ASISTENTE IA", icono: Icons.auto_awesome_rounded, color: colorMorado, destino: AsistenteIaScreen(usuario: widget.adminUser)),
                    _AvisosMenuCard(usuario: widget.adminUser, color: colorCyan),
                    _MenuCard(titulo: "RECONOCIMIENTOS", icono: Icons.workspace_premium_rounded, color: colorAmarillo, destino: ReconocimientosScreen(usuario: widget.adminUser)),
                    _MenuCard(titulo: "BLOG INTERNO", icono: Icons.auto_stories_rounded, color: colorRosa, destino: BlogInternoScreen(usuario: widget.adminUser)),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}


class _ProyectoDuoCard extends StatelessWidget {
  final Proyecto proyecto;
  final Color colorAmarillo;

  const _ProyectoDuoCard({required this.proyecto, required this.colorAmarillo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('actividades')
          .where('proyectoId', isEqualTo: proyecto.id)
          .snapshots(),
      builder: (context, actSnapshot) {
        int totalActividades = 0;
        int completadas = 0;
        List<ActividadModel> listaActividades = [];

        if (actSnapshot.hasData) {
          listaActividades = actSnapshot.data!.docs
              .map((doc) => ActividadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          totalActividades = listaActividades.length;
          completadas = listaActividades.where((a) => a.estatus == 'finalizado' || a.estatus == 'completado').length;
        }

        double porcentaje = totalActividades > 0 ? (completadas / totalActividades) : 0.0;
        String fechaEntregaStr = "${proyecto.fechaEntrega.day}/${proyecto.fechaEntrega.month}/${proyecto.fechaEntrega.year}";

        return GestureDetector(
          onTap: () => _mostrarDesgloseMisiones(context, proyecto, listaActividades, completadas, totalActividades),
          child: Container(
            width: MediaQuery.of(context).size.width - 74,
            margin: const EdgeInsets.only(right: 16),
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        proyecto.titulo,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      totalActividades > 0 ? "$completadas/$totalActividades completadas" : "Sin tareas asignadas",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorAmarillo),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 12,
                    child: LinearProgressIndicator(
                      value: porcentaje,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(colorAmarillo),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Entrega: $fechaEntregaStr",
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDesgloseMisiones(BuildContext context, Proyecto proj, List<ActividadModel> actividades, int completadas, int total) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        double porc = total > 0 ? (completadas / total) : 0.0;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          proj.titulo.toUpperCase(), 
                          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)
                        ),
                      ),
                      Text("$completadas/$total Tareas", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFFFDE21))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: porc, minHeight: 10, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFDE21))),
                  ),
                ),
                const SizedBox(height: 15),
                const Divider(color: Colors.white10),
                
                Expanded(
                  child: actividades.isEmpty
                      ? Center(child: Text("No hay actividades registradas.", style: GoogleFonts.inter(color: Colors.white38)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: actividades.length,
                          itemBuilder: (context, idx) {
                            final act = actividades[idx];
                            
                            bool estaAtrasada = act.estatus != 'completado' && DateTime.now().isAfter(act.fechaTermino);
                            String textoEstatus = estaAtrasada ? 'ATRASADO' : act.estatus;

                            Color estatusColor = act.estatus == 'completado'
                                ? Colors.greenAccent
                                : estaAtrasada
                                    ? Colors.redAccent 
                                    : act.estatus == 'en_progreso'
                                        ? Colors.cyanAccent
                                        : Colors.orangeAccent;

                            
                            return GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => admin_view.ModalDetalleActividad(actividad: act),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121212), 
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: estaAtrasada ? Colors.redAccent.withOpacity(0.3) : Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            act.titulo.toUpperCase(),
                                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: estatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            textoEstatus.toUpperCase(),
                                            style: GoogleFonts.inter(color: estatusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (act.descripcion.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        act.descripcion,
                                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    const Divider(color: Colors.white10, height: 1),
                                    const SizedBox(height: 10),
                                    
                                    Row(
                                      children: [
                                        Icon(
                                          estaAtrasada ? Icons.error_outline : Icons.calendar_today_rounded, 
                                          color: estaAtrasada ? Colors.redAccent : Colors.white30, 
                                          size: 14
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          estaAtrasada 
                                              ? "Venció el: ${DateFormat('dd/MM/yyyy HH:mm').format(act.fechaTermino)}"
                                              : "Límite: ${DateFormat('dd/MM/yyyy HH:mm').format(act.fechaTermino)}",
                                          style: GoogleFonts.inter(
                                            color: estaAtrasada ? Colors.redAccent : Colors.white54, 
                                            fontSize: 12,
                                            fontWeight: estaAtrasada ? FontWeight.bold : FontWeight.normal
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    
                                    FutureBuilder<String>(
                                      future: FirebaseFirestore.instance
                                          .collection('usuarios')
                                          .doc(act.asignadoATrabajadorId)
                                          .get()
                                          .then((doc) => doc.exists ? (doc.data() as Map)['nombre'] ?? 'Sin nombre' : 'No encontrado'),
                                      builder: (context, userSnap) {
                                        return Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, color: Colors.white30, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Asignado: ${userSnap.data ?? 'Cargando...'}",
                                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                            ),
                                            const Spacer(),
                                            if (act.totalEvidencias > 0)
                                              Row(
                                                children: [
                                                  const Icon(Icons.attach_file_rounded, color: Color(0xFF00B0FF), size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${act.totalEvidencias} evidencias",
                                                    style: GoogleFonts.inter(color: Color(0xFF00B0FF), fontSize: 11, fontWeight: FontWeight.bold),
                                                  )
                                                ],
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color color;
  final Widget? destino;
  final VoidCallback? onTap;

  const _MenuCard({required this.titulo, required this.icono, required this.color, this.destino, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (context) => destino!)),
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(icono, size: 90, color: color.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icono, size: 26, color: color),
                    ),
                    Text(
                      titulo, 
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisosMenuCard extends StatelessWidget {
  final UserModel usuario;
  final Color color;

  const _AvisosMenuCard({required this.usuario, required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificacionesService().noLeidosPara(
        usuarioId: usuario.id,
        rol: usuario.rol,
      ),
      builder: (context, snapshot) {
        final pendientes = snapshot.data ?? 0;
        return _MenuCard(
          titulo: pendientes > 0 ? 'AVISOS ($pendientes)' : 'AVISOS',
          icono: pendientes > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: color,
          destino: NotificacionesScreen(usuario: usuario),
        );
      },
    );
  }
}


// --- DASHBOARD UNIFICADO (MAESTRO Y TRABAJADOR) ---
class OperativoDashboard extends StatefulWidget {
  final UserModel usuario; 

  const OperativoDashboard({Key? key, required this.usuario}) : super(key: key);

  @override
  State<OperativoDashboard> createState() => _OperativoDashboardState();
}

class _OperativoDashboardState extends State<OperativoDashboard> {
  static const Color colorAmarillo = Color(0xFFFFDE21);
  static const Color colorCyan = Color(0xFF00E5FF);

  final List<Map<String, dynamic>> _zonasEmpresa = [
    {'nombre': 'Sauna Stilo', 'lat': 19.26240453030914, 'lon': -98.89425236731768, 'radio': 40.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26247565075755, 'lon': -98.89430986717343, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262358639389277, 'lon': -98.89418849721551, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262416139245033, 'lon': -98.89430073089898, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.2624186957255, 'lon': -98.89407106675208, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26236781757325, 'lon': -98.89404650777578, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.2622796818614, 'lon': -98.89399453997612, 'radio': 45.0}, 
    {'nombre': 'Sauna Stilo', 'lat': 19.262236850336194, 'lon': -98.89410702511668, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262222978286445, 'lon': -98.89388540759683, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26225763745606, 'lon': -98.89398305676877, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26225529052317, 'lon': -98.89396402984858, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262342839501798, 'lon': -98.89420425519347, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262421336025, 'lon': -98.89423744753003, 'radio': 35.0},
  ];

  @override
  void initState() {
    super.initState();
    _registrarAsistenciaAutomatica();
  }

  Future<void> _registrarAsistenciaAutomatica() async {
    try {
      final AsistenciaService asistenciaService = AsistenciaService();
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).get();
      
      String horaEntrada = '08:00';
      int tolerancia = 15;

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        horaEntrada = data['horaEntrada'] ?? '08:00';
        tolerancia = data['toleranciaMinutos'] ?? 15;
      }

      await asistenciaService.registrarEntradaAutomatica(
        trabajadorId: widget.usuario.id,
        zonasPermitidas: _zonasEmpresa,
        horaEntradaConfig: horaEntrada,
        toleranciaMinutos: tolerancia,
      );
    } catch (e) {
      debugPrint("Error validando entrada automática: $e");
    }
  }

  Future<void> _actualizarProgreso() async {
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool esMaestro = widget.usuario.rol == 'maestro';
    final nombre = widget.usuario.nombre.isNotEmpty ? widget.usuario.nombre : (esMaestro ? 'Maestro' : 'Trabajador'); 
    final String workerUid = widget.usuario.id;
    final ProyectoService _proyectoService = ProyectoService(); 

    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00B0FF),
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: _actualizarProgreso,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/logo_saunastilo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => const Icon(Icons.hot_tub_rounded, color: Color(0xFF00B0FF)),
                        ),
                      ),
                      StreamBuilder<List<Proyecto>>(
                        stream: _proyectoService.getProyectos(),
                        builder: (context, snapshot) {
                          int activos = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'en_proceso').length : 0;
                          int pendientes = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'pendiente').length : 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProyectosTrabajadorScreen(filtroInicial: 'en_proceso', esMaestro: esMaestro)),
                                  );
                                },
                                child: _buildDuoBadge(Icons.bolt_rounded, "$activos", colorAmarillo),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProyectosTrabajadorScreen(filtroInicial: 'pendiente', esMaestro: esMaestro)),
                                  );
                                },
                                child: _buildDuoBadge(Icons.hourglass_empty_rounded, "$pendientes", colorCyan),
                              ),
                              const SizedBox(width: 12),
                              
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ConfiguracionScreen(usuario: widget.usuario),
                                      ),
                                    );
                                  },
                                  tooltip: 'Ajustes y Perfil',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00B0FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // AVATAR CON CÁLCULO DE RACHA EN TIEMPO REAL
                            _AvatarConRachaReal(usuario: widget.usuario, size: 80),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    esMaestro ? "Panel de Maestro" : "Área de Trabajo", 
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nombre, 
                                    style: GoogleFonts.montserrat(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                          onPressed: () => AuthService().logout(),
                        ),
                      )
                    ],
                  ),
                ),
                
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('actividades')
                      .where('asignadoATrabajadorId', isEqualTo: workerUid)
                      .where('estatus', isNotEqualTo: 'completado') 
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF00B0FF))),
                      );
                    }

                    final actividades = snapshot.data?.docs ?? [];

                    if (actividades.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text(
                          "No tienes tareas pendientes. ¡Buen trabajo!",
                          style: GoogleFonts.inter(color: Colors.white54, fontStyle: FontStyle.italic),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "TUS TAREAS ASIGNADAS",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF00B0FF), letterSpacing: 1),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B0FF).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Text(
                                    "${actividades.length}",
                                    style: GoogleFonts.inter(color: const Color(0xFF00B0FF), fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 14),

                            SizedBox(
                              height: 145, 
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(), 
                                itemCount: actividades.length,
                                itemBuilder: (context, index) {
                                  final doc = actividades[index];
                                  final act = ActividadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);

                                  return _TareaTrabajadorCard(
                                    actividad: act,
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Text("Tus Herramientas", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                
        GridView.count(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05, 
                  children: [
                    const _MenuCard(
                      titulo: "INVENTARIO", 
                      icono: Icons.inventory_2_rounded, 
                      color: Color(0xFF00B0FF), 
                      destino: InventarioTrabajadorScreen() 
                    ),
                    const _MenuCard(
                      titulo: "CUMPLEAÑOS", 
                      icono: Icons.cake_rounded, 
                      color: Color(0xFFFF3399), 
                      destino: CalendarioCumpleanosScreen()
                    ),
                    _MenuCard(
                      titulo: "ASISTENCIA", 
                      icono: Icons.fingerprint_rounded, 
                      color: const Color(0xFF00E676), 
                      destino: TrabajadorAsistenciaScreen(trabajador: widget.usuario)
                    ),
                    _MenuCard(
                        titulo: "MI CAJITA", 
                        icono: Icons.home_repair_service_rounded, 
                        color: const Color(0xFFFF9800), 
                        destino: TrabajadorCajitaHerramientasScreen(trabajadorId: workerUid) 
                    ),
                    _MenuCard(
                      titulo: "PROYECTOS", 
                      icono: Icons.construction_rounded, 
                      color: const Color(0xFF00E676), 
                      destino: ProyectosTrabajadorScreen(esMaestro: esMaestro) 
                    ),
                    const _MenuCard( 
                      titulo: "MADERAS", 
                      icono: Icons.forest_rounded, 
                      color: Color(0xFF8B5CF6), 
                      destino: CatalogoSaunasTrabajadorScreen() 
                    ),
                    _MenuCard(
                      titulo: "ASISTENTE IA",
                      icono: Icons.auto_awesome_rounded,
                      color: const Color(0xFF8B5CF6),
                      destino: AsistenteIaScreen(usuario: widget.usuario),
                    ),
                    _AvisosMenuCard(usuario: widget.usuario, color: colorCyan),
                    _MenuCard(
                      titulo: "MIS INSIGNIAS",
                      icono: Icons.workspace_premium_rounded,
                      color: colorAmarillo,
                      destino: ReconocimientosScreen(usuario: widget.usuario),
                    ),
                    _MenuCard(
                      titulo: "BLOG INTERNO",
                      icono: Icons.auto_stories_rounded,
                      color: const Color(0xFFFF3399),
                      destino: BlogInternoScreen(usuario: widget.usuario),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}


class _TareaTrabajadorCard extends StatelessWidget {
  final ActividadModel actividad;

  const _TareaTrabajadorCard({
    Key? key,
    required this.actividad,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String estatus = actividad.estatus.toLowerCase();
    bool estaCompletada = estatus == 'completado' || estatus == 'finalizado';
    
    DateTime ahora = DateTime.now();
    DateTime inicio = actividad.fechaInicio; 
    DateTime limite = actividad.fechaTermino;

    double progreso = 0.0;
    Color colorEstado;
    String textoEstado;

    bool estaAtrasada = !estaCompletada && ahora.isAfter(limite);

    if (estaCompletada) {
      progreso = 1.0;
      colorEstado = const Color(0xFF00E676);
      textoEstado = "COMPLETADO";
    } else if (estaAtrasada) {
      progreso = 1.0;
      colorEstado = const Color(0xFFD32F2F);
      textoEstado = "ATRASADO";
    } else {
      int totalDuration = limite.difference(inicio).inMilliseconds;
      int elapsedDuration = ahora.difference(inicio).inMilliseconds;

      if (totalDuration > 0) {
        progreso = (elapsedDuration / totalDuration).clamp(0.05, 0.98);
      } else {
        progreso = 0.5;
      }

      if (progreso < 0.4) {
        colorEstado = const Color(0xFF00E676);
        textoEstado = "EN CURSO";
      } else if (progreso < 0.75) {
        colorEstado = const Color(0xFFFFDE21);
        textoEstado = "EN CURSO";
      } else {
        colorEstado = const Color(0xFFFF9800);
        textoEstado = "URGENTE";
      }
    }

    String fechaEntregaStr = DateFormat('dd/MM/yyyy HH:mm').format(limite);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent, 
          isScrollControlled: true, 
          builder: (context) => trabajador_view.ModalDetalleActividad(actividad: actividad),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width - 74,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorEstado.withOpacity(0.3), 
            width: 1.5
          ),
          boxShadow: [
            BoxShadow(
              color: colorEstado.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    actividad.titulo,
                    style: GoogleFonts.inter(
                      color: Colors.white, 
                      fontWeight: FontWeight.w700, 
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  textoEstado,
                  style: GoogleFonts.inter(
                    color: colorEstado, 
                    fontSize: 11, 
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('proyectos').doc(actividad.proyectoId).get(),
              builder: (context, snapshot) {
                String nombreProyecto = "Cargando proyecto...";
                if (snapshot.hasData && snapshot.data!.exists) {
                  nombreProyecto = snapshot.data!.get('titulo') ?? 'Sin proyecto';
                }
                return Text(
                  "Proyecto: $nombreProyecto",
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: progreso,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(colorEstado),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(estaAtrasada ? Icons.error_outline : Icons.calendar_today_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  estaAtrasada ? "Venció el: $fechaEntregaStr" : "Límite: $fechaEntregaStr",
                  style: GoogleFonts.inter(
                    color: estaAtrasada ? const Color(0xFFD32F2F) : Colors.white38, 
                    fontSize: 12, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// WIDGET: AVATAR CON CÁLCULO DE RACHA EN TIEMPO REAL DESDE FIRESTORE
// =====================================================================
class _AvatarConRachaReal extends StatelessWidget {
  final UserModel usuario;
  final double size;

  const _AvatarConRachaReal({
    Key? key,
    required this.usuario,
    required this.size,
  }) : super(key: key);

  int _calcularRacha(List<AsistenciaModel> asistencias) {
    if (asistencias.isEmpty) return 0;

    int racha = 0;
    DateTime? ultimoDiaProcesado;

    for (var asistencia in asistencias) {
      if (ultimoDiaProcesado != null &&
          asistencia.fecha.year == ultimoDiaProcesado.year &&
          asistencia.fecha.month == ultimoDiaProcesado.month &&
          asistencia.fecha.day == ultimoDiaProcesado.day) {
        continue;
      }

      String estatusLimpio = asistencia.estatus.trim().toLowerCase();

      if (estatusLimpio == 'a_tiempo') {
        racha++;
        ultimoDiaProcesado = asistencia.fecha;
      } else if (estatusLimpio == 'justificada') {
        ultimoDiaProcesado = asistencia.fecha;
        continue; 
      } else {
        break; 
      }
    }
    return racha;
  }

  @override
  Widget build(BuildContext context) {
    final nombre = usuario.nombre.isNotEmpty ? usuario.nombre : 'U';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('trabajadorId', isEqualTo: usuario.id)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        int rachaDias = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          List<AsistenciaModel> historial = snapshot.data!.docs
              .map((d) => AsistenciaModel.fromFirestore(d))
              .toList();
          rachaDias = _calcularRacha(historial);
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Foto de perfil
            GestureDetector(
              onTap: () {
                if (usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty) {
                  _mostrarImagenGrande(context, usuario.fotoUrl!);
                }
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                  color: Colors.white.withOpacity(0.1),
                  image: usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(usuario.fotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: usuario.fotoUrl == null || usuario.fotoUrl!.isEmpty
                    ? Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                        style: GoogleFonts.montserrat(
                          fontSize: size * 0.35, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        ),
                      )
                    : null,
              ),
            ),
            
            // 2. Badge en forma de píldora con el contador real
            Positioned(
              bottom: -8,
              child: Tooltip(
                message: 'Ver tu Racha',
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => RachaAsistenciasScreen(usuario: usuario, isAdmin: false))
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)], 
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0081CB), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withOpacity(0.5), 
                          blurRadius: 8, 
                          offset: const Offset(0, 3)
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded, 
                          color: Colors.white, 
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$rachaDias",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- PANEL DE CONTROL ALMACENISTA ---
class AlmacenistaDashboard extends StatefulWidget {
  final UserModel usuario;

  const AlmacenistaDashboard({Key? key, required this.usuario}) : super(key: key);

  @override
  State<AlmacenistaDashboard> createState() => _AlmacenistaDashboardState();
}

class _AlmacenistaDashboardState extends State<AlmacenistaDashboard> {
  static const Color colorFondo = Color(0xFF000000);
  static const Color colorNaranja = Color(0xFFFF9800);
  static const Color colorAzul = Color(0xFF00B0FF);
  static const Color colorVerde = Color(0xFF00E676);
  static const Color colorAmarillo = Color(0xFFFFDE21);
  static const Color colorRosa = Color(0xFFFF3399);
  static const Color colorMorado = Color(0xFF8B5CF6);
  static const Color colorCyan = Color(0xFF00E5FF);

  final List<Map<String, dynamic>> _zonasEmpresa = [
    {'nombre': 'Sauna Stilo', 'lat': 19.26240453030914, 'lon': -98.89425236731768, 'radio': 40.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26247565075755, 'lon': -98.89430986717343, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262358639389277, 'lon': -98.89418849721551, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262416139245033, 'lon': -98.89430073089898, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.2624186957255, 'lon': -98.89407106675208, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26236781757325, 'lon': -98.89404650777578, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.2622796818614, 'lon': -98.89399453997612, 'radio': 45.0}, 
    {'nombre': 'Sauna Stilo', 'lat': 19.262236850336194, 'lon': -98.89410702511668, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262222978286445, 'lon': -98.89388540759683, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26225763745606, 'lon': -98.89398305676877, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26225529052317, 'lon': -98.89396402984858, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262342839501798, 'lon': -98.89420425519347, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262421336025, 'lon': -98.89423744753003, 'radio': 35.0},
  ];

  @override
  void initState() {
    super.initState();
    _registrarAsistenciaAutomatica();
  }

  Future<void> _registrarAsistenciaAutomatica() async {
    try {
      final AsistenciaService asistenciaService = AsistenciaService();
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuario.id).get();
      
      String horaEntrada = '08:00';
      int tolerancia = 15;

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        horaEntrada = data['horaEntrada'] ?? '08:00';
        tolerancia = data['toleranciaMinutos'] ?? 15;
      }

      await asistenciaService.registrarEntradaAutomatica(
        trabajadorId: widget.usuario.id,
        zonasPermitidas: _zonasEmpresa,
        horaEntradaConfig: horaEntrada,
        toleranciaMinutos: tolerancia,
      );
    } catch (e) {
      debugPrint("Error validando entrada automática almacenista: $e");
    }
  }

  Future<void> _actualizarPantalla() async {
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario.nombre.isNotEmpty ? widget.usuario.nombre : 'Almacenista';
    final ProyectoService _proyectoService = ProyectoService();

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: RefreshIndicator(
          color: colorNaranja,
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: _actualizarPantalla,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/logo_saunastilo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => const Icon(Icons.hot_tub_rounded, color: colorNaranja),
                        ),
                      ),
                      StreamBuilder<List<Proyecto>>(
                        stream: _proyectoService.getProyectos(),
                        builder: (context, snapshot) {
                          int activos = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'en_proceso').length : 0;
                          int pendientes = snapshot.hasData ? snapshot.data!.where((p) => p.estatus == 'pendiente').length : 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProyectosAlmacenistaScreen(filtroInicial: 'en_proceso')));
                                },
                                child: _buildDuoBadge(Icons.bolt_rounded, "$activos", colorAmarillo),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProyectosAlmacenistaScreen(filtroInicial: 'pendiente')));
                                },
                                child: _buildDuoBadge(Icons.hourglass_empty_rounded, "$pendientes", colorCyan),
                              ),
                              const SizedBox(width: 12),
                              
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('solicitudes_herramientas')
                                    .where('estatus', isEqualTo: 'pendiente')
                                    .snapshots(),
                                builder: (context, snapshotTools) {
                                  int solicitudesPendientes = snapshotTools.hasData ? snapshotTools.data!.docs.length : 0;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.build_circle_outlined, color: colorNaranja, size: 20),
                                          onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSolicitudesHerramientasScreen()));
                                          },
                                        ),
                                      ),
                                      if (solicitudesPendientes > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                            child: Text(
                                              solicitudesPendientes > 9 ? '9+' : '$solicitudesPendientes',
                                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ConfiguracionScreen(usuario: widget.usuario)));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _AvatarConRachaReal(usuario: widget.usuario, size: 80),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Encargad@ de Almacén", 
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nombre, 
                                    style: GoogleFonts.montserrat(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                          onPressed: () => AuthService().logout(),
                        ),
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Text("Panel de Almacén", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    const _MenuCard(titulo: "INVENTARIO", icono: Icons.inventory_2_rounded, color: colorAzul, destino: InventarioAdminScreen()),
                    const _MenuCard(titulo: "CAJITAS", icono: Icons.home_repair_service_rounded, color: colorNaranja, destino: AdminCajitasScreen()),
                    const _MenuCard(titulo: "PROVEEDORES", icono: Icons.local_shipping_rounded, color: colorCyan, destino: ProveedoresScreen()),
                    const _MenuCard(titulo: "MADERAS", icono: Icons.forest_rounded, color: colorVerde, destino: CatalogoSaunasScreen()),
                    
                    const _MenuCard(titulo: "PROYECTOS", icono: Icons.construction_rounded, color: colorRosa, destino: ProyectosAlmacenistaScreen()), 
                    
                    _MenuCard(titulo: "MI ASISTENCIA", icono: Icons.fingerprint_rounded, color: colorMorado, destino: TrabajadorAsistenciaScreen(trabajador: widget.usuario)),
                    _MenuCard(titulo: "MI RACHA", icono: Icons.local_fire_department_rounded, color: const Color(0xFFFF5722), destino: RachaAsistenciasScreen(usuario: widget.usuario, isAdmin: false)),
                    const _MenuCard(titulo: "CUMPLEAÑOS", icono: Icons.cake_rounded, color: colorAmarillo, destino: CalendarioCumpleanosScreen()),
                    _MenuCard(titulo: "ASISTENTE IA", icono: Icons.auto_awesome_rounded, color: colorMorado, destino: AsistenteIaScreen(usuario: widget.usuario)),
                    _AvisosMenuCard(usuario: widget.usuario, color: colorCyan),
                    _MenuCard(titulo: "MIS INSIGNIAS", icono: Icons.workspace_premium_rounded, color: colorAmarillo, destino: ReconocimientosScreen(usuario: widget.usuario)),
                    _MenuCard(titulo: "BLOG INTERNO", icono: Icons.auto_stories_rounded, color: colorRosa, destino: BlogInternoScreen(usuario: widget.usuario)),
                  ],
                ),
                const SizedBox(height: 100), // Aumentamos el padding para asegurar que la firma no tape el último elemento
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class MjoyDreamsFooter extends StatelessWidget {
  const MjoyDreamsFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.code_rounded, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Text(
          "creado por ",
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF00B0FF), // Tu tono azul neón
              Color(0xFF8B5CF6), // Tu tono morado
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            "MJeann.devs",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
