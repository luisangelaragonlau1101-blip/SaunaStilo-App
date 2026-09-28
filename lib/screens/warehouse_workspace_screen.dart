import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'inventario_admin_screen.dart';
import 'inventario_trabajador_screen.dart';
import 'admin_solicitudes_herramientas_screen.dart';
import 'trabajador_control_herramientas_screen.dart';
import 'prestamos_equipo_screen.dart';
import 'admin_cajitas_screen.dart';
import 'trabajador_cajita_herramientas_screen.dart';

class WarehouseWorkspaceScreen extends StatelessWidget {
  final UserModel user;
  const WarehouseWorkspaceScreen({super.key, required this.user});
  @override Widget build(BuildContext context) {
    final manager = user.rol == AppRoles.admin || user.rol == AppRoles.almacenista;
    void open(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(appBar: AppBar(title: const Text('Almacén')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(manager ? 'Todo el almacén, en un lugar.' : 'Lo que necesitas para trabajar.', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10), const Text('Productos, fotografías, solicitudes y herramientas. Cada movimiento conserva su seguimiento.'), const SizedBox(height: 20),
      _option(context, Icons.inventory_2_outlined, 'Productos y existencias', manager ? 'Registrar productos, fotos y entradas' : 'Consultar productos disponibles', () => open(manager ? const InventarioAdminScreen() : const InventarioTrabajadorScreen())),
      _option(context, Icons.outbox_outlined, 'Mis solicitudes', 'Solicitar herramienta y revisar su devolución', () => open(ControlHerramientasScreen(usuarioId: user.id, usuarioNombre: user.nombre))),
      if (manager) _option(context, Icons.rule_folder_outlined, 'Entregas y devoluciones', 'Autorizar salidas, recibir y consultar movimientos', () => open(const AdminSolicitudesHerramientasScreen())),
      _option(context, Icons.handyman_outlined, 'Préstamos entre compañeros', 'Prestar, recibir o devolver con confirmación', () => open(PrestamosEquipoScreen(usuario: user))),
      _option(context, Icons.home_repair_service_outlined, manager ? 'Cajitas del equipo' : 'Mi cajita', 'Herramientas asignadas y su estado', () => open(manager ? const AdminCajitasScreen() : TrabajadorCajitaHerramientasScreen(trabajadorId: user.id))),
    ]));
  }
  Widget _option(BuildContext context, IconData icon, String title, String subtitle, VoidCallback action) => Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: action));
}
