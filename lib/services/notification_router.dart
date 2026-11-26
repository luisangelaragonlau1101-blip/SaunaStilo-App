import '../screens/calendario_cumpleanos_screen.dart';
import '../screens/installation_orders_screen.dart'
    deferred as installation_pages;
import '../screens/finance_workspace_screen.dart' deferred as finance_pages;
import '../screens/purchases_workspace_screen.dart' deferred as purchase_pages;
import '../widgets/deferred_workspace.dart';
import '../workflow/enterprise_permissions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../screens/mensajes_equipo_screen.dart';
import '../screens/proyecto_chat_screen.dart';
import '../screens/work_workspace_screen.dart';
import '../screens/daily_tasks_screen.dart';
import '../screens/admin_asistencias_screen.dart';
import 'company_learning_service.dart';
import '../screens/jornada_screen.dart';
import '../screens/prestamos_equipo_screen.dart';
import '../screens/admin_solicitudes_herramientas_screen.dart';
import '../screens/trabajador_control_herramientas_screen.dart';

class NotificationRouter {
  static Future<void> open(
    BuildContext context,
    UserModel user,
    String id,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final record = await db.collection('notificaciones').doc(id).get();
      if (!record.exists || !context.mounted) return;
      final data = record.data()!;
      final recipient = data['destinatarioId'];
      final roles = List<String>.from(data['rolesDestinatarios'] ?? const []);
      if (recipient != user.id &&
          recipient != 'todos' &&
          !roles.contains('todos') &&
          !roles.contains(user.rol))
        throw StateError('Aviso no autorizado.');
      Widget destination = MensajesEquipoScreen(usuario: user);
      final conversationId = data['conversacionId']?.toString() ?? '';
      final projectId = data['proyectoId']?.toString() ?? '';
      final orderId = (data['installationOrderId'] ?? data['orderId'] ?? '')
          .toString();
      if (data['tipo'] == 'instalacion' && orderId.isNotEmpty) {
        destination = DeferredWorkspace(
          load: installation_pages.loadLibrary,
          title: 'Instalación',
          builder: (_) => installation_pages.InstallationOrderDetailScreen(
            user: user,
            orderId: orderId,
          ),
        );
      } else if (data['tipo'] == 'cumpleanos') {
        destination = CalendarioCumpleanosScreen();
      } else if (data['pantalla'] == 'facturas') {
        if (!EnterprisePermissions.canViewFinance(user))
          throw StateError('Acceso financiero no autorizado.');
        destination = DeferredWorkspace(
          load: finance_pages.loadLibrary,
          title: 'Facturas',
          builder: (_) => finance_pages.FinanceWorkspaceScreen(
            user: user,
            initialSection: 'facturas',
          ),
        );
      } else if (data['pantalla'] == 'compras') {
        destination = DeferredWorkspace(
          load: purchase_pages.loadLibrary,
          title: 'Compras',
          builder: (_) => purchase_pages.PurchasesWorkspaceScreen(
            user: user,
            administrative: EnterprisePermissions.canApprovePurchases(user),
          ),
        );
      } else if (conversationId.isNotEmpty) {
        final conversation = await db
            .collection('conversaciones')
            .doc(conversationId)
            .get();
        final members = List<String>.from(
          conversation.data()?['participantes'] ?? const [],
        );
        if (members.length != 2 || !members.contains(user.id))
          throw StateError('Chat no autorizado.');
        final contact = await db
            .collection('usuarios')
            .doc(members.firstWhere((m) => m != user.id))
            .get();
        if (!contact.exists)
          throw StateError('La cuenta de contacto ya no existe.');
        destination = ConversacionPrivadaScreen(
          usuario: user,
          contacto: UserModel.fromFirestore(contact),
        );
      } else if (data['tipo'] == 'traspaso_herramienta') {
        destination = PrestamosEquipoScreen(usuario: user);
      } else if (data['tipo'] == 'almacen' ||
          data['tipo'] == 'solicitud_herramienta') {
        destination = [AppRoles.admin, AppRoles.almacenista].contains(user.rol)
            ? const AdminSolicitudesHerramientasScreen()
            : ControlHerramientasScreen(
                usuarioId: user.id,
                usuarioNombre: user.nombre,
              );
      } else if (data['tipo'] == 'tarea') {
        final activityId = (data['actividadId'] ?? '').toString();
        if (activityId.isEmpty) {
          destination = EquipoTareasScreen(usuario: user);
        } else {
          final result = await CompanyLearningService().call('daily-read', {
            'taskId': activityId,
          });
          destination = DailyTaskDetail(
            user: user,
            task: Map<String, dynamic>.from(result['task'] as Map),
          );
        }
      } else if (projectId.isNotEmpty) {
        final project = await db.collection('proyectos').doc(projectId).get();
        if (!project.exists) throw StateError('El proyecto ya no existe.');
        final model = Proyecto.fromFirestore(project);
        if (user.rol != AppRoles.admin && !model.encargados.contains(user.id))
          throw StateError('No perteneces a este proyecto.');
        destination = ProyectoChatScreen(proyecto: model);
      } else if ((data['tipo']?.toString() ?? '').startsWith('asistencia_')) {
        destination = user.rol == AppRoles.admin
            ? AdminAsistenciasScreen(nombreAdmin: user.nombre)
            : JornadaScreen(usuario: user);
      }
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir este aviso. Revisa tu conexión y acceso al proyecto o chat.',
            ),
          ),
        );
    }
  }
}
