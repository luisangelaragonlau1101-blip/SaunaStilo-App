import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';

class ModalDetalleActividad extends StatefulWidget {
  final ActividadModel actividad;

  const ModalDetalleActividad({Key? key, required this.actividad}) : super(key: key);

  @override
  State<ModalDetalleActividad> createState() => _ModalDetalleActividadState();
}

class _ModalDetalleActividadState extends State<ModalDetalleActividad> {
  late String _estatusActual;
  late TextEditingController _comentariosController;
  bool _isUploading = false;
  bool _isSaving = false;
  
  // NUEVO: Variable para controlar si estamos editando o viendo el comentario
  bool _isEditingComment = false; 

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _estatusActual = widget.actividad.estatus;
    _comentariosController = TextEditingController(text: widget.actividad.comentariosTrabajador);
    
    // Si no hay comentario previo, iniciamos en modo edición directamente
    _isEditingComment = widget.actividad.comentariosTrabajador.isEmpty;
  }

  @override
  void dispose() {
    _comentariosController.dispose();
    super.dispose();
  }

  // --- LÓGICA PARA ACTUALIZAR CAMPOS (Estatus, Comentarios, etc.) ---
  Future<void> _actualizarActividad(Map<String, dynamic> datos, {bool mostrarMensaje = true}) async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('actividades')
          .doc(widget.actividad.id)
          .update(datos);

      if (mostrarMensaje && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actualizado correctamente'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating, 
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- NUEVO: LÓGICA PARA ELIMINAR COMENTARIO ---
  Future<void> _eliminarComentario() async {
    // Actualizamos Firebase vaciando el campo
    await _actualizarActividad({'comentariosTrabajador': ''});
    
    setState(() {
      widget.actividad.comentariosTrabajador = '';
      _comentariosController.clear();
      _isEditingComment = true; // Volvemos al modo edición para que pueda escribir uno nuevo
    });
  }

  // --- LÓGICA PARA SELECCIONAR Y SUBIR FOTO ---
  Future<void> _subirEvidencia(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Comprimir un poco
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      File file = File(pickedFile.path);
      String fileName = 'evidencia_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('actividades_evidencias')
          .child(widget.actividad.id)
          .child(fileName);

      TaskSnapshot uploadTask = await storageRef.putFile(file);
      String downloadUrl = await uploadTask.ref.getDownloadURL();

      // Guardamos en Firestore usando arrayUnion
      await FirebaseFirestore.instance
          .collection('actividades')
          .doc(widget.actividad.id)
          .update({
        'evidenciaFotos': FieldValue.arrayUnion([downloadUrl])
      });

      setState(() {
        widget.actividad.evidenciaFotos.add(downloadUrl);
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia subida correctamente'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text('Tomar Foto', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _subirEvidencia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text('Elegir de la Galería', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _subirEvidencia(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool estaAtrasada = _estatusActual != 'completado' && DateTime.now().isAfter(widget.actividad.fechaTermino);
    
    // Variable global para saber si bloqueamos toda la edición
    bool estaBloqueada = _estatusActual == 'completado' || DateTime.now().isAfter(widget.actividad.fechaTermino);
    
    // Configuración visual según el estatus
    Color colorEstatus;
    String textoEstatus = _estatusActual.replaceAll('_', ' ').toUpperCase();
    if (_estatusActual == 'completado') {
      colorEstatus = Colors.tealAccent;
    } else if (estaAtrasada) {
      colorEstatus = Colors.redAccent;
      textoEstatus = 'ATRASADO';
    } else if (_estatusActual == 'en_progreso') {
      colorEstatus = Colors.cyanAccent;
    } else {
      colorEstatus = const Color(0xFFFFDE21);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        // Agregamos el padding.bottom del sistema para evitar que el botón se corte
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LÍNEA DE ARRASTRE
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // CABECERA: TÍTULO Y BADGE DE ESTATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.actividad.titulo.toUpperCase(),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorEstatus.withOpacity(0.6)),
                ),
                child: Text(
                  textoEstatus,
                  style: GoogleFonts.inter(color: colorEstatus, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // FECHA LÍMITE
          Row(
            children: [
              Icon(estaAtrasada ? Icons.notification_important : Icons.timer, color: colorEstatus, size: 16),
              const SizedBox(width: 8),
              Text(
                estaAtrasada
                    ? "Venció el: ${DateFormat('dd MMM, yyyy - HH:mm').format(widget.actividad.fechaTermino)}"
                    : "Límite: ${DateFormat('dd MMM, yyyy - HH:mm').format(widget.actividad.fechaTermino)}",
                style: GoogleFonts.inter(
                  color: colorEstatus.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: estaAtrasada ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),

          // CONTENIDO SCROLLABLE
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INSTRUCCIONES
                  Text("INSTRUCCIONES", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.actividad.descripcion,
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // NOTA DEL ADMIN (Solo si existe)
                  if (widget.actividad.observacionesAdmin.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(left: BorderSide(color: Colors.cyanAccent, width: 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("NOTA DEL ADMINISTRADOR:", style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(widget.actividad.observacionesAdmin, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- MODIFICACIÓN: COMENTARIOS DEL TRABAJADOR ---
                  Text("MI REPORTE / COMENTARIOS", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // Si hay un comentario guardado y NO estamos en modo edición, mostramos el Modo Vista
                  if (widget.actividad.comentariosTrabajador.isNotEmpty && !_isEditingComment)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.actividad.comentariosTrabajador,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4),
                            ),
                          ),
                          // Si la tarea está bloqueada, ocultamos los botones de editar/eliminar
                          if (!estaBloqueada) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingComment = true;
                                });
                              },
                              child: const Icon(Icons.edit, color: Color(0xFFFFDE21), size: 20),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _eliminarComentario,
                              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            ),
                          ]
                        ],
                      ),
                    )
                  else
                    // Modo Edición: TextField + Botones de Guardar / Cancelar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _comentariosController,
                          maxLines: 3,
                          enabled: !estaBloqueada, 
                          style: GoogleFonts.inter(color: estaBloqueada ? Colors.white54 : Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: estaBloqueada ? "Sin comentarios..." : "Escribe notas o inconvenientes aquí...",
                            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Botón de cancelar (solo aparece si ya existía un comentario antes)
                            if (widget.actividad.comentariosTrabajador.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _comentariosController.text = widget.actividad.comentariosTrabajador; // Restauramos texto original
                                    _isEditingComment = false; // Salimos de edición
                                  });
                                },
                                child: Text("Cancelar", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                              ),
                            TextButton.icon(
                              onPressed: (_isSaving || estaBloqueada || _comentariosController.text.trim().isEmpty) ? null : () async {
                                FocusScope.of(context).unfocus(); 
                                await _actualizarActividad({'comentariosTrabajador': _comentariosController.text.trim()});
                                
                                setState(() {
                                  widget.actividad.comentariosTrabajador = _comentariosController.text.trim();
                                  _isEditingComment = false; // Cambiamos a modo vista al guardar
                                });
                              },
                              icon: Icon(Icons.save, size: 16, color: estaBloqueada ? Colors.white24 : const Color(0xFFFFDE21)),
                              label: Text("Guardar Comentario", style: GoogleFonts.inter(color: estaBloqueada ? Colors.white24 : const Color(0xFFFFDE21), fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 12),

                  // EVIDENCIA FOTOGRÁFICA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("FOTOS DE EVIDENCIA (${widget.actividad.evidenciaFotos.length})", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      if (_isUploading)
                        const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Color(0xFFFFDE21), strokeWidth: 2))
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CARRUSEL HORIZONTAL DE FOTOS Y BOTÓN AGREGAR
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // BOTÓN DE AGREGAR FOTO (SOLO SE MUESTRA SI NO ESTÁ BLOQUEADA)
                        if (!estaBloqueada)
                          GestureDetector(
                            onTap: _isUploading ? null : _mostrarOpcionesImagen,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.white54, size: 30),
                                  SizedBox(height: 8),
                                  Text("Agregar", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        // MAPEO DE FOTOS SUBIDAS
                        ...widget.actividad.evidenciaFotos.map((url) {
                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator(color: Colors.white24));
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10), // Espacio extra de respiro

          // BOTÓN PRINCIPAL DE ACCIÓN (INICIAR / COMPLETAR)
          SafeArea(
            top: false,
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)))
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _estatusActual == 'pendiente' 
                            ? const Color(0xFF1E3A8A) // Azul
                            : (_estatusActual == 'en_progreso' ? const Color(0xFF0F766E) : Colors.grey[800]), // Verde o Gris
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: Colors.white12, // Color de fondo deshabilitado para UX
                      ),
                      onPressed: estaBloqueada ? null : () async {
                        if (_estatusActual == 'pendiente') {
                          await _actualizarActividad({'estatus': 'en_progreso'}, mostrarMensaje: false);
                          setState(() => _estatusActual = 'en_progreso');
                        } else if (_estatusActual == 'en_progreso') {
                          await _actualizarActividad({'estatus': 'completado'}, mostrarMensaje: false);
                          setState(() => _estatusActual = 'completado');
                          if (mounted) Navigator.pop(context); // Cierra modal si completó
                        }
                      },
                      child: Text(
                        _estatusActual == 'pendiente'
                            ? "INICIAR TAREA"
                            : (_estatusActual == 'en_progreso' ? "MARCAR COMO COMPLETADA" : (estaAtrasada ? "TIEMPO AGOTADO" : "TAREA FINALIZADA")),
                        style: GoogleFonts.inter(
                          fontSize: 15, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.1, 
                          color: estaBloqueada ? Colors.white30 : Colors.white 
                      ),
                    ),
                  ),
                ),
          )
        ],
      ),
    );
  }
}