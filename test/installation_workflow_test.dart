import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/screens/installation_orders_screen.dart';
import 'package:saunastilo/services/installation_order_service.dart';

class InstallationApi extends InstallationOrderService {
  final Map<String, dynamic> order = {
    'id': 'order',
    'folio': 'INS-TEST',
    'proyectoTitulo': 'Instalación de prueba',
    'estado': 'preparacion',
    'version': 1,
    'editores': ['worker'],
    'preparadorId': 'worker',
    'preparadorNombre': 'Preparador',
    'transportistaId': 'tech',
    'transportistaNombre': 'Técnico',
    'receptorTallerId': 'admin',
    'receptorTallerNombre': 'Administración',
    'participantes': ['worker', 'tech', 'admin'],
    'lineas': [
      {
        'id': 'drill',
        'nombre': 'Taladro',
        'tipo': 'retornable',
        'cantidad': 2,
        'preparada': 0,
        'preparadaConfirmada': false,
        'estadoFisico': 'bueno',
      },
    ],
  };
  final List<Map<String, dynamic>> mutations = [];
  @override
  Future<Map<String, dynamic>> read(String id) async => {
    'order': order,
    'events': [],
  };
  @override
  Future<Map<String, dynamic>> mutate(
    String action,
    String op,
    Map<String, dynamic> data,
  ) async {
    mutations.add({'action': action, 'operationId': op, ...data});
    if (data['lineas'] != null) order['lineas'] = data['lineas'];
    return {'orderId': 'order'};
  }
}

UserModel person(String id, String role) => UserModel(
  id: id,
  nombre: id,
  correo: '$id@example.invalid',
  rol: role,
  fechaRegistro: DateTime(2026),
);
void main() {
  testWidgets(
    'preparation saves actual quantities and the expected version through the service',
    (t) async {
      final api = InstallationApi();
      await t.pumpWidget(
        MaterialApp(
          home: InstallationOrderDetailScreen(
            user: person('worker', 'trabajador'),
            orderId: 'order',
            service: api,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Taladro'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '2');
      await t.tap(find.byType(SwitchListTile));
      await t.pump();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar avance'));
      await t.tap(find.text('Guardar avance'));
      await t.pumpAndSettle();
      expect(api.mutations.single['action'], 'save-checklist');
      expect(api.mutations.single['expectedVersion'], 1);
      final saved = (api.mutations.single['lineas'] as List).single as Map;
      expect(saved['preparada'], 2);
      expect(saved['preparadaConfirmada'], isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'only the authenticated receiver sees their own departure signature',
    (t) async {
      final api = InstallationApi();
      api.order['estado'] = 'autorizada';
      api.order['salida'] = {'hash': 'frozen-version'};
      await t.pumpWidget(
        MaterialApp(
          home: InstallationOrderDetailScreen(
            user: person('tech', 'trabajador'),
            orderId: 'order',
            service: api,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Firmar recepción'), findsOneWidget);
      expect(find.text('Firmar entrega'), findsNothing);
      expect(find.text('Autorizar salida'), findsNothing);
      expect(find.text('Guardar avance'), findsNothing);
    },
  );
}
