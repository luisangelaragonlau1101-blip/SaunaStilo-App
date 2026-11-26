import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/startup_metrics.dart';

class WorkspaceAccess {
  final String userId;
  final UserModel? user;
  final bool cached;
  final bool active;
  const WorkspaceAccess({
    required this.userId,
    required this.user,
    required this.cached,
    required this.active,
  });
}

/// A restored Firebase session identifies the account, but cached roles alone
/// never open a private workspace. A current server response must approve it.
class AuthenticatedWorkspaceGate extends StatefulWidget {
  final String userId;
  final Stream<WorkspaceAccess> access;
  final Widget Function(BuildContext, UserModel) workspace;
  final VoidCallback onRetry;
  final VoidCallback onLogout;
  const AuthenticatedWorkspaceGate({
    super.key,
    required this.userId,
    required this.access,
    required this.workspace,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  State<AuthenticatedWorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<AuthenticatedWorkspaceGate> {
  bool _verified = false;
  UserModel? _verifiedUser;
  @override
  void didUpdateWidget(covariant AuthenticatedWorkspaceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.access != widget.access) {
      _verified = false;
      _verifiedUser = null;
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<WorkspaceAccess>(
    key: ValueKey(widget.userId),
    stream: widget.access,
    builder: (context, snapshot) {
      final access = snapshot.data;
      if (snapshot.hasError) {
        _verified = false;
        _verifiedUser = null;
        return AccessProblem(
          message: 'No pudimos validar tu acceso. Revisa la conexión.',
          onRetry: widget.onRetry,
          onLogout: widget.onLogout,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting ||
          access == null ||
          access.userId != widget.userId ||
          (access.user != null && access.user!.id != widget.userId)) {
        return const WorkspaceLoadingScreen();
      }
      if (!access.active || access.user == null) {
        _verified = false;
        _verifiedUser = null;
        if (access.cached) return const WorkspaceLoadingScreen();
        return AccessProblem(
          message: access.user == null
              ? 'No encontramos tu perfil. Administración puede revisar tu acceso.'
              : 'Tu cuenta está desactivada. Contacta a Administración.',
          onRetry: widget.onRetry,
          onLogout: widget.onLogout,
        );
      }
      if (access.cached && !_verified) return const WorkspaceLoadingScreen();
      if (!_verified) StartupMetrics.mark('profile-ready');
      _verified = true;
      if (!access.cached) _verifiedUser = access.user;
      return Column(
        children: [
          if (access.cached)
            const SafeArea(
              bottom: false,
              child: Material(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'Sincronizando · mostrando el último acceso validado',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          Expanded(child: widget.workspace(context, _verifiedUser!)),
        ],
      );
    },
  );
}

/// The useful structure appears immediately; private data waits for access.
class WorkspaceLoadingScreen extends StatelessWidget {
  final bool session;
  const WorkspaceLoadingScreen({super.key, this.session = true});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/logo_saunastilo.png',
              width: 116,
              height: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            session ? 'Tu espacio de trabajo' : 'Abriendo STILO',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            session
                ? 'Validando tu acceso y sincronizando tu jornada…'
                : 'Preparando una conexión segura…',
          ),
          if (session) ...[
            const SizedBox(height: 24),
            for (final title in ['Mi jornada', 'Mis actividades de hoy'])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Tu información aparecerá aquí.'),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class AccessProblem extends StatelessWidget {
  final String message;
  final VoidCallback onRetry, onLogout;
  const AccessProblem({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 18),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
              TextButton(
                onPressed: onLogout,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
