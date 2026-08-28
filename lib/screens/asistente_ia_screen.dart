import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/actividad_model.dart';
import '../models/insumo_model.dart';
import '../models/user_model.dart';
import '../services/ai_assistant_service.dart';
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
  static const _acento = Color(0xFFD6A85F);
  static const _verde = Color(0xFFB9F56A);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = AiAssistantService();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final List<StreamSubscription<dynamic>> _suscripciones = [];
  final List<_MensajeAsistente> _mensajes = <_MensajeAsistente>[];

  List<ActividadModel> _actividades = <ActividadModel>[];
  List<Map<String, dynamic>> _solicitudes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _proyectos = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _clientes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cotizaciones = <Map<String, dynamic>>[];
  List<InsumoModel> _insumos = <InsumoModel>[];
  List<UserModel> _equipo = <UserModel>[];
  final List<XFile> _imagenesAdjuntas = <XFile>[];

  StreamSubscription<Uint8List>? _flujoAudio;
  BytesBuilder _audioBytes = BytesBuilder(copy: false);
  Timer? _cronometroAudio;
  int _segundosAudio = 0;
  bool _escuchando = false;
  bool _grabandoAudio = false;
  bool _subiendoAudio = false;
  bool _pensando = false;
  bool _leerRespuestas = true;
  bool? _nubeDisponible;
  String? _audioReproduciendo;

  bool get _esAdmin => widget.usuario.rol == AppRoles.admin;
  bool get _esAlmacen => widget.usuario.rol == AppRoles.almacenista;

  @override
  void initState() {
    super.initState();
    _configurarVoz();
    _escucharDatosPermitidos();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _audioReproduciendo = null);
    });
    _mensajes.add(
      _MensajeAsistente(
        texto: _esAdmin
            ? 'Hola, ${widget.usuario.nombre}. Tengo acceso administrativo a proyectos, clientes, cotizaciones, tareas y almacén. Puedes pedirme resúmenes, estadísticas, borradores o prioridades y también puedo responderte con voz.'
            : 'Hola, ${widget.usuario.nombre}. Te ayudo con tus tareas, evidencias, solicitudes y herramientas disponibles. Los datos privados de clientes, cotizaciones y proyectos administrativos permanecen protegidos para tu rol.',
        esUsuario: false,
      ),
    );
  }

  Future<void> _configurarVoz() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(.58);
    await _tts.setPitch(.98);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is List) {
        final voices = rawVoices
            .whereType<Map>()
            .map((voice) => Map<String, dynamic>.from(voice))
            .where((voice) {
              final locale = voice['locale']?.toString().toLowerCase() ?? '';
              return locale.startsWith('es');
            })
            .toList(growable: true);
        voices.sort((a, b) {
          int score(Map<String, dynamic> voice) {
            final value = '${voice['name']} ${voice['locale']}'.toLowerCase();
            var total = value.contains('es-mx') ? 6 : 0;
            if (value.contains('natural') || value.contains('neural')) total += 5;
            if (value.contains('premium') || value.contains('enhanced')) total += 4;
            return total;
          }

          return score(b).compareTo(score(a));
        });
        if (voices.isNotEmpty) {
          final selected = voices.first;
          final name = selected['name']?.toString();
          final locale = selected['locale']?.toString();
          if (name != null && locale != null) {
            await _tts.setVoice({'name': name, 'locale': locale});
          }
        }
      }
    } catch (_) {
      // Algunos navegadores no enumeran voces; conservamos es-MX del sistema.
    }
  }

  void _escucharDatosPermitidos() {
    final db = FirebaseFirestore.instance;
    final Query<Map<String, dynamic>> actividadesQuery = _esAdmin
        ? db.collection('actividades')
        : db
              .collection('actividades')
              .where('asignadoATrabajadorId', isEqualTo: widget.usuario.id);
    _suscripciones.add(
      actividadesQuery.snapshots().listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _actividades = snapshot.docs
              .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
              .toList(growable: false);
        });
      }),
    );

    final Query<Map<String, dynamic>> solicitudesQuery = (_esAdmin || _esAlmacen)
        ? db.collection('solicitudes_herramientas')
        : db
              .collection('solicitudes_herramientas')
              .where('trabajadorId', isEqualTo: widget.usuario.id);
    _suscripciones.add(
      solicitudesQuery.snapshots().listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _solicitudes = snapshot.docs
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList(growable: false);
        });
      }),
    );

    _suscripciones.add(
      db.collection('insumos_inventario').snapshots().listen((snapshot) {
        if (!mounted) return;
        final insumos = snapshot.docs
            .map((doc) => InsumoModel.fromFirestore(doc))
            .toList(growable: true)
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
        setState(() => _insumos = insumos);
      }),
    );

    _suscripciones.add(
      db.collection('usuarios').snapshots().listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _equipo = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList(growable: false);
        });
      }),
    );

    // Estas tres colecciones sensibles ni siquiera se consultan desde un
    // dispositivo que no tenga rol administrador.
    if (_esAdmin) {
      _suscripciones.add(
        db.collection('proyectos').snapshots().listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _proyectos = snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList(growable: false);
          });
        }),
      );
      _suscripciones.add(
        db.collection('clientes').snapshots().listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _clientes = snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList(growable: false);
          });
        }),
      );
      _suscripciones.add(
        db.collection('seguimiento_cotizaciones').snapshots().listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _cotizaciones = snapshot.docs
                .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
                .toList(growable: false);
          });
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _flujoAudio?.cancel();
    _cronometroAudio?.cancel();
    _speech.cancel();
    _tts.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
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
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASISTENTE SAUNA IA',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              _esAdmin ? 'Acceso administrativo verificado' : 'Acceso protegido por tu rol',
              style: GoogleFonts.inter(
                color: _esAdmin ? _verde : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _leerRespuestas ? 'Desactivar voz' : 'Activar voz',
            onPressed: () {
              setState(() => _leerRespuestas = !_leerRespuestas);
              if (!_leerRespuestas) _tts.stop();
            },
            icon: Icon(
              _leerRespuestas
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: _leerRespuestas ? _acento : Colors.white38,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _resumenOperacion(),
          _preguntasRapidas(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: _listaMensajes()),
          _entradaMensaje(),
        ],
      ),
    );
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
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _Metrica(titulo: 'PARA HOY', valor: hoy, color: _verde),
          _Metrica(
            titulo: 'PENDIENTES',
            valor: pendientes,
            color: const Color(0xFFFFD166),
          ),
          _Metrica(
            titulo: _esAdmin || _esAlmacen ? 'ALMACÉN' : 'SOLICITUDES',
            valor: solicitudes,
            color: const Color(0xFF72D6FF),
          ),
          if (_esAdmin)
            _Metrica(
              titulo: 'CLIENTES',
              valor: _clientes.length,
              color: const Color(0xFFFF8FAB),
            ),
        ],
      ),
    );
  }

  Widget _preguntasRapidas() {
    final opciones = _esAdmin
        ? const [
            'Resumen ejecutivo',
            'Proyectos y estados',
            'Clientes',
            'Cotizaciones',
            'Genera estadísticas',
            'Próximos cumpleaños',
          ]
        : _esAlmacen
        ? const [
            'Resumen de hoy',
            'Pendientes',
            'Almacén',
            'Herramientas',
            'Próximos cumpleaños',
          ]
        : const [
            '¿Qué hago hoy?',
            'Mis pendientes',
            'Herramientas',
            'Mis evidencias',
            'Mis logros',
            'Próximos cumpleaños',
          ];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          backgroundColor: _tarjeta,
          side: const BorderSide(color: Colors.white12),
          avatar: index == 0
              ? const Icon(Icons.auto_awesome_rounded, size: 16, color: _acento)
              : null,
          label: Text(
            opciones[index],
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
          onPressed: _pensando ? null : () => _enviar(opciones[index]),
        ),
      ),
    );
  }

  Widget _listaMensajes() {
    final total = _mensajes.length + (_pensando ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      itemCount: total,
      itemBuilder: (context, index) {
        if (_pensando && index == _mensajes.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: _BurbujaPensando(),
          );
        }
        final mensaje = _mensajes[index];
        return Align(
          alignment: mensaje.esUsuario
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 590),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: mensaje.esUsuario ? const Color(0xFF40372B) : _tarjeta,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mensaje.esUsuario ? 20 : 5),
                bottomRight: Radius.circular(mensaje.esUsuario ? 5 : 20),
              ),
              border: Border.all(
                color: mensaje.esUsuario
                    ? _acento.withOpacity(.35)
                    : Colors.white10,
              ),
            ),
            child: _contenidoMensaje(mensaje),
          ),
        );
      },
    );
  }

  Widget _burbujaAudio(_MensajeAsistente mensaje) {
    final reproduciendo = _audioReproduciendo == mensaje.audioUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: () => _reproducirAudio(mensaje.audioUrl!),
          icon: Icon(
            reproduciendo ? Icons.stop_rounded : Icons.play_arrow_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mensaje de audio',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _formatoDuracion(mensaje.duracionAudio ?? 0),
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(width: 16),
        const Icon(Icons.graphic_eq_rounded, color: _acento),
      ],
    );
  }

  Widget _contenidoMensaje(_MensajeAsistente mensaje) {
    if (mensaje.audioUrl != null) return _burbujaAudio(mensaje);
    final imagenes = mensaje.imagenes ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imagenes.isNotEmpty) ...[
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: imagenes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.network(
                  imagenes[index],
                  width: 170,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 170,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (mensaje.texto.isNotEmpty) const SizedBox(height: 9),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                mensaje.texto,
                style: GoogleFonts.inter(color: Colors.white, height: 1.42),
              ),
            ),
            if (!mensaje.esUsuario) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _hablar(mensaje.texto),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 17,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _entradaMensaje() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imagenesAdjuntas.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _imagenesAdjuntas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: FutureBuilder<Widget>(
                          future: _previewImagenIa(_imagenesAdjuntas[index]),
                          builder: (_, snapshot) => SizedBox(
                            width: 64,
                            height: 64,
                            child: snapshot.data ??
                                const ColoredBox(color: Colors.white10),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        top: 1,
                        child: InkWell(
                          onTap: () => setState(
                            () => _imagenesAdjuntas.removeAt(index),
                          ),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black87,
                            child: Icon(Icons.close_rounded, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_grabandoAudio || _subiendoAudio)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF291719),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _subiendoAudio
                          ? Icons.cloud_upload_rounded
                          : Icons.fiber_manual_record_rounded,
                      size: 17,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _subiendoAudio
                            ? 'Enviando audio…'
                            : 'Grabando ${_formatoDuracion(_segundosAudio)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_grabandoAudio)
                      TextButton(
                        onPressed: _detenerYEnviarAudio,
                        child: const Text('ENVIAR'),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                if (!_esAdmin)
                  _BotonEntrada(
                    tooltip: 'Solicitar herramienta',
                    icono: Icons.handyman_rounded,
                    onPressed: _abrirSolicitudHerramienta,
                  ),
                _BotonEntrada(
                  tooltip: 'Enviar fotografías a Sauna IA',
                  icono: Icons.add_photo_alternate_rounded,
                  onPressed: _pensando ? null : _seleccionarImagenesIa,
                ),
                _BotonEntrada(
                  tooltip: _escuchando ? 'Detener dictado' : 'Dictar pregunta',
                  icono: _escuchando ? Icons.mic_rounded : Icons.mic_none_rounded,
                  activo: _escuchando,
                  onPressed: _alternarDictado,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_pensando && !_grabandoAudio,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    onSubmitted: _enviar,
                    decoration: InputDecoration(
                      hintText: _escuchando
                          ? 'Te estoy escuchando…'
                          : 'Pregunta lo que necesites…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: _tarjeta,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                _BotonEntrada(
                  tooltip: _grabandoAudio ? 'Detener y enviar audio' : 'Grabar audio',
                  icono: _grabandoAudio
                      ? Icons.stop_circle_rounded
                      : Icons.graphic_eq_rounded,
                  activo: _grabandoAudio,
                  onPressed: _subiendoAudio ? null : _alternarGrabacionAudio,
                ),
                _BotonEntrada(
                  tooltip: 'Enviar',
                  icono: Icons.arrow_upward_rounded,
                  activo: true,
                  onPressed: _pensando
                      ? null
                      : () => _enviar(_controller.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagenesIa() async {
    final fotos = await ImagePicker().pickMultiImage(imageQuality: 82);
    if (fotos.isNotEmpty && mounted) {
      setState(() => _imagenesAdjuntas.addAll(fotos));
    }
  }

  Future<Widget> _previewImagenIa(XFile imagen) async {
    return Image.memory(await imagen.readAsBytes(), fit: BoxFit.cover);
  }

  Future<List<String>> _subirImagenesIa(List<XFile> imagenes) async {
    final urls = <String>[];
    final momento = DateTime.now().millisecondsSinceEpoch;
    for (var index = 0; index < imagenes.length; index++) {
      final imagen = imagenes[index];
      final nombre = imagen.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
      final ref = FirebaseStorage.instance.ref().child(
        'asistente_imagenes/${widget.usuario.id}/${momento}_${index}_${nombre.isEmpty ? 'foto.jpg' : nombre}',
      );
      await ref.putData(
        await imagen.readAsBytes(),
        SettableMetadata(
          contentType: _mimeImagen(imagen.name),
          customMetadata: {'usuarioId': widget.usuario.id},
        ),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  String _mimeImagen(String nombre) {
    final limpio = nombre.toLowerCase();
    if (limpio.endsWith('.png')) return 'image/png';
    if (limpio.endsWith('.webp')) return 'image/webp';
    if (limpio.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _alternarDictado() async {
    if (_grabandoAudio) return;
    if (_escuchando) {
      await _speech.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    await _tts.stop();
    final disponible = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _escuchando = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _escuchando = false);
      },
    );
    if (!disponible) {
      _mostrarMensaje('Activa el permiso de micrófono para dictar preguntas.');
      return;
    }
    setState(() => _escuchando = true);
    await _speech.listen(
      localeId: 'es_MX',
      listenFor: const Duration(seconds: 35),
      pauseFor: const Duration(seconds: 4),
      onResult: (resultado) {
        if (!mounted) return;
        setState(() => _controller.text = resultado.recognizedWords);
        if (resultado.finalResult && resultado.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          setState(() => _escuchando = false);
          _enviar(resultado.recognizedWords);
        }
      },
    );
  }

  Future<void> _alternarGrabacionAudio() async {
    if (_grabandoAudio) {
      await _detenerYEnviarAudio();
    } else {
      await _iniciarGrabacionAudio();
    }
  }

  Future<void> _iniciarGrabacionAudio() async {
    await _speech.stop();
    await _tts.stop();
    final permitido = await _recorder.hasPermission();
    if (!permitido) {
      _mostrarMensaje('Necesito permiso de micrófono para grabar el audio.');
      return;
    }
    try {
      _audioBytes = BytesBuilder(copy: false);
      _segundosAudio = 0;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _flujoAudio = stream.listen(_audioBytes.add);
      _cronometroAudio = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _segundosAudio++);
      });
      if (mounted) setState(() => _grabandoAudio = true);
    } catch (_) {
      _mostrarMensaje('No pude iniciar la grabación en este dispositivo.');
    }
  }

  Future<void> _detenerYEnviarAudio() async {
    if (!_grabandoAudio) return;
    setState(() {
      _grabandoAudio = false;
      _subiendoAudio = true;
    });
    _cronometroAudio?.cancel();
    await _recorder.stop();
    await _flujoAudio?.cancel();
    final pcm = _audioBytes.takeBytes();
    if (pcm.isEmpty) {
      if (mounted) setState(() => _subiendoAudio = false);
      _mostrarMensaje('El audio quedó vacío. Intenta grabarlo otra vez.');
      return;
    }
    try {
      final wav = _crearWav(pcm, sampleRate: 16000, channels: 1);
      final fecha = DateTime.now().millisecondsSinceEpoch;
      final referencia = FirebaseStorage.instance
          .ref()
          .child('audios_asistente/${widget.usuario.id}/audio_$fecha.wav');
      await referencia.putData(
        wav,
        SettableMetadata(
          contentType: 'audio/wav',
          customMetadata: <String, String>{
            'emisorId': widget.usuario.id,
            'emisorRol': widget.usuario.rol,
          },
        ),
      );
      final url = await referencia.getDownloadURL();
      final db = FirebaseFirestore.instance;
      final audioRef = db.collection('mensajes_audio').doc();
      final batch = db.batch();
      batch.set(audioRef, <String, dynamic>{
        'emisorId': widget.usuario.id,
        'emisorNombre': widget.usuario.nombre,
        'emisorRol': widget.usuario.rol,
        'audioUrl': url,
        'duracionSegundos': _segundosAudio,
        'destino': _esAdmin ? 'asistente' : 'administracion',
        'origen': 'asistente_ia',
        'creadoEn': FieldValue.serverTimestamp(),
      });
      if (!_esAdmin) {
        batch.set(
          db.collection('notificaciones').doc(),
          NotificacionesService.datosAviso(
            titulo: 'Nuevo audio de ${widget.usuario.nombre}',
            mensaje: 'Envió un mensaje de voz desde el Asistente IA.',
            tipo: 'audio',
            rolesDestinatarios: const ['admin'],
          ),
        );
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _subiendoAudio = false;
        _mensajes.add(
          _MensajeAsistente(
            texto: 'Mensaje de audio',
            esUsuario: true,
            audioUrl: url,
            duracionAudio: _segundosAudio,
          ),
        );
        _mensajes.add(
          _MensajeAsistente(
            texto: _esAdmin
                ? 'Audio guardado en la conversación.'
                : 'Audio enviado. Administración recibió el aviso en la aplicación.',
            esUsuario: false,
          ),
        );
      });
      _moverAlFinal();
    } catch (_) {
      if (mounted) setState(() => _subiendoAudio = false);
      _mostrarMensaje('No pude subir el audio. Revisa tu conexión e inténtalo otra vez.');
    }
  }

  Uint8List _crearWav(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final header = ByteData(44);
    void texto(int offset, String value) {
      final bytes = ascii.encode(value);
      for (var i = 0; i < bytes.length; i++) {
        header.setUint8(offset + i, bytes[i]);
      }
    }

    texto(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    texto(8, 'WAVE');
    texto(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    texto(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    final resultado = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm);
    return resultado.takeBytes();
  }

  Future<void> _reproducirAudio(String url) async {
    if (_audioReproduciendo == url) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _audioReproduciendo = null);
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    if (mounted) setState(() => _audioReproduciendo = url);
  }

  Future<void> _hablar(String texto) async {
    await _tts.stop();
    await _tts.speak(
      texto
          .replaceAll('•', '')
          .replaceAll(RegExp(r'\n+'), '. ')
          .replaceAll('_', ' '),
    );
  }

  Future<void> _enviar(String texto) async {
    final adjuntas = List<XFile>.from(_imagenesAdjuntas);
    final textoLimpio = texto.trim();
    if ((textoLimpio.isEmpty && adjuntas.isEmpty) || _pensando) return;
    final limpio = textoLimpio.isEmpty
        ? 'Analiza estas fotografías y dime qué observas y qué acción recomiendas.'
        : textoLimpio;
    await _speech.stop();
    setState(() {
      _escuchando = false;
      _controller.clear();
      _pensando = true;
    });
    _moverAlFinal();

    List<String> imagenesUrls = const <String>[];
    try {
      if (adjuntas.isNotEmpty) imagenesUrls = await _subirImagenesIa(adjuntas);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pensando = false);
      _mostrarMensaje(
        'No pude subir las fotografías. Revisa el permiso y la conexión.',
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _imagenesAdjuntas.clear();
      _mensajes.add(
        _MensajeAsistente(
          texto: limpio,
          esUsuario: true,
          imagenes: imagenesUrls,
        ),
      );
    });

    String? respuesta;
    if (_nubeDisponible != false) {
      try {
        respuesta = await _aiService.responder(
          pregunta: limpio,
          imagenes: imagenesUrls,
          historial: _mensajes
              .where((mensaje) => mensaje.audioUrl == null)
              .toList(growable: false)
              .reversed
              .take(10)
              .map(
                (mensaje) => <String, String>{
                  'rol': mensaje.esUsuario ? 'usuario' : 'asistente',
                  'texto': mensaje.texto,
                },
              )
              .toList(growable: false)
              .reversed
              .toList(growable: false),
        );
        if (respuesta != null) _nubeDisponible = true;
      } catch (_) {
        _nubeDisponible = false;
      }
    }
    respuesta ??= imagenesUrls.isNotEmpty
        ? 'Recibí ${imagenesUrls.length} fotografías. El análisis visual inteligente no respondió en este momento; las imágenes sí quedaron adjuntas. Intenta de nuevo o describe qué parte debo revisar.'
        : _responderLocal(limpio);
    if (!mounted) return;
    setState(() {
      _pensando = false;
      _mensajes.add(
        _MensajeAsistente(texto: respuesta!, esUsuario: false),
      );
    });
    _moverAlFinal();
    if (_leerRespuestas) await _hablar(respuesta);
  }

  String _responderLocal(String pregunta) {
    final q = pregunta.toLowerCase();
    if (q.contains('cumple')) {
      final conFecha = _equipo
          .where((persona) => persona.cumpleanos != null)
          .toList(growable: true);
      if (conFecha.isEmpty) {
        return 'Todavía no hay cumpleaños registrados en los perfiles del equipo.';
      }
      final hoy = DateTime.now();
      int diasHasta(DateTime fecha) {
        var siguiente = DateTime(hoy.year, fecha.month, fecha.day);
        if (siguiente.isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
          siguiente = DateTime(hoy.year + 1, fecha.month, fecha.day);
        }
        return siguiente.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      }

      conFecha.sort(
        (a, b) => diasHasta(a.cumpleanos!).compareTo(diasHasta(b.cumpleanos!)),
      );
      final lista = conFecha.take(8).map((persona) {
        final fecha = persona.cumpleanos!;
        final dias = diasHasta(fecha);
        return '• ${persona.nombre}: ${DateFormat('d MMMM', 'es').format(fecha)}${dias == 0 ? ' — hoy' : ' — en $dias días'}';
      }).join('\n');
      return 'Próximos cumpleaños del equipo:\n$lista';
    }
    if (!_esAdmin &&
        (q.contains('cliente') ||
            q.contains('cotiza') ||
            q.contains('proyecto'))) {
      return 'Por seguridad, tu perfil no consulta clientes, cotizaciones ni el panel administrativo de proyectos. Sí puedo decirte tus tareas asignadas, evidencias pendientes y herramientas disponibles.';
    }
    if (_esAdmin &&
        (q.contains('resumen') ||
            q.contains('estadíst') ||
            q.contains('estadist'))) {
      final activos = _proyectos
          .where((proyecto) => proyecto['estatus'] == 'en_proceso')
          .length;
      final tareasPendientes = _actividades
          .where((actividad) => actividad.estatus != 'completado')
          .length;
      final cotizacionesPendientes = _cotizaciones.where((cotizacion) {
        final estado = cotizacion['estatus_cotizacion']
            ?.toString()
            .toLowerCase();
        return estado == 'pendiente' || estado == 'en seguimiento';
      }).length;
      return 'Resumen administrativo de hoy:\n'
          '• ${_proyectos.length} proyectos registrados; $activos en proceso.\n'
          '• $tareasPendientes tareas abiertas.\n'
          '• ${_clientes.length} clientes registrados.\n'
          '• ${_cotizaciones.length} cotizaciones; $cotizacionesPendientes pendientes o en seguimiento.\n'
          '• ${_solicitudes.where((s) => s['estatus'] == 'pendiente').length} solicitudes de almacén pendientes.';
    }
    if (_esAdmin && q.contains('cliente')) {
      if (_clientes.isEmpty) return 'No hay clientes registrados.';
      final lista = _clientes.take(10).map((cliente) {
        final nombre = cliente['nombre']?.toString() ?? 'Sin nombre';
        final telefono = cliente['telefono']?.toString() ?? '';
        return '• $nombre${telefono.isEmpty ? '' : ' — $telefono'}';
      }).join('\n');
      return 'Hay ${_clientes.length} clientes registrados. Los primeros son:\n$lista';
    }
    if (_esAdmin && q.contains('cotiza')) {
      if (_cotizaciones.isEmpty) return 'No hay cotizaciones registradas.';
      final porEstado = <String, int>{};
      double total = 0;
      for (final cotizacion in _cotizaciones) {
        final estado = cotizacion['estatus_cotizacion']?.toString() ?? 'Sin estado';
        porEstado[estado] = (porEstado[estado] ?? 0) + 1;
        final monto = cotizacion['monto_cotizado'];
        if (monto is num) total += monto.toDouble();
      }
      final estados = porEstado.entries
          .map((entry) => '• ${entry.key}: ${entry.value}')
          .join('\n');
      return 'Cotizaciones: ${_cotizaciones.length}. Monto acumulado: ${NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(total)}.\n$estados';
    }
    if (_esAdmin && q.contains('proyecto')) {
      final activos = _proyectos
          .where((proyecto) => proyecto['estatus'] == 'en_proceso')
          .toList(growable: false);
      if (activos.isEmpty) return 'No aparecen proyectos activos en este momento.';
      final nombres = activos.take(8).map((proyecto) {
        return '• ${proyecto['titulo'] ?? 'Proyecto'} — en proceso';
      }).join('\n');
      return 'Hay ${activos.length} proyectos en proceso:\n$nombres';
    }
    if (q.contains('herramienta') ||
        q.contains('inventario') ||
        q.contains('disponible')) {
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
      return '$lista\n\nUsa el botón de herramienta junto al cuadro de texto para enviar la solicitud.';
    }
    if (q.contains('almac') || q.contains('solicitud')) {
      final pendientes = _solicitudes
          .where((solicitud) => solicitud['estatus'] == 'pendiente')
          .toList(growable: false);
      if (pendientes.isEmpty) return 'No hay solicitudes de almacén pendientes.';
      final detalle = pendientes.take(6).map((solicitud) {
        final nombre = solicitud['nombreInsumo']?.toString() ?? 'Artículo';
        final cantidad = solicitud['cantidad']?.toString() ?? '1';
        final trabajador = solicitud['trabajadorNombre']?.toString() ?? '';
        return '• $nombre × $cantidad${trabajador.isEmpty ? '' : ' — $trabajador'}';
      }).join('\n');
      return 'Hay ${pendientes.length} solicitudes pendientes:\n$detalle';
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
      return 'Tu registro muestra $completadas tareas completadas y $evidencias evidencias. Revisa Reconocimientos para ver tus insignias.';
    }
    if (q.contains('hoy') ||
        q.contains('qué hago') ||
        q.contains('que hago') ||
        q.contains('pendiente')) {
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
        return 'No hay tareas abiertas para hoy. Revisa el blog o confirma con tu encargado si existe una nueva asignación.';
      }
      final partes = <String>[];
      if (vencidas.isNotEmpty) {
        partes.add(
          'Prioridad alta: ${vencidas.length} tareas vencidas:\n${_listaTareas(vencidas)}',
        );
      }
      if (deHoy.isNotEmpty) {
        partes.add('Para hoy:\n${_listaTareas(deHoy)}');
      }
      return partes.join('\n\n');
    }

    final pendientes = _actividades
        .where((actividad) => actividad.estatus != 'completado')
        .toList(growable: false);
    if (_nubeDisponible == false) {
      return 'No pude conectar con el motor generativo en este momento. Con los datos disponibles sí puedo ayudarte con tareas, evidencias, almacén${_esAdmin ? ', clientes, cotizaciones, proyectos y estadísticas' : ' y herramientas'}.';
    }
    if (pendientes.isEmpty) {
      return 'No hay tareas pendientes. Pregúntame por almacén, evidencias${_esAdmin ? ', clientes, cotizaciones o proyectos' : ' o logros'}.';
    }
    return 'Hay ${pendientes.length} tareas pendientes:\n${_listaTareas(pendientes.take(6).toList())}';
  }

  Future<void> _abrirSolicitudHerramienta() async {
    final disponibles = _insumos
        .where((insumo) => insumo.cantidadDisponible > 0)
        .toList(growable: false);
    if (disponibles.isEmpty) {
      _mostrarMensaje('No hay herramientas disponibles registradas.');
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOLICITAR HERRAMIENTA',
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
                decoration: const InputDecoration(
                  labelText: 'Herramienta disponible',
                ),
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
                  if (value == null) return;
                  setModalState(() {
                    seleccionado = value;
                    if (cantidad > seleccionado.cantidadDisponible) cantidad = 1;
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Cantidad', style: GoogleFonts.inter(color: Colors.white70)),
                  const Spacer(),
                  IconButton(
                    onPressed: cantidad > 1
                        ? () => setModalState(() => cantidad--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    '$cantidad',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: _acento,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                          setModalState(() => enviando = true);
                          final db = FirebaseFirestore.instance;
                          final solicitudRef = db
                              .collection('solicitudes_herramientas')
                              .doc();
                          final avisoRef = db.collection('notificaciones').doc();
                          final batch = db.batch();
                          batch.set(solicitudRef, <String, dynamic>{
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
                          if (!mounted) return;
                          final respuesta =
                              'Solicitud enviada: $cantidad × ${seleccionado.nombre}. Administración y almacén recibieron el aviso.';
                          setState(() {
                            _mensajes.add(
                              _MensajeAsistente(
                                texto: respuesta,
                                esUsuario: false,
                              ),
                            );
                          });
                          if (_leerRespuestas) _hablar(respuesta);
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

  String _listaTareas(List<ActividadModel> tareas) {
    return tareas.take(6).map((actividad) {
      final fecha = DateFormat('dd MMM', 'es').format(actividad.fechaAsignada);
      return '• ${actividad.titulo} — $fecha';
    }).join('\n');
  }

  bool _esParaHoy(ActividadModel actividad) {
    final hoy = DateTime.now();
    final fecha = actividad.fechaAsignada;
    return hoy.year == fecha.year &&
        hoy.month == fecha.month &&
        hoy.day == fecha.day;
  }

  DateTime _inicioDeHoy() {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  String _formatoDuracion(int segundos) {
    final minutos = segundos ~/ 60;
    final resto = segundos % 60;
    return '$minutos:${resto.toString().padLeft(2, '0')}';
  }

  void _moverAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _MensajeAsistente {
  final String texto;
  final bool esUsuario;
  final String? audioUrl;
  final int? duracionAudio;
  final List<String>? imagenes;

  const _MensajeAsistente({
    required this.texto,
    required this.esUsuario,
    this.audioUrl,
    this.duracionAudio,
    this.imagenes,
  });
}

class _Metrica extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color color;

  const _Metrica({required this.titulo, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _AsistenteIaScreenState._tarjeta,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withOpacity(.3)),
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

class _BotonEntrada extends StatelessWidget {
  final String tooltip;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool activo;

  const _BotonEntrada({
    required this.tooltip,
    required this.icono,
    required this.onPressed,
    this.activo = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: activo
            ? _AsistenteIaScreenState._acento
            : const Color(0xFF242424),
        foregroundColor: activo ? Colors.black : Colors.white70,
      ),
      onPressed: onPressed,
      icon: Icon(icono, size: 21),
    );
  }
}

class _BurbujaPensando extends StatelessWidget {
  const _BurbujaPensando();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _AsistenteIaScreenState._tarjeta,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _AsistenteIaScreenState._acento,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Analizando datos…',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
