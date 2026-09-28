import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import 'online_smart_screen.dart';
import '../services/ai_assistant_service.dart';
import '../services/app_action_catalog.dart';
import '../services/custom_voice_service.dart';
import '../services/local_guide.dart';

class GuiaInteligenteScreen extends StatefulWidget {
  final UserModel usuario;

  const GuiaInteligenteScreen({super.key, required this.usuario});

  @override
  State<GuiaInteligenteScreen> createState() => _GuiaInteligenteScreenState();
}

class _GuiaInteligenteScreenState extends State<GuiaInteligenteScreen> {
  static Color get _bg => StiloColors.background;
  static Color get _panel => StiloColors.surface;
  static Color get _cyan => StiloColors.accent;
  static final _mint = Color(0xFFC6FF68);
  static final _violet = Color(0xFFB82B55);

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _ai = AiAssistantService();
  final _voice = CustomVoiceService();
  final _tts = FlutterTts();
  final _player = AudioPlayer();
  final _speech = stt.SpeechToText();
  final _messages = <_GuideMessage>[];

  bool _thinking = false;
  bool _listening = false;
  bool _speak = true;
  int _speechRequest = 0;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('es-MX');
    _tts.setSpeechRate(.72);
    _messages.add(
      _GuideMessage(
        text:
            'Soy tu Guía de Sauna Stilo. Dime qué quieres hacer y te indico dónde entrar y qué tocar. Para otras preguntas abriré Online Smart dentro de la aplicación.',
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
    final actions = AppActionCatalog.forUser(widget.usuario)
        .where((action) => action.id != 'guia')
        .take(6)
        .toList(growable: false);
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
                gradient: LinearGradient(colors: [_mint, _cyan]),
              ),
              child: Icon(Icons.explore_rounded, color: StiloColors.background),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guía inteligente',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'MANUAL DE USO · SEGÚN TU ROL',
                    style: GoogleFonts.inter(
                      color: _mint,
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
            tooltip: _speak ? 'Desactivar voz' : 'Activar voz',
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
              color: _speak ? _cyan : StiloColors.text.withValues(alpha: .38),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _status(),
          TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OnlineSmartScreen(usuario: widget.usuario))), icon: Icon(Icons.auto_awesome_outlined), label: Text('Conversar con Online Smart')),
          SizedBox(height: 48, child: ListView(
            scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 14),
            children: ['¿Cómo registro mi jornada?', '¿Dónde pido una herramienta?', '¿Cómo envío un mensaje?', '¿Cómo grabo mi voz?'].map((q) => Padding(
              padding: EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: _thinking ? null : () => _ask(q)))).toList(),
          )),
          _modules(actions),
          Divider(height: 1, color: StiloColors.text.withValues(alpha: .10)),
          Expanded(child: _conversation()),
          _composer(),
        ],
      ),
    );
  }

  Widget _status() {
    return Container(
      margin: EdgeInsets.fromLTRB(14, 6, 14, 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: StiloColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mint.withOpacity(.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.language_rounded, color: _mint, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pasos de uso sin conexión al motor de IA. Para otras preguntas, abre Online Smart; tus permisos no cambian.',
              style: GoogleFonts.inter(
                color: StiloColors.text.withValues(alpha: .60),
                fontSize: 10.7,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modules(List<AppAction> actions) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: actions.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, index) {
          final action = actions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: action.builder),
            ),
            child: Container(
              width: 122,
              padding: EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: action.color.withOpacity(.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(action.icon, color: action.color, size: 19),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: StiloColors.text,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _conversation() {
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14, 14, 14, 16),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (_, index) {
        if (_thinking && index == _messages.length) {
          return _bubble(
            _GuideMessage(
              text: 'Consultando la app y la web…',
              user: false,
            ),
            loading: true,
          );
        }
        return _bubble(_messages[index]);
      },
    );
  }

  Widget _bubble(_GuideMessage message, {bool loading = false}) {
    return Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 680),
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.user ? StiloColors.surface : _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: message.user ? _mint.withOpacity(.18) : StiloColors.text.withValues(alpha: .10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.user ? Icons.person_rounded : Icons.explore_rounded,
                  color: message.user ? _cyan : _mint,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  message.user ? 'Tú' : 'Guía Sauna Stilo',
                  style: GoogleFonts.inter(
                    color: StiloColors.text.withValues(alpha: .54),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (loading) ...[
                  SizedBox(width: 8),
                  SizedBox(
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
            SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: StiloColors.text,
                      fontSize: 13.5,
                      height: 1.48,
                    ),
                  ),
                ),
                if (!message.user && !loading)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Escuchar',
                    onPressed: () => _speakText(message.text),
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: StiloColors.text.withValues(alpha: .38),
                      size: 18,
                    ),
                  ),
              ],
            ),
            if (message.sources.isNotEmpty) ...[
              SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: message.sources
                    .take(5)
                    .map(
                      (source) => ActionChip(
                        avatar: Icon(Icons.open_in_new_rounded, size: 13),
                        label: Text(
                          source.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _openSource(source.url),
                        backgroundColor: StiloColors.text.withOpacity(.04),
                        side: BorderSide(color: StiloColors.text.withValues(alpha: .12)),
                        labelStyle: GoogleFonts.inter(
                          color: StiloColors.text.withValues(alpha: .60),
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
    final suggestions = <String>[
      '¿Cómo uso esta app?',
      '¿Qué debo hacer hoy?',
      'Explícame las notificaciones',
      'Busca en Internet',
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 11),
        decoration: BoxDecoration(
          color: StiloColors.surface,
          border: Border(top: BorderSide(color: StiloColors.text.withValues(alpha: .10))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => SizedBox(width: 7),
                itemBuilder: (_, index) => ActionChip(
                  onPressed: _thinking ? null : () => _ask(suggestions[index]),
                  label: Text(suggestions[index]),
                  backgroundColor: _panel,
                  side: BorderSide(color: StiloColors.text.withValues(alpha: .10)),
                  labelStyle: GoogleFonts.inter(
                    color: StiloColors.text.withValues(alpha: .60),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: _listening ? 'Detener dictado' : 'Hablar con la guía',
                  onPressed: _thinking ? null : _toggleDictation,
                  icon: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: TextField(contextMenuBuilder: privacyTextMenu,
                    controller: _controller,
                    enabled: !_thinking,
                    onSubmitted: _ask,
                    style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Te escucho…'
                          : 'Pregunta cómo hacer algo o consulta Internet…',
                      filled: true,
                      fillColor: _panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: _thinking ? null : () => _ask(_controller.text),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask(String value) async {
    final question = value.trim();
    if (question.isEmpty || _thinking) return;
    await _speech.stop();
    setState(() {
      _listening = false;
      _thinking = true;
      _controller.clear();
      _messages.add(_GuideMessage(text: question, user: true));
    });
    _moveToEnd();
    try {
      final help = LocalGuide.answer(question, widget.usuario.rol);
      if (help != null) {
        if (!mounted) return;
        setState(() {
          _thinking = false;
          _messages.add(_GuideMessage(text: 'GUÍA DE USO · SIN CONSULTA A IA\n\n$help', user: false));
        });
        _moveToEnd();
        if (_speak) unawaited(_speakText(help));
        return;
      }
      // For questions outside the offline manual, open the working embedded guide.
      if (!mounted) return;
      setState(() => _thinking = false);
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OnlineSmartScreen(usuario: widget.usuario)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(
          _GuideMessage(
            text: error is AiAssistantException
                ? error.message
                : 'No pude conectar con la guía. Revisa Internet e intenta otra vez.',
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay dictado disponible. Revisa el permiso de micrófono o escribe tu pregunta.')));
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'es_MX',
      listenFor: Duration(seconds: 40),
      pauseFor: Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _controller.text = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          setState(() => _listening = false);
          _ask(result.recognizedWords);
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
      // El TTS del dispositivo sigue siendo el respaldo si la voz no está lista.
    }
    if (!mounted || request != _speechRequest) return;
    try { await _tts.speak(spoken); } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('La voz no pudo reproducirse. La respuesta permanece en pantalla.')));
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
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _GuideMessage {
  final String text;
  final bool user;
  final List<AiAssistantSource> sources;

  _GuideMessage({
    required this.text,
    required this.user,
    this.sources = <AiAssistantSource>[],
  });
}
