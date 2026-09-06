import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/recorded_streak.dart';
import 'package:saunastilo/services/team_games.dart';
import 'package:saunastilo/screens/team_games_screen.dart';
import 'package:saunastilo/widgets/shared_media_card.dart';
import 'package:saunastilo/services/offline_workspace.dart';
void main(){
 UserModel user(String role)=>UserModel(id:'test',nombre:'Prueba',correo:'test@example.invalid',rol:role,fechaRegistro:DateTime(2026));
 test('warehouse approval is a direct role-filtered action, games and notebook do not remove alerts',(){
  for(final role in ['admin','almacenista','maestro','trabajador']){final ids=AppActionCatalog.forUser(user(role)).map((a)=>a.id).toList();expect(ids,containsAll(['juegos','sin_conexion','solicitudes_almacen','tareas','prestamos']));expect(ids.contains('almacen_movimientos'),['admin','almacenista'].contains(role));expect(ids.contains('alerta_general'),role=='admin');expect(ids.toSet().length,ids.length);}
 });
 test('recorded streak explains neutral justification and missed-day reset',(){
  final s=RecordedStreak.from([AttendancePoint(DateTime(2026,9,1),'a_tiempo'),AttendancePoint(DateTime(2026,9,2),'justificada'),AttendancePoint(DateTime(2026,9,3),'a_tiempo'),AttendancePoint(DateTime(2026,9,4),'falta'),AttendancePoint(DateTime(2026,9,5),'a_tiempo')]);expect(s.current,1);expect(s.best,2);expect(s.total,5);expect(s.nextMilestone,7);
 });
 test('a game only places a single mark in a free cell; wins and ties finish it',(){
  final b=placeMark(List.filled(9,''),0,'X');expect(b[0],'X');expect(()=>placeMark(b,0,'O'),throwsStateError);expect(boardResult(['X','X','X','','','','','','']),'X');expect(boardResult(['X','O','X','X','O','O','O','X','X']),'empate');
 });
 test('reels and Spotify are external allowed links, not executable links',(){
  expect(sharedMediaUrl('https://open.spotify.com/track/test'),isNotNull);expect(sharedMediaUrl('Mira https://www.instagram.com/reel/example/'),isNotNull);expect(sharedMediaUrl('https://instagram.com.attacker.test/reel/a'),isNull);expect(sharedMediaUrl('javascript:alert(1)'),isNull);
 });
 testWidgets('local game works at phone width without a Firebase account or Internet',(tester)async{
  tester.view.physicalSize=const Size(375,812);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:TeamGameBoard(user:user('worker'))));
  final cells=find.byType(FilledButton);await tester.tap(cells.at(0));await tester.pump();await tester.tap(cells.at(3));await tester.pump();await tester.tap(cells.at(1));await tester.pump();await tester.tap(cells.at(4));await tester.pump();await tester.tap(cells.at(2));await tester.pump();expect(find.text('Ganó Jugador X'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('cache and pending writes are explicitly not server confirmations',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Column(children:[OfflineDataBadge(cached:true),OfflineDataBadge(cached:false,pending:true)]))));expect(find.textContaining('Copia local'),findsOneWidget);expect(find.textContaining('no es una confirmación'),findsOneWidget);
 });
}
