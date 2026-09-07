import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/services/personalized_alert.dart';
import 'package:saunastilo/screens/training_access_screen.dart';
import 'package:saunastilo/screens/company_manuals_screen.dart';
import 'package:saunastilo/widgets/company_assistant_panel.dart';

class FakeCompanyService extends CompanyLearningService {
 final calls=<String>[];
 String status='none';bool fail=false;
 @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}])async{
  calls.add(action);
  if(fail)throw StateError('No se confirmó el guardado.');
  if(action=='training-request')status='request';
  if(action.startsWith('training-'))return {'languages':[{'language':'en','status':status,'eventId':'request-test','grantId':status=='approve'?'grant-test':null,'comment':''}],'history':[]};
  if(action=='manual-save')return {'id':'manual-test','status':'draft'};
  if(action=='manual-publish')return {'id':'manual-test'};
  if(action=='manual-ask')return {'text':'Según [1], el procedimiento indica utilizar un paño seco.','hasManuals':true,'sources':[{'id':'m1','title':'Manual de prueba','version':1,'section':1,'text':'Utiliza un paño seco.'}]};
  return {};
 }
}
void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 UserModel worker(String role)=>UserModel(id:'qa',nombre:'Persona de prueba',correo:'qa@example.invalid',rol:role,fechaRegistro:DateTime(2026));
 test('only admin can access knowledge administration; languages is a normal gated action',(){
  for(final role in ['admin','maestro','almacenista','trabajador']){
   final actions=AppActionCatalog.forUser(worker(role));
   expect(actions.any((a)=>a.id=='conocimiento_ia'),role=='admin');
   expect(actions.any((a)=>a.id=='idiomas'),true);expect(actions.firstWhere((a)=>a.id=='idiomas').primary,false);
   expect(actions.any((a)=>a.id=='alerta_general'),role=='admin');
  }
 });
 test('personal alerts never inherit the all-team audience and duplicate recipients are deduped',(){
  final selected=personalizedAlertPayloads(senderId:'admin',title:'Ven a oficina',message:'Revisión de proyecto',audience:'personas',users:['a','b','a']);
  expect(selected.length,2);expect(selected.map((p)=>p['destinatarioId']),['a','b']);
  for(final p in selected){expect(p['rolesDestinatarios'],isEmpty);expect(p['tipo'],'alarma_admin');expect(p['prioridad'],'critica');}
  final role=personalizedAlertPayloads(senderId:'admin',title:'Atención',message:'Almacén',audience:'rol',role:'almacenista').single;
  expect(role['destinatarioId'],'');expect(role['rolesDestinatarios'],['almacenista']);
  final all=personalizedAlertPayloads(senderId:'admin',title:'Atención',message:'Todo el equipo',audience:'todos').single;
  expect(all['destinatarioId'],'todos');
  expect(()=>personalizedAlertPayloads(senderId:'a',title:'T',message:'M',audience:'personas'),throwsArgumentError);
  expect(()=>personalizedAlertPayloads(senderId:'a',title:'T',message:'M',audience:'personas',users:['todos']),throwsArgumentError);
 });
 testWidgets('a worker requests study and cannot enter before server approval',(tester)async{
  final service=FakeCompanyService();
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:TrainingAccessScreen(user:worker('trabajador'),service:service)));
  await tester.pumpAndSettle();expect(find.text('Entrar al curso'),findsNothing);
  await tester.ensureVisible(find.text('Solicitar acceso'));await tester.pumpAndSettle();await tester.tap(find.text('Solicitar acceso'));await tester.pumpAndSettle();
  expect(service.calls,contains('training-request'));expect(find.text('Solicitud pendiente'),findsOneWidget);expect(find.text('Entrar al curso'),findsNothing);
  service.status='approve';await tester.tap(find.byTooltip('Actualizar autorización'));await tester.pumpAndSettle();
  expect(find.text('Entrar al curso'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('manual edits must be saved and re-reviewed before publication',(tester)async{
  final service=FakeCompanyService();
  tester.view.physicalSize=const Size(800,2200);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:CompanyManualEditor(service:service)));await tester.pumpAndSettle();
  final fields=find.byType(TextField);await tester.enterText(fields.at(0),'Procedimiento de prueba');await tester.enterText(fields.at(2),'Manual revisado para limpiar la rejilla con un paño seco.');
  await tester.tap(find.text('Guardar borrador'));await tester.pumpAndSettle();expect(service.calls,contains('manual-save'));
  await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();
  final publish=find.widgetWithText(OutlinedButton,'Publicar versión guardada');expect(tester.widget<OutlinedButton>(publish).onPressed,isNotNull);
  await tester.enterText(fields.at(2),'Contenido cambiado después de guardar el manual de prueba.');await tester.pump();expect(tester.widget<OutlinedButton>(publish).onPressed,isNull);
  expect(service.calls, isNot(contains('manual-publish')));expect(tester.takeException(),isNull);
 });
 testWidgets('assistant shows actual authorized excerpts and keeps question after failure',(tester)async{
  final service=FakeCompanyService();
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:CompanyAssistantPanel(service:service))));
  await tester.enterText(find.byType(TextField),'¿Cómo limpio la rejilla?');await tester.tap(find.byTooltip('Enviar pregunta'));await tester.pumpAndSettle();
  expect(service.calls,contains('manual-ask'));expect(find.text('Respuesta con manuales autorizados'),findsOneWidget);
  expect(find.text('Manual de prueba · v1'),findsOneWidget);
  service.fail=true;await tester.enterText(find.byType(TextField),'Otra pregunta');await tester.tap(find.byTooltip('Enviar pregunta'));await tester.pumpAndSettle();
  expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,'Otra pregunta');expect(tester.takeException(),isNull);
 });
 testWidgets('digital company certificate shows issuer scope and revoked state without export',(tester)async{
  tester.view.physicalSize=const Size(320,1000);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:CompanyCertificateScreen(certificate:const {'id':'qa-test-not-issued','language':'en','learnerName':'Persona de prueba','course':'Inglés introductorio','scope':'Acreditó conocimientos introductorios de vocabulario.','score':90,'actorName':'Administración de prueba','at':'2026-09-06','valid':false})));
  await tester.pumpAndSettle();expect(find.text('Revocada o sin autorización vigente'),findsOneWidget);expect(find.byIcon(Icons.share),findsNothing);expect(tester.takeException(),isNull);
 });
}
