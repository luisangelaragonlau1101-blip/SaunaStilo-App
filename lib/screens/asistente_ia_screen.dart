import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../services/ai_assistant_service.dart';
import '../services/custom_voice_service.dart';
import '../services/media_upload_service.dart';
import 'guia_inteligente_screen.dart';
import 'online_smart_screen.dart';
import 'voz_administracion_screen.dart';

class AsistenteIaLegadoScreen extends StatefulWidget {
  final UserModel usuario;

  const AsistenteIaLegadoScreen({super.key, required this.usuario});

  @override
  State<AsistenteIaLegadoScreen> createState() => _AsistenteIaLegadoScreenState();
}

class _AsistenteIaLegadoScreenState extends State<AsistenteIaLegadoScreen> {
  static const _bg = Color(0xFF05070A);
  static const _panel = Color(0xFF11161C);
  static const _cyan = Color(0xFF86E9FF);
  static const _mint = Color(0xFFA8F6D5);
  static const _violet = Color(0xFFB8A7FF);

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _ai = AiAssistantService();
  final _voice = CustomVoiceService();
  final _media = MediaUploadService();
  final _tts = FlutterTts();
  final _player = AudioPlayer();
  final _speech = stt.SpeechToText();
  final _picker = ImagePicker();
  final _messages = <_AiMessage>[];
  final _pendingImages = <XFile>[];

  bool _thinking = false;
  bool _listening = false;
  bool _speak = true;
  int _speechRequest = 0;
  bool? _online;

  bool get _admin => widget.usuario.rol == AppRoles.admin;
  bool get _warehouse => widget.usuario.rol == AppRoles.almacenista;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('es-MX');
    _tts.setSpeechRate(.72);
    _tts.setPitch(1.0);
    _messages.add(
      _AiMessage(
        text: _admin
            ? 'Hola, ${widget.usuario.nombre}. Soy Sauna IA. Puedo ayudarte con la operación autorizada de la empresa y consultar Internet cuando necesites información actual. Mis respuestas pueden reproducirse con la voz oficial configurada por Administración.'
            : 'Hola, ${widget.usuario.nombre}. Soy Sauna IA. Puedo ayudarte con tus tareas, herramientas, evidencias y dudas, respetando siempre los permisos de tu cuenta.',
        user: false,
      ),
    );
  }

  @override
  void dispose() {
    _speechRequest++;
    _controller.dispose();
    _scroll.dispose();
    _speech.cancel();
    _tts.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [_cyan, _violet]),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sauna IA',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _online == true
                        ? 'RESPUESTA IA VERIFICADA'
                        : _online == false
                            ? 'SIN CONEXIÓN · REINTENTA'
                            : 'CONEXIÓN POR VERIFICAR',
                    style: GoogleFonts.inter(
                      color: _online == false ? Colors.redAccent : _mint,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Guía de la aplicación',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuiaInteligenteScreen(usuario: widget.usuario),
              ),
            ),
            icon: const Icon(Icons.explore_rounded, color: _mint),
          ),
          if (_admin)
            IconButton(
              tooltip: 'Configurar mi voz',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      VozAdministracionScreen(usuario: widget.usuario),
                ),
              ),
              icon: const Icon(Icons.graphic_eq_rounded, color: _cyan),
            ),
          IconButton(
            tooltip: _speak
                ? 'Desactivar respuestas por voz'
                : 'Activar respuestas por voz',
            onPressed: () {
              setState(() => _speak = !_speak);
              if (!_speak) {
                _speechRequest++;
                _player.stop();
                _tts.stop();
              }
            },
            icon: Icon(
              _speak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _speak ? _cyan : Colors.white38,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _capabilityStrip(),
          _quickPrompts(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: _conversation()),
          _composer(),
        ],
      ),
    );
  }

  Widget _capabilityStrip() {
    final label = _admin
        ? 'Proyectos · Clientes · Cotizaciones · Almacén · Web'
        : _warehouse
            ? 'Inventario · Solicitudes · Tareas · Web'
            : 'Tus tareas · Herramientas · Evidencias · Web';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0D171C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyan.withOpacity(.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.language_rounded, color: _cyan, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPrompts() {
    final prompts = _admin
        ? <String>[
            'Resumen ejecutivo',
            '¿Qué urge hoy?',
            'Proyectos y estados',
            'Cotizaciones',
            'Busca en Internet',
          ]
        : _warehouse
            ? <String>[
                '¿Qué falta hoy?',
                'Herramientas',
                'Inventario',
                'Mis pendientes',
                'Busca en Internet',
              ]
            : <String>[
                '¿Qué hago hoy?',
                'Mis pendientes',
                'Herramientas',
                'Mis evidencias',
                'Busca en Internet',
              ];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) => ActionChip(
          onPressed: _thinking ? null : () => _send(prompts[index]),
          label: Text(prompts[index]),
          backgroundColor: _panel,
          side: const BorderSide(color: Colors.white10),
          labelStyle: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _conversation() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (_, index) {
        if (_thinking && index == _messages.length) {
          return _bubble(
            const _AiMessage(
              text: 'Analizando y consultando…',
              user: false,
            ),
            loading: true,
          );
        }
        return _bubble(_messages[index]);
      },
    );
  }

  Widget _bubble(_AiMessage message, {bool loading = false}) {
    return Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.user ? const Color(0xFF16303A) : _panel,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: message.user ? _cyan.withOpacity(.18) : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.user
                      ? Icons.person_rounded
                      : Icons.auto_awesome_rounded,
                  size: 15,
                  color: message.user ? _cyan : _mint,
                ),
                const SizedBox(width: 6),
                Text(
                  message.user ? 'Tú' : 'Sauna IA',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (loading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: _mint,
                    ),
                  ),
                ],
              ],
            ),
            if (message.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 9),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, imageIndex) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      message.imageUrls[imageIndex],
                      width: 128,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.48,
                    ),
                  ),
                ),
                if (!message.user && !loading)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Escuchar respuesta',
                    onPressed: () => _speakText(message.text),
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
              ],
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: message.sources
                    .take(5)
                    .map(
                      (source) => ActionChip(
                        avatar: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: Text(
                          source.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _openSource(source.url),
                        backgroundColor: Colors.white.withOpacity(.04),
                        side: const BorderSide(color: Colors.white12),
                        labelStyle: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 9.5,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 11),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0D11),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImages.isNotEmpty)
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 7),
                  itemCount: _pendingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<Widget>(
                          future: _preview(_pendingImages[index]),
                          builder: (_, snapshot) => SizedBox(
                            width: 62,
                            height: 62,
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
                            () => _pendingImages.removeAt(index),
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
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Agregar fotografías',
                  onPressed: _thinking ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                ),
                const SizedBox(width: 5),
                IconButton.filledTonal(
                  tooltip: _listening ? 'Detener dictado' : 'Hablar',
                  onPressed: _thinking ? null : _toggleDictation,
                  icon: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_thinking,
                    onSubmitted: _send,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Te escucho…'
                          : 'Pregunta, analiza o busca en Internet…',
                      filled: true,
                      fillColor: _panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: _thinking ? null : () => _send(_controller.text),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 82);
    if (images.isNotEmpty && mounted) {
      setState(() => _pendingImages.addAll(images.take(4 - _pendingImages.length)));
    }
  }

  Future<Widget> _preview(XFile image) async {
    return Image.memory(await image.readAsBytes(), fit: BoxFit.cover);
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final urls = <String>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final file = await _media.upload(
        bytes: await image.readAsBytes(),
        fileName: image.name.isEmpty ? 'foto_$index.jpg' : image.name,
        contentType: _mime(image.name),
        folder: 'asistente_imagenes',
      );
      urls.add(file.url);
    }
    return urls;
  }

  String _mime(String name) {
    final value = name.toLowerCase();
    if (value.endsWith('.png')) return 'image/png';
    if (value.endsWith('.webp')) return 'image/webp';
    if (value.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _send(String value) async {
    final question = value.trim();
    if (question.length > 2500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La pregunta admite hasta 2500 caracteres.')));
      return;
    }
    if (_thinking || (question.isEmpty && _pendingImages.isEmpty)) return;
    await _speech.stop();
    final images = List<XFile>.from(_pendingImages);
    setState(() {
      _thinking = true;
      _listening = false;
      _controller.clear();
      _pendingImages.clear();
    });
    try {
      final uploaded =
          images.isEmpty ? <String>[] : await _uploadImages(images);
      final prompt = question.isEmpty
          ? 'Analiza estas fotografías y dime qué observas de forma útil para mi trabajo.'
          : question;
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiMessage(text: prompt, user: true, imageUrls: uploaded),
        );
      });
      _moveToEnd();
      final response = await _ai.responderAvanzado(
        pregunta: prompt,
        historial: _history(),
        imagenes: uploaded,
        usarInternet: true,
        modo: 'asistente',
      );
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _online = true;
        _messages.add(
          _AiMessage(
            text: response.respuesta,
            user: false,
            sources: response.fuentes,
          ),
        );
      });
      _moveToEnd();
      if (_speak) unawaited(_speakText(response.respuesta));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _online = false;
        _controller.text = question;
        if (_pendingImages.isEmpty) _pendingImages.addAll(images);
        _messages.add(
          _AiMessage(
            text: error is AiAssistantException
                ? error.message
                : 'No pude conectar con Sauna IA. Revisa la conexión e intenta de nuevo.',
            user: false,
          ),
        );
      });
      _moveToEnd();
    }
  }

  List<Map<String, String>> _history() {
    return _messages.reversed
        .take(10)
        .toList()
        .reversed
        .map(
          (message) => <String, String>{
            'rol': message.user ? 'usuario' : 'asistente',
            'texto': message.text,
          },
        )
        .toList(growable: false);
  }

  Future<void> _toggleDictation() async {
    _speechRequest++;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _player.stop();
    await _tts.stop();
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay dictado disponible. Revisa el permiso de micrófono o escribe tu pregunta.')));
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'es_MX',
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _controller.text = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          setState(() => _listening = false);
          _send(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _speakText(String text) async {
    final request = ++_speechRequest;
    final clean = text
        .replaceAll(RegExp(r'https?://\S+'), 'enlace')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    final spoken = clean.length > 900
        ? '${clean.substring(0, 900)}. El resto está disponible en pantalla.'
        : clean;
    await _player.stop();
    await _tts.stop();
    try {
      final audio = await _voice.synthesize(spoken);
      if (!mounted || request != _speechRequest) return;
      if (audio != null) {
        await _player.play(BytesSource(audio.bytes, mimeType: audio.mimeType));
        return;
      }
    } catch (_) {
      // La voz del dispositivo permanece como respaldo si la personalizada falla.
    }
    if (!mounted || request != _speechRequest) return;
    try { await _tts.speak(spoken); } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La voz no pudo reproducirse. La respuesta permanece en pantalla.')));
    }
  }

  Future<void> _openSource(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _moveToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _AiMessage {
  final String text;
  final bool user;
  final List<AiAssistantSource> sources;
  final List<String> imageUrls;

  const _AiMessage({
    required this.text,
    required this.user,
    this.sources = const <AiAssistantSource>[],
    this.imageUrls = const <String>[],
  });
}

// Retain the legacy implementation for internal data tools; the public entry uses Online Smart.
class AsistenteIaScreen extends StatelessWidget {
  final UserModel usuario;
  const AsistenteIaScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) => OnlineSmartScreen(usuario: usuario);
}
