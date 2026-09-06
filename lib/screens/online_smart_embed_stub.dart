import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget onlineSmartEmbed(Uri uri, {ValueChanged<String>? onVoiceRequest}) => _ExternalGuide(uri: uri);

class _ExternalGuide extends StatelessWidget {
  final Uri uri;
  const _ExternalGuide({required this.uri});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: FilledButton.icon(
      icon: const Icon(Icons.open_in_browser_rounded),
      label: const Text('Abrir Online Smart'),
      onPressed: () async {
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView) && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la guía. Revisa tu conexión.')));
        }
      },
    ),
  ));
}
