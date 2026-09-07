import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saunastilo/academy/lesson_catalog.dart';
import 'package:saunastilo/academy/learning_progress.dart';
import 'package:saunastilo/games/round_match.dart';
import 'package:saunastilo/games/round_questions.dart';
import 'package:saunastilo/screens/round_arcade_screen.dart';
import 'package:saunastilo/screens/stilo_academy_screen.dart';
import 'package:saunastilo/widgets/home_progress_panel.dart';
import 'package:saunastilo/services/external_transfer.dart';

void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('24 lessons are internally consistent, bilingual and have 144 unambiguous pairs',(){
  expect(stiloLessons.length,24);expect(stiloLessons.map((l)=>l.id).toSet().length,24);
  expect(stiloLessons.fold<int>(0,(n,l)=>n+l.pairs.length),144);
  for(final l in stiloLessons){expect(l.pairs.length,6);expect(l.pairs.map((p)=>p.spanish).toSet().length,6);expect(l.pairs.map((p)=>p.foreign).toSet().length,6);for(int i=0;i<12;i++){final q=languageQuestion(l,i,Random(i));expect(q.choices.toSet().length,4);expect(q.choices,contains(q.answer));}}
 });
 test('17 round categories generate valid questions and playable four-person matches',(){
  expect(roundPacks.length,17);
  for(final pack in roundPacks){
   final random=Random(44);for(int n=0;n<100;n++){final q=roundQuestion(pack.id,random);expect(q.choices.length,4);expect(q.choices.toSet().length,4);expect(q.choices,contains(q.answer));}
   final m=RoundMatch(pack.id,['Uno','Dos','Tres','Cuatro'],3,random:Random(3));
   for(int n=0;n<12;n++){expect(m.player,n%4);expect(m.round,n~/4+1);m.ready=true;final q=m.question;m.answer(q.answer);expect(()=>m.answer(q.answer),throwsStateError);m.next();}
   expect(m.finished,true);expect(m.scores,[30,30,30,30]);expect(m.winners,[0,1,2,3]);expect(RoundMatch.fromJson(m.toJson()).toJson(),m.toJson());
  }
 });
 test('missed answers, premature turns and invalid saved rounds never grant points',(){
  final m=RoundMatch('addition',['A','B'],3,random:Random(4));
  expect(()=>m.answer(m.question.answer),throwsStateError);m.ready=true;m.answer(m.question.choices.firstWhere((c)=>c!=m.question.answer));expect(m.scores,[0,0]);m.next();expect(()=>m.next(),throwsStateError);
  expect(()=>RoundMatch.fromJson({...m.toJson(),'index':99}),throwsFormatException);
 });
 test('round save and resume preserves points and revealed-answer state',()async{
  final m=RoundMatch('flash',['A','B','C','D'],5);m.ready=true;m.answer(m.question.answer);await RoundStore.save(m);expect((await RoundStore.read())!.toJson(),m.toJson());
 });
 test('learning streak is daily, separate by language and not attendance or unlimited XP',(){
  final p=LearningProgress(),now=DateTime(2026,9,6);
  p.record('en-1',12,12,now);p.record('en-1',12,12,now);expect(p.xp,60);expect(p.streak('en',now),1);expect(p.streak('fr',now),0);
  p.record('en-1',12,12,DateTime(2026,9,7));expect(p.streak('en',DateTime(2026,9,7)),2);expect(p.xp,60);
  expect(p.streak('en',DateTime(2026,9,8)),2);expect(p.streak('en',DateTime(2026,9,9)),0);
  p.record('en-2',10,12,DateTime(2026,9,10));expect(p.streak('en',DateTime(2026,9,10)),1);expect(p.bestStreak('en'),2);expect(p.xp,120);
  p.record('fr-1',12,12,now);expect(p.streak('fr',now),1);expect(p.completed('fr'),1);
 });
 test('study failure cannot unlock lessons; lower scores do not replace personal best',(){
  final p=LearningProgress(),now=DateTime(2026,9,6);
  expect(()=>p.record('en-2',12,12,now),throwsStateError);
  p.record('en-1',5,12,now);expect(p.unlocked(stiloLesson('en-2')),false);expect(p.streak('en',now),0);
  p.record('en-1',10,12,now);p.record('en-1',4,12,now);expect(p.score('en-1'),83);expect(p.xp,60);expect(p.unlocked(stiloLesson('en-2')),true);
  expect(LearningProgress.fromJson(p.toJson()).toJson(),p.toJson());
 });
 test('progress isolates two users and survives parallel completions',()async{
  await Future.wait([LearningStore.record('a','en-1',12,12,DateTime(2026,9,6)),LearningStore.record('a','fr-1',12,12,DateTime(2026,9,6))]);
  expect((await LearningStore.read('a')).xp,120);expect((await LearningStore.read('b')).xp,0);expect((await LearningStore.read('local-guest')).xp,0);
 });
 testWidgets('home progress retains role distinction and fits a narrow phone',(tester)async{
  tester.view.physicalSize=const Size(320,850);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  int tapped=0;await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:SingleChildScrollView(child:HomeProgressView(admin:true,streak:'14',badges:const [{'nombre':'Calidad','icono':'calidad','acento':1}],learning:LearningProgress(),onStreak:(){},onProfile:(){},onLearn:()=>tapped++)))));
  expect(find.text('Mejor secuencia del equipo'),findsOneWidget);expect(find.text('Mi racha registrada'),findsNothing);
  await tester.ensureVisible(find.byKey(const ValueKey('home-learn')));await tester.pumpAndSettle();await tester.tap(find.byKey(const ValueKey('home-learn')));expect(tapped,1);expect(tester.takeException(),isNull);
 });
 testWidgets('quiz moves and scores from actual taps, never network',(tester)async{
  final game=RoundMatch('riddles',['A','B','C','D'],3,random:Random(1));
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:RoundBoardScreen(game:game)));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('round-ready')));await tester.pumpAndSettle();
  final target=find.byKey(ValueKey('round-answer-${game.question.choices.indexOf(game.question.answer)}'));
  await tester.ensureVisible(target);await tester.pumpAndSettle();await tester.tap(target);await tester.pumpAndSettle();expect(game.scores,[10,0,0,0]);
  final next=find.byKey(const ValueKey('round-next'));await tester.scrollUntilVisible(next,180,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(next);await tester.pumpAndSettle();await tester.tap(next);await tester.pumpAndSettle();expect(game.player,1);expect(tester.takeException(),isNull);
 });
 testWidgets('starter lesson presents the six expressions and begins exercises',(tester)async{
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:StiloLessonScreen(userId:'test',lesson:stiloLesson('fr-1'))));await tester.pumpAndSettle();
  expect(find.text('Bonjour'),findsOneWidget);
  final start=find.byKey(const ValueKey('lesson-practice'));await tester.scrollUntilVisible(start,200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(start);await tester.pumpAndSettle();await tester.tap(start);await tester.pumpAndSettle();
  expect(find.text('Ejercicio 1 de 12'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('outbound export shows a clear policy notice, not a share sheet',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>ExternalTransfer.block(context),child:const Text('Exportar'))))));
  await tester.tap(find.text('Exportar'));await tester.pump();expect(find.text(ExternalTransfer.blockedMessage),findsOneWidget);
 });
}
