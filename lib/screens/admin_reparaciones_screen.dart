import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/insumo_model.dart'; 

class AdminReparacionesScreen extends StatefulWidget {
  const AdminReparacionesScreen({super.key});

  @override
  State<AdminReparacionesScreen> createState() => _AdminReparacionesScreenState();
}

class _AdminReparacionesScreenState extends State<AdminReparacionesScreen> {
  static const Color colorFondo = Color(0xFF000000);
  static const Color colorTarjeta = Color(0xFF111012);
  static const Color colorTextoPrimario = Color(0xFFFDFDFD);
  static const Color colorAcento = Color(0xFFB7FF2A);
  static const Color colorAzul = Color(0xFFC798FF);
  static const Color colorRojoCoral = Color(0xFFFF5252);
  static const Color colorMorado = Color(0xFFC13CFF);
  static const Color colorRosaVibrante = Color(0xFFFF729C);
  static const Color colorBlanco = Color(0xFFFFFFFF);
  static const Color colorVerde1 = Color(0xFF7CE3BD);

  Color _obtenerColorBarra(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'material':
      case 'materiales':
        return colorRosaVibrante;
      case 'herramienta':
      case 'herramientas':
        return colorRojoCoral;
      case 'máquinas':
      case 'maquinas':
        return colorMorado;
      case 'accesorios':
      case 'accesorio':
        return colorAcento;
      case 'ferretería':
        return colorVerde1;
      case 'eléctrico':
        return colorAzul;
      default:
        return colorBlanco;
    }
  }

  void _mostrarImagenExpandida(BuildContext context, String imageUrl, String heroTag) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: heroTag,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: colorRosaVibrante)),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

Future<void> _marcarComoReparado(BuildContext context, String insumoId) async {
    try {
      // 1. Buscamos el reporte activo en el taller para este insumo
      final reparacionesActivas = await FirebaseFirestore.instance
          .collection('reparaciones_taller')
          .where('insumoId', isEqualTo: insumoId)
          .where('estatus', isEqualTo: 'en_reparacion')
          .limit(1)
          .get();

      if (reparacionesActivas.docs.isEmpty) {
        throw Exception("No se encontró el reporte activo en el taller.");
      }

      // Obtenemos exactamente cuántas herramientas de este insumo estaban en este reporte
      final reparacionDoc = reparacionesActivas.docs.first;
      final int cantidadReparada = int.tryParse(reparacionDoc.data()['cantidad']?.toString() ?? '1') ?? 1;

      final inventarioRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);
      
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 2. Actualizamos el inventario principal (A prueba de errores de sincronización)
      batch.set(inventarioRef, {
        'en_reparacion': FieldValue.increment(-cantidadReparada),
        'cantidad_disponible': FieldValue.increment(cantidadReparada),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Cerramos el reporte en el taller
      batch.update(reparacionDoc.reference, {
        'estatus': 'reparado',
        'fechaReparacion': FieldValue.serverTimestamp(),
      });


      // Buscar si esta reparación viene de un reporte de daño en un kit de salida
      final dataReparacion = reparacionDoc.data() as Map<String, dynamic>;
      if (dataReparacion['origen'] == 'recepcion_obra_evaluada') {
         // Necesitaríamos saber el ID del kit (solicitudId) para actualizarlo directamente. 
         // O, una forma más robusta:
         final salidasConEsteInsumo = await FirebaseFirestore.instance
            .collection('solicitudes_salida')
            .where('proyectoId', isEqualTo: dataReparacion['proyectoId'])
            .get();

         for (var docSalida in salidasConEsteInsumo.docs) {
            Map<String, dynamic> datos = docSalida.data();
            List reportes = datos['reportes_danos'] ?? [];
            bool actualizado = false;

            for (int i = 0; i < reportes.length; i++) {
               if (reportes[i]['insumoId'] == insumoId && reportes[i]['estatusEvaluacion'] == 'taller') {
                  reportes[i]['estatusReparacionInterno'] = 'reparado';
                  actualizado = true;
               }
            }

            if (actualizado) {
               batch.update(docSalida.reference, {'reportes_danos': reportes});
            }
         }
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: colorVerde1,
            content: Text("Herramienta reparada con éxito. Regresó al stock disponible."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: colorRojoCoral, content: Text("Error al procesar: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextoPrimario),
        title: Text(
          'TALLER Y REPARACIONES',
          style: GoogleFonts.inter(
            color: colorTextoPrimario,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('insumos_inventario')
            .where('en_reparacion', isGreaterThan: 0)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: colorTextoPrimario));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.handyman_outlined, color: Colors.white24, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'No hay herramientas dañadas en mantenimiento.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final insumo = InsumoModel.fromFirestore(doc);
              
              // Extracción local del campo dinámico
              final dataRaw = doc.data() as Map<String, dynamic>;
              final int enReparacion = dataRaw['en_reparacion'] ?? 0;

              final String heroTag = 'reparar_${insumo.id}';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorTarjeta,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.2), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Barra de color lateral por categoría
                      Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: _obtenerColorBarra(insumo.categoria),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),

                      // Imagen del insumo
                      if (insumo.imagenUrl != null && insumo.imagenUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                          child: GestureDetector(
                            onTap: () => _mostrarImagenExpandida(context, insumo.imagenUrl!, heroTag),
                            child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: insumo.imagenUrl!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.white10,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorRosaVibrante)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.white10,
                                    child: const Icon(Icons.broken_image, color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.build_circle_outlined, color: Colors.white54, size: 30),
                          ),
                        ),

                      // Detalles del insumo y acciones
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                insumo.nombre.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: colorTextoPrimario,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${insumo.categoria.toUpperCase()} > ${insumo.subcategoria.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  color: colorTextoPrimario.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'DAÑADAS: $enReparacion ${insumo.unidadMedida}',
                                      style: GoogleFonts.inter(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                          ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorVerde1,
                                      foregroundColor: colorFondo,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    // --- AQUÍ ESTÁ EL CAMBIO ---
                                    onPressed: () => _marcarComoReparado(context, insumo.id),
                                    // ---------------------------
                                    icon: const Icon(Icons.build, size: 14),
                                    label: Text(
                                      "REPARADA",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}