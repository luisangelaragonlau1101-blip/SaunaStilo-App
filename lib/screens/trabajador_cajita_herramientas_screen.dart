import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cajita_herramientas_model.dart';
import '../services/cajita_herramientas_service.dart';
import 'trabajador_control_herramientas_screen.dart'; 

class TrabajadorCajitaHerramientasScreen extends StatefulWidget {
  final String trabajadorId; 

  const TrabajadorCajitaHerramientasScreen({super.key, required this.trabajadorId});

  @override
  State<TrabajadorCajitaHerramientasScreen> createState() => _TrabajadorCajitaHerramientasScreenState();
}

class _TrabajadorCajitaHerramientasScreenState extends State<TrabajadorCajitaHerramientasScreen> {
  
  // Paleta de colores cálidos (Estilo Industrial/Pro)
  static const Color colorFondo = Color(0xFF161210); 
  static const Color colorTarjeta = Color(0xFF221A16); 
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorTextoSecundario = Color(0xFFB5ABA5);
  static const Color colorAcento = Color(0xFFFFDE21); 
  static const Color colorNaranja = Color(0xFFFF9800); 
  static const Color colorRojo = Color(0xFFFF5252); 
  
  // NUEVOS COLORES PARA EL GRADIENTE (Más sobrios y elegantes)
  static const Color colorGradiente1 = Color(0xFF382A22); // Bronce oscuro sutil
  static const Color colorGradiente2 = Color(0xFF221A16); // Carbón/Marrón que se funde con la app

  @override
  Widget build(BuildContext context) {
    final cajitaProvider = Provider.of<CajitaInventarioProvider>(context);

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_repair_service, color: colorAcento, size: 24),
            const SizedBox(width: 10),
            Text(
              'MI CAJITA',
              style: GoogleFonts.outfit(
                color: colorTextoPrimario, 
                fontWeight: FontWeight.w800, 
                fontSize: 18, 
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. SECCIÓN DE TRASPASOS ENTRANTES PENDIENTES
          StreamBuilder<QuerySnapshot>(
            stream: cajitaProvider.streamTraspasosPendientes(widget.trabajadorId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              final solicitudes = snapshot.data!.docs;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.notification_important, color: colorAcento, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Préstamos Entrantes (${solicitudes.length})',
                          style: GoogleFonts.outfit(color: colorAcento, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: solicitudes.length,
                    itemBuilder: (context, index) {
                 final solicitud = solicitudes[index].data() as Map<String, dynamic>;
final idSolicitud = solicitudes[index].id;

final nombreHerramienta = solicitud['nombre_herramienta'] ?? 'Herramienta';
final origenUsuarioNombre = solicitud['origen_usuario_nombre'] ?? 'Un compañero'; 


                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorAcento.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: colorAcento.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.handshake, color: colorAcento, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
  child: Text(
    '$origenUsuarioNombre te quiere prestar:', 
    style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13),
  ),
),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nombreHerramienta.toString().toUpperCase(),
                              style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: colorRojo,
                                      elevation: 0,
                                      side: const BorderSide(color: colorRojo),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => cajitaProvider.rechazarTraspaso(idSolicitud),
                                    child: const Text('RECHAZAR'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => cajitaProvider.aceptarTraspaso(idSolicitud, widget.trabajadorId),
                                    child: const Text('ACEPTAR'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),

          // 2. BOTÓN CENTRO DE SOLICITUDES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('solicitudes_herramientas') // Verifica si aquí quieres usar traspasos_inventario también en el futuro
                  .where('trabajadorId', isEqualTo: widget.trabajadorId)
                  .where('estatus', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, badgeSnapshot) {
                int solicitudesPendientes = badgeSnapshot.hasData ? badgeSnapshot.data!.docs.length : 0;
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ControlHerramientasScreen())),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [colorGradiente1, colorGradiente2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3), 
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2), 
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Badge(
                            isLabelVisible: solicitudesPendientes > 0,
                            label: Text(
                              '$solicitudesPendientes', 
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                            ),
                            backgroundColor: colorAcento, 
                            child: const Icon(Icons.handyman, color: colorAcento, size: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Centro de Solicitudes", 
                                style: GoogleFonts.outfit(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text(
                                "Gestiona tus herramientas", 
                                style: GoogleFonts.inter(color: colorTextoSecundario, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: colorTextoSecundario, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // TÍTULO DE LISTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tus Herramientas',
                style: GoogleFonts.outfit(
                  color: colorTextoPrimario,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // 3. LISTA DE CAJITA
          Expanded(
            child: StreamBuilder<List<CajitaHerramientaModel>>(
              stream: cajitaProvider.streamCajitaUsuario(widget.trabajadorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: colorAcento));
                }
                final herramientas = snapshot.data ?? [];
                
                if (herramientas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.construction, size: 64, color: colorTextoSecundario.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('Tu cajita está vacía', style: GoogleFonts.outfit(color: colorTextoSecundario, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('No tienes herramientas asignadas aún.', style: GoogleFonts.inter(color: colorTextoSecundario.withOpacity(0.7), fontSize: 14)),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: herramientas.length,
                  itemBuilder: (context, index) {
                  final h = herramientas[index];
final enTransito = h.estado == 'en_transito';
                    
final esPrestada = h.propietarioOriginalId != null && 
                   h.propietarioOriginalId!.isNotEmpty && 
                   h.propietarioOriginalId != widget.trabajadorId;

final nombrePropietario = h.propietarioOriginalNombre ?? 'Un compañero';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(16),
                        // Destacamos con borde naranja si es prestada
                        border: Border.all(color: esPrestada ? colorNaranja.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: enTransito ? colorNaranja.withOpacity(0.2) : colorAcento.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            enTransito ? Icons.local_shipping : Icons.build,
                            color: enTransito ? colorNaranja : colorAcento,
                          ),
                        ),
                        title: Text(
                          h.nombre.toUpperCase(), 
                          style: GoogleFonts.inter(color: colorTextoPrimario, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          enTransito ? 'En espera de confirmación' : (esPrestada ? 'Herramienta prestada' : 'Disponible'),
                          style: GoogleFonts.inter(
                            color: enTransito ? colorNaranja : (esPrestada ? colorNaranja : colorTextoSecundario), 
                            fontSize: 12,
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: enTransito 
                                ? colorTarjeta 
                                : (esPrestada ? colorTarjeta : colorAcento), // Fondo transparente para Devolver
                            foregroundColor: enTransito 
                                ? colorTextoSecundario 
                                : (esPrestada ? colorNaranja : Colors.black), // Texto naranja para Devolver
                            elevation: enTransito || esPrestada ? 0 : 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: enTransito 
                                  ? BorderSide(color: colorTextoSecundario.withOpacity(0.3)) 
                                  : (esPrestada ? const BorderSide(color: colorNaranja) : BorderSide.none),
                            ),
                          ),
                          onPressed: enTransito 
                              ? null 
                              : () {
                                  if (esPrestada) {
                                    cajitaProvider.devolverHerramienta(
                                      herramientaId: h.id, 
                                      propietarioId: h.propietarioOriginalId!
                                    );
                                  } else {
                                    _mostrarModalPrestar(context, h);
                                  }
                                },
                          child: Text(
                            enTransito ? "EN ESPERA" : (esPrestada ? "DEVOLVER" : "PRESTAR"),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
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

  void _mostrarModalPrestar(BuildContext context, CajitaHerramientaModel herramienta) {
    final cajitaProvider = Provider.of<CajitaInventarioProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: colorAcento.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.people_alt, color: colorAcento),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '¿A quién le prestas\nla herramienta?',
                          style: GoogleFonts.outfit(color: colorTextoPrimario, fontWeight: FontWeight.bold, fontSize: 20, height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .where('rol', isEqualTo: 'trabajador')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('Error al cargar compañeros', style: GoogleFonts.inter(color: colorRojo)),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: colorAcento),
                        );
                      }

                      final trabajadores = snapshot.data!.docs
                          .where((doc) => doc.id != widget.trabajadorId)
                          .toList();

                      if (trabajadores.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_off, size: 48, color: colorTextoSecundario),
                              const SizedBox(height: 16),
                              Text('No hay otros trabajadores disponibles.', style: GoogleFonts.inter(color: colorTextoSecundario)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: trabajadores.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                        itemBuilder: (context, index) {
                          final userDoc = trabajadores[index];
                          final userData = userDoc.data() as Map<String, dynamic>;
                          final nombre = userData['nombre'] ?? 'Compañero';
                          
                          final avatarColors = [colorNaranja, colorAcento, colorRojo, Colors.amber, Colors.deepOrange];
                          final avatarColor = avatarColors[nombre.codeUnitAt(0) % avatarColors.length];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: avatarColor.withOpacity(0.2),
                              child: Text(
                                nombre.substring(0, 1).toUpperCase(),
                                style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              nombre,
                              style: GoogleFonts.inter(color: colorTextoPrimario, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorTarjeta,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.chevron_right, color: colorAcento, size: 20),
                            ),
                            onTap: () async {
                              Navigator.pop(context); 
                              
                              bool exito = await cajitaProvider.iniciarTraspaso(
                                herramientaId: herramienta.id,
                                origenId: widget.trabajadorId,
                                destinoId: userDoc.id,
                                nombreHerramienta: herramienta.nombre,
                              );

                              if (exito && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorNaranja,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    margin: const EdgeInsets.all(16),
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text('Traspaso enviado a $nombre', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}