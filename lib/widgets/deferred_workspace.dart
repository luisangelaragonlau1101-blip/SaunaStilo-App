import 'package:flutter/material.dart';

/// Loads an optional module only when its route is opened.
class DeferredWorkspace extends StatefulWidget {
  final Future<void> Function() load;
  final WidgetBuilder builder;
  final String title;
  const DeferredWorkspace({
    super.key,
    required this.load,
    required this.builder,
    this.title = 'Abriendo sección',
  });
  @override
  State<DeferredWorkspace> createState() => _DeferredWorkspaceState();
}

class _DeferredWorkspaceState extends State<DeferredWorkspace> {
  late Future<void> _loading = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.builder(context);
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No pudimos descargar esta sección. Revisa la conexión.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() { _loading = widget.load(); }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                )
              : const LinearProgressIndicator(),
        ),
      );
    },
  );
}
