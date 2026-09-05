// Web-only: keep AppDeploy requests in its own origin. Never forward Firebase credentials.
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget onlineSmartEmbed(Uri uri) => _EmbeddedGuide(key: ValueKey(uri.toString()), uri: uri);

class _EmbeddedGuide extends StatefulWidget {
  final Uri uri;
  const _EmbeddedGuide({super.key, required this.uri});
  @override
  State<_EmbeddedGuide> createState() => _EmbeddedGuideState();
}

class _EmbeddedGuideState extends State<_EmbeddedGuide> {
  static int _sequence = 0;
  late final String _viewType;
  late final html.IFrameElement _frame;
  StreamSubscription<html.Event>? _load;
  @override
  void initState() {
    super.initState();
    _viewType = 'sauna-online-smart-${++_sequence}';
    _frame = html.IFrameElement()
      ..src = widget.uri.toString()
      ..title = 'Online Smart, guía de Sauna Stilo'
      ..setAttribute('allow', 'microphone; autoplay')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-popups')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }
  @override
  void dispose() {
    _load?.cancel();
    _frame.src = 'about:blank';
    _frame.remove();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
