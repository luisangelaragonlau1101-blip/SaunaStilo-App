import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/screens/personal_day_screen.dart';
import 'package:saunastilo/widgets/personal_panel_control.dart';

UserModel person({String role='trabajador',bool enabled=true})=>UserModel(id:'person',nombre:'Persona de prueba',correo:'test@example.invalid',rol:role,fechaRegistro:DateTime(2026),panelPersonal:enabled);
class FakePersonalService extends CompanyLearningService{
 bool done=false,fail=false;final calls=<String>[];
 @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}])async{
  calls.add(action);
  if(action=='personal-change'){if(fail)throw StateError('No se confirmó el cambio.');done=data['done']==true;return {'saved':true};}
  if(action=='personal-upcoming')return {'items':[],'history':[],'through':'2026-10-31'};
  return {'items':[{'id':'a','date':'2026-09-07','kind':'task','title':'Preparar la mesa','details':'Revisar sillas','quantity':'','time':'13:00','done':done,'createdBy':'admin','createdByName':'Administración','lastBy':'Persona de prueba','steps':[]}],'history':[]};
 }
}
void main(){
 test('personal flag changes only a worker home and preserves required actions',(){
  for(final role in ['trabajador','admin','maestro','almacenista']){
   final p=person(role:role);expect(p.usesPersonalPanel,role=='trabajador');
   final actions=AppActionCatalog.forUser(p).map((a)=>a.id).toList();
   expect(actions,containsAll(['idiomas','ia','tareas','juegos','equipo']));
   expect(actions.contains('mi_dia'),role=='trabajador');expect(actions.contains('plan_personal'),role=='admin');expect(actions.contains('alerta_general'),role=='admin');
  }
  expect(person(enabled:false).usesPersonalPanel,false);
  expect(person(enabled:false).toFirestore().containsKey('panelPersonal'),false);
 });
 testWidgets('finishing checklists never claims an attendance exit and empty days never award completion',(t)async{
  await t.pumpWidget(MaterialApp(home:Scaffold(body:PersonalCompletionBanner(items:const []))));
  expect(find.textContaining('completados'),findsNothing);
  await t.pumpWidget(MaterialApp(home:Scaffold(body:PersonalCompletionBanner(items:const [{'done':true}]))));
  expect(find.textContaining('Pendientes del día completados'),findsOneWidget);expect(find.textContaining('confirma tu salida'),findsOneWidget);expect(find.textContaining('Terminaste tu jornada laboral'),findsNothing);
 });
 testWidgets('personal checklist confirms and strikes through the item without Firebase writes',(t)async{
  t.view.physicalSize=const Size(375,1000);t.view.devicePixelRatio=1;addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  final s=FakePersonalService();await t.pumpWidget(MaterialApp(theme:ThemeData.dark(useMaterial3:true),home:PersonalDayScreen(user:person(),service:s)));await t.pumpAndSettle();
  final check=find.byKey(const ValueKey('personal-check-a'));await t.ensureVisible(check);await t.pumpAndSettle();await t.tap(check);await t.pumpAndSettle();
  expect(s.done,true);expect(t.widget<Text>(find.text('Preparar la mesa')).style!.decoration,TextDecoration.lineThrough);expect(s.calls,contains('personal-change'));expect(t.takeException(),isNull);
 });
 testWidgets('failed checklist update never shows completed state',(t)async{
  final s=FakePersonalService()..fail=true;await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:PersonalDayScreen(user:person(),service:s)));await t.pumpAndSettle();
  final check=find.byKey(const ValueKey('personal-check-a'));await t.ensureVisible(check);await t.pumpAndSettle();await t.tap(check);await t.pumpAndSettle();expect(s.done,false);expect(find.text('No se confirmó el cambio.'),findsOneWidget);expect(t.takeException(),isNull);
 });
 testWidgets('event form keeps input on failed save and validates required title',(t)async{
  t.view.physicalSize=const Size(375,1000);t.view.devicePixelRatio=1;addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:PersonalItemForm(kind:'event',initialDate:DateTime(2026,9,7),save:(_,__)async=>throw StateError('No hay conexión.')))));await t.pumpAndSettle();
  final save=find.byKey(const ValueKey('personal-save'));await t.ensureVisible(save);await t.pumpAndSettle();await t.tap(save);await t.pumpAndSettle();expect(find.text('Escribe un nombre para la actividad.'),findsOneWidget);
  final title=find.byKey(const ValueKey('personal-title'));await t.ensureVisible(title);await t.enterText(title,'Evento del equipo');await t.ensureVisible(save);await t.pumpAndSettle();await t.tap(save);await t.pumpAndSettle();expect(find.text('No hay conexión.'),findsOneWidget);expect(t.widget<TextField>(title).controller!.text,'Evento del equipo');expect(t.takeException(),isNull);
 });
 testWidgets('non-admin has no personal profile configuration control',(t)async{
  await t.pumpWidget(MaterialApp(home:Scaffold(body:PersonalPanelControl(administrator:person(),profileId:'other',name:'Otra persona',enabled:true))));expect(find.byType(SwitchListTile),findsNothing);
 });
}
