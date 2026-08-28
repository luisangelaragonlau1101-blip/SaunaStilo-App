import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';
import '../models/insumo_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';

class AsistenteIaScreen extends StatefulWidget {
  final UserModel usuario;

  const AsistenteIaScreen({super.key, required this.usuario});

  @override
  State<AsistenteIaScreen> createState() => _AsistenteIaScreenState();
}

class _AsistenteIaScreenState extends State<AsistenteIaScreen> {
  static const _fondo = Color(0xFF050505);
  static const _tarjeta = Color(0xFF171717);
  static const _acento = Color(0xFF8B5CF6);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_MensajeAsistente> _mensajes = <_MensajeAsistente>[];
  List<ActividadModel> _actividades = <ActividadModel>[];
  List<Map<String, dynamic>> _solicitudes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _proyectos = <Map<String, dynamic>>[];
  List<InsumoModel> _insumos = <InsumoModel>[];

  bool get _esAdmin => widget.usuario.rol == AppRoles.admin;
  bool get _esAlmacen => widget.usuario.rol == AppRoles.almacenista;

  @override
  void initState() {
    super.initState();
    _mensajes.add(
      _MensajeAsistente(
        texto:
            'Hola, ${widget.usuario.nombre}. Soy tu asistente de Sauna Stilo. '
            'Puedo decirte qué debes hacer hoy, qué está vencido, qué falta por comprobar y qué solicitudes esperan atención.',
        esUsuario: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASISTENTE IA',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
            ),
            Text(
              'Datos reales de la operación',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('actividades').snapshots(),
        builder: (context, actividadesSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('solicitudes_herramientas')
                .snapshots(),
            builder: (context, solicitudesSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('proyectos')
                    .snapshots(),
                builder: (context, proyectosSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('insumos_inventario')
                        .snapshots(),
                    builder: (context, inventarioSnapshot) {
                      _sincronizarDatos(
                        actividadesSnapshot.data,
                        solicitudesSnapshot.data,
                        proyectosSnapshot.data,
                        inventarioSnapshot.data,
                      );
                      return Column(
                        children: [
                          _resumenOperacion(),
                          _preguntasRapidas(),
                          const Divider(height: 1, color: Colors.white10),
                          Expanded(child: _listaMensajes()),
                          _entradaMensaje(),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _sincronizarDatos(
    QuerySnapshot<Map<String, dynamic>>? actividades,
    QuerySnapshot<Map<String, dynamic>>? solicitudes,
    QuerySnapshot<Map<String, dynamic>>? proyectos,
    QuerySnapshot<Map<String, dynamic>>? inventario,
  ) {
    final todas = actividades?.docs
            .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
            .toList(growable: false) ??
        const <ActividadModel>[];
    _actividades = _esAdmin
        ? todas
        : todas
              .where(
                (actividad) =>
                    actividad.asignadoATrabajadorId == widget.usuario.id,
              )
              .toList(growable: false);

    final todasSolicitudes = solicitudes?.docs
            .map(
              (doc) => <String, dynamic>{'id': doc.id, ...doc.data()},
            )
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    _solicitudes = (_esAdmin || _esAlmacen)
        ? todasSolicitudes
        : todasSolicitudes
              .where(
                (solicitud) => solicitud['trabajadorId'] == widget.usuario.id,
              )
              .toList(growable: false);
    _proyectos = proyectos?.docs
            .map(
              (doc) => <String, dynamic>{'id': doc.id, ...doc.data()},
            )
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    _insumos = inventario?.docs
            .map((doc) => InsumoModel.fromFirestore(doc))
            .toList(growable: true) ??
        <InsumoModel>[];
    _insumos.sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  Widget _resumenOperacion() {
    final pendientes = _actividades
        .where((actividad) => actividad.estatus != 'completado')
        .length;
    final hoy = _actividades.where(_esParaHoy).length;
    final solicitudes = _solicitudes
        .where((solicitud) => solicitud['estatus'] == 'pendiente')
        .length;
    return SizedBox(
      height: 94,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        children: [
          _Metrica(titulo: 'PARA HOY', valor: hoy, color: const Color(0xFF00E676)),
          _Metrica(titulo: 'PENDIENTES', valor: pendientes, color: const Color(0xFFFFDE21)),
          _Metrica(
            titulo: _esAdmin || _esAlmacen ? 'ALMACÉN' : 'SOLICITUDES',
            valor: solicitudes,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _preguntasRapidas() {
    final opciones = _esAdmin || _esAlmacen
        ? const ['Resumen de hoy', 'Pendientes', 'Almacén', 'Herramientas', 'Proyectos']
        : const ['¿Qué hago hoy?', 'Mis pendientes', 'Herramientas', 'Mis evidencias', 'Mis logros'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          backgroundColor: _tarjeta,
          side: const BorderSide(color: Colors.white12),
          label: Text(
            opciones[index],
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
          onPressed: () => _enviar(opciones[index]),
        ),
      ),
    );
  }

  Widget _listaMensajes() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      itemCount: _mensajes.length,
      itemBuilder: (context, index) {
        final mensaje = _mensajes[index];
        return Align(
          alignment: mensaje.esUsuario
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: mensaje.esUsuario ? _acento : _tarjeta,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mensaje.esUsuario ? 18 : 4),
                bottomRight: Radius.circular(mensaje.esUsuario ? 4 : 18),
              ),
              border: mensaje.esUsuario
                  ? null
                  : Border.all(color: Colors.white10),
            ),
            child: Text(
              mensaje.texto,
              style: GoogleFonts.inter(color: Colors.white, height: 1.4),
            ),
          ),
        );
      },
    );
  }

  Widget _entradaMensaje() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            if (!_esAdmin) ...[
              IconButton.filledTonal(
                tooltip: 'Solicitar herramienta',
                onPressed: _abrirSolicitudHerramienta,
                icon: const Icon(Icons.handyman_rounded),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(color: Colors.white),
                onSubmitted: _enviar,
                decoration: InputDecoration(
                  hintText: 'Pregunta por tus tareas o pendientes…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _tarjeta,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _acento),
              onPressed: () => _enviar(_controller.text),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSolicitudHerramienta() async {
    final disponibles = _insumos
        .where((insumo) => insumo.cantidadDisponible > 0)
        .toList(growable: false);
    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay herramientas disponibles registradas.')),
      );
      return;
    }
    InsumoModel seleccionado = disponibles.first;
    int cantidad = 1;
    bool enviando = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOLICITAR DESDE EL ASISTENTE',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InsumoModel>(
                initialValue: seleccionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Herramienta disponible'),
                items: disponibles
                    .map(
                      (insumo) => DropdownMenuItem(
                        value: insumo,
                        child: Text(
                          '${insumo.nombre} · ${insumo.cantidadDisponible} ${insumo.unidadMedida}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() {
                      seleccionado = value;
                      if (cantidad > seleccionado.cantidadDisponible) cantidad = 1;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Cantidad', style: GoogleFonts.inter(color: Colors.white70)),
                  const Spacer(),
                  IconButton(
                    onPressed: cantidad > 1 ? () => setModalState(() => cantidad--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$cantidad', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900)),
                  IconButton(
                    onPressed: cantidad < seleccionado.cantidadDisponible
                        ? () => setModalState(() => cantidad++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _acento),
                  onPressed: enviando
                      ? null
                      : () async {
                          setModalState(() => enviando = true);
                          final db = FirebaseFirestore.instance;
                          final solicitudRef = db.collection('solicitudes_herramientas').doc();
                          final avisoRef = db.collection('notificaciones').doc();
                          final batch = db.batch();
                          batch.set(solicitudRef, {
                            'proyectoId': 'general',
                            'proyectoNombre': 'Solicitud desde Asistente IA',
                            'trabajadorId': widget.usuario.id,
                            'trabajadorNombre': widget.usuario.nombre,
                            'insumoId': seleccionado.id,
                            'nombreInsumo': seleccionado.nombre,
                            'cantidad': cantidad,
                            'esRetornable': true,
                            'estatus': 'pendiente',
                            'marcadoDevueltoTrabajador': false,
                            'devueltoConfirmadoAdmin': false,
                            'fechaSolicitud': FieldValue.serverTimestamp(),
                            'origen': 'asistente_ia',
                          });
                          batch.set(
                            avisoRef,
                            NotificacionesService.datosAviso(
                              titulo: 'Solicitud desde Asistente IA',
                              mensaje:
                                  '${widget.usuario.nombre} solicita $cantidad × ${seleccionado.nombre}',
                              tipo: 'almacen',
                              rolesDestinatarios: const ['admin', 'almacenista'],
                            ),
                          );
                          await batch.commit();
                          if (modalContext.mounted) Navigator.pop(modalContext);
                          if (mounted) {
                            setState(() {
                              _mensajes.add(
                                _MensajeAsistente(
                                  texto:
                                      'Solicitud enviada: $cantidad × ${seleccionado.nombre}. Administración y almacén ya recibieron el aviso.',
                                  esUsuario: false,
                                ),
                              );
                            });
                          }
                        },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('ENVIAR SOLICITUD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enviar(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    setState(() {
      _mensajes.add(_MensajeAsistente(texto: limpio, esUsuario: true));
      _mensajes.add(
        _MensajeAsistente(texto: _responder(limpio), esUsuario: false),
      );
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  String _responder(String pregunta) {
    final q = pregunta.toLowerCase();
    if (q.contains('herramienta') || q.contains('inventario') || q.contains('disponible')) {
      final disponibles = _insumos
          .where((insumo) => insumo.cantidadDisponible > 0)
          .toList(growable: false);
      if (disponibles.isEmpty) {
        return 'No encuentro herramientas con existencia disponible en el almacén.';
      }
      final lista = disponibles.take(12).map(
        (insumo) =>
            '• ${insumo.nombre}: ${insumo.cantidadDisponible} ${insumo.unidadMedida}',
      ).join('\n');
      return '$lista\n\nUsa el botón de herramienta junto al cuadro de texto para enviar la solicitud directamente.';
    }
    if (q.contains('almac') || q.contains('solicitud')) {
      final pendientes = _solicitudes
          .where((solicitud) => solicitud['estatus'] == 'pendiente')
          .toList(growable: false);
      if (pendientes.isEmpty) return 'No hay solicitudes de almacén pendientes.';
      final detalle = pendientes.take(5).map((solicitud) {
        final nombre = solicitud['nombreInsumo']?.toString() ?? 'Artículo';
        final cantidad = solicitud['cantidad']?.toString() ?? '1';
        final trabajador = solicitud['trabajadorNombre']?.toString() ?? '';
        return '• $nombre × $cantidad${trabajador.isEmpty ? '' : ' — $trabajador'}';
      }).join('\n');
      return 'Hay ${pendientes.length} solicitudes pendientes:\n$detalle';
    }
    if (q.contains('proyecto')) {
      final activos = _proyectos
          .where((proyecto) => proyecto['estatus'] == 'en_proceso')
          .toList(growable: false);
      if (activos.isEmpty) return 'No aparecen proyectos activos en este momento.';
      final nombres = activos
          .take(6)
          .map((proyecto) => '• ${proyecto['titulo'] ?? 'Proyecto'}')
          .join('\n');
      return 'Proyectos en proceso: ${activos.length}.\n$nombres';
    }
    if (q.contains('evidencia') || q.contains('comprobar')) {
      final sinEvidencia = _actividades
          .where(
            (actividad) =>
                actividad.estatus != 'completado' &&
                actividad.totalEvidencias == 0,
          )
          .toList(growable: false);
      if (sinEvidencia.isEmpty) {
        return 'Todas tus tareas abiertas ya cuentan con alguna evidencia.';
      }
      return 'Falta evidencia en ${sinEvidencia.length} tareas:\n${_listaTareas(sinEvidencia)}';
    }
    if (q.contains('logro') || q.contains('insignia')) {
      final completadas = _actividades
          .where((actividad) => actividad.estatus == 'completado')
          .length;
      final evidencias = _actividades.fold<int>(
        0,
        (total, actividad) => total + actividad.totalEvidencias,
      );
      return 'Tu registro actual muestra $completadas tareas completadas y $evidencias evidencias. Revisa Reconocimientos para ver las insignias desbloqueadas.';
    }
    if (q.contains('hoy') || q.contains('qué hago') || q.contains('que hago')) {
      final deHoy = _actividades
          .where(
            (actividad) =>
                _esParaHoy(actividad) && actividad.estatus != 'completado',
          )
          .toList(growable: false);
      final vencidas = _actividades
          .where(
            (actividad) =>
                actividad.estatus != 'completado' &&
                actividad.fechaTermino.isBefore(_inicioDeHoy()),
          )
          .toList(growable: false);
      if (deHoy.isEmpty && vencidas.isEmpty) {
        return 'No tienes tareas abiertas para hoy. Revisa el blog o confirma con tu encargado si hay una nueva asignación.';
      }
      final partes = <String>[];
      if (vencidas.isNotEmpty) {
        partes.add('Prioridad alta: ${vencidas.length} tareas vencidas:\n${_listaTareas(vencidas)}');
      }
      if (deHoy.isNotEmpty) {
        partes.add('Para hoy:\n${_listaTareas(deHoy)}');
      }
      return partes.join('\n\n');
    }

    final pendientes = _actividades
        .where((actividad) => actividad.estatus != 'completado')
        .toList(growable: false);
    if (pendientes.isEmpty) {
      return 'No tienes tareas pendientes. Puedes preguntarme por almacén, proyectos, evidencias o logros.';
    }
    return 'Tienes ${pendientes.length} tareas pendientes:\n${_listaTareas(pendientes.take(6).toList())}';
  }

  String _listaTareas(List<ActividadModel> tareas) {
    return tareas.take(6).map((actividad) {
      final fecha = DateFormat('dd MMM', 'es').format(actividad.fechaAsignada);
      return '• ${actividad.titulo} — $fecha';
    }).join('\n');
  }

  bool _esParaHoy(ActividadModel actividad) {
    final hoy = DateTime.now();
    final fecha = actividad.fechaAsignada;
    return hoy.year == fecha.year && hoy.month == fecha.month && hoy.day == fecha.day;
  }

  DateTime _inicioDeHoy() {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }
}

class _MensajeAsistente {
  final String texto;
  final bool esUsuario;

  const _MensajeAsistente({required this.texto, required this.esUsuario});
}

class _Metrica extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color color;

  const _Metrica({required this.titulo, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$valor',
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            titulo,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
