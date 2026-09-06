import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/profile_social_links.dart';
import 'package:saunastilo/services/team_notes_service.dart';
import 'package:saunastilo/widgets/stilo_orbit.dart';
import 'package:saunastilo/widgets/profile_networks.dart';
import 'package:saunastilo/widgets/team_notes_strip.dart';
import 'package:saunastilo/widgets/audio_note_button.dart';
import 'package:saunastilo/widgets/official_voice_reply.dart';

void main() {
  test('administrator supervises attendance without personal check-in action', () {
    for (final role in ['admin','maestro','trabajador','almacenista']) {
      final user = UserModel(id: 'test', nombre: 'Test', correo: 'a@example.invalid', rol: role, fechaRegistro: DateTime(2026));
      final ids = AppActionCatalog.forUser(user).map((a) => a.id).toSet();
      expect(ids.contains('asistencia'), role != 'admin');
      expect(ids.contains('alerta_general'), role == 'admin');
      expect(ids.contains('asistencias'), role == 'admin');
    }
  });
  test('social links accept chosen HTTPS platforms, reject executable or impersonating URLs', () {
    expect(ProfileSocialLinks.normalize('instagram','instagram.com/saunastilo'), 'https://instagram.com/saunastilo');
    for (final url in ['javascript:alert(1)','https://instagram.com.evil.test/a','https://name:password@instagram.com/a','http://instagram.com/a','https://127.0.0.1/a']) {
      expect(() => ProfileSocialLinks.normalize('instagram',url), throwsFormatException);
    }
    expect(ProfileSocialLinks.music('https://open.spotify.com/track/abc'), contains('open.spotify.com'));
    expect(() => ProfileSocialLinks.music('https://example.com/a'), throwsFormatException);
  });
  test('music notes and audio headers use actual bounded content', () {
    expect(() => const TeamNoteDraft(text:' ').validated(), throwsFormatException);
    expect(() => TeamNoteDraft(text:'x'*181).validated(), throwsFormatException);
    expect(const TeamNoteDraft(text:'Hoy toca crear',song:'Mi canción',url:'https://open.spotify.com/track/test').validated().text,'Hoy toca crear');
    final wav = createAudioNoteWav(Uint8List(48000 * 2)); final h = ByteData.sublistView(wav);
    expect(h.getUint32(24, Endian.little),24000); expect(h.getUint32(28, Endian.little),48000);
    expect(wav.length,96044); expect(h.getUint32(40, Endian.little),96000);
    final parts=splitVoiceReply(List.filled(450,'palabra').join(' '));
    expect(parts.every((p)=>p.length<=900),isTrue); expect(parts.join(' '),List.filled(450,'palabra').join(' '));
  });
  testWidgets('round multi-accent dock stays accessible at 320 pixels', (t) async {
    t.view.physicalSize=const Size(320,740);t.view.devicePixelRatio=1;
    addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
    int selected=-1;
    await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(bottomNavigationBar:StiloDock(selectedIndex:0,
      destinations:const [NavigationDestination(icon:Icon(Icons.home),label:'Inicio'),NavigationDestination(icon:Icon(Icons.people),label:'Comunidad'),NavigationDestination(icon:Icon(Icons.chat),label:'Chats'),NavigationDestination(icon:Icon(Icons.task),label:'Tareas'),NavigationDestination(icon:Icon(Icons.person),label:'Perfil')],onSelected:(i)=>selected=i))));
    await t.tap(find.byKey(const ValueKey('stilo-tab-2')));await t.pump();
    expect(selected,2);expect(find.byType(StiloOrbitIcon),findsNWidgets(5));expect(stiloAccents.toSet().length,5);expect(t.takeException(),isNull);
  });
  testWidgets('admin card has no personal attendance buttons', (t) async {
    await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:AdminOperationsCard(onAttendance:(){},onTeam:(){}))));
    expect(find.text('Ver asistencias'),findsOneWidget);expect(find.text('Entrada'),findsNothing);expect(find.text('Salida'),findsNothing);
  });
  testWidgets('social form keeps links after a save error', (t) async {
    await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:ProfileNetworksEditor(initial:const {'instagram':'https://instagram.com/saunastilo'},save:(_)async{throw StateError('offline');}))));
    await t.tap(find.text('Guardar redes'));await t.pumpAndSettle();
    expect(find.textContaining('No se confirmó'),findsOneWidget);expect(find.text('https://instagram.com/saunastilo'),findsOneWidget);expect(t.takeException(),isNull);
  });
  testWidgets('note editor saves validated text and song through the shared callback', (t) async {
    TeamNoteDraft? saved;
    await t.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Builder(builder:(c)=>Scaffold(body:TextButton(onPressed:()=>showDialog<void>(context:c,builder:(_)=>TeamNoteEditor(save:(d)async{saved=d;})),child:const Text('Abrir'))))));
    await t.tap(find.text('Abrir'));await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(0),'Una buena jornada');
    await t.enterText(find.byType(TextField).at(1),'Canción');
    await t.enterText(find.byType(TextField).at(2),'https://open.spotify.com/track/test');
    await t.tap(find.text('Compartir'));await t.pumpAndSettle();
    expect(saved?.text,'Una buena jornada');expect(saved?.url,'https://open.spotify.com/track/test');expect(t.takeException(),isNull);
  });
}
