import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lesson_catalog.dart';

/// Personal practice only. This never creates work badges, attendance or company records.
class LearningProgress {
 final Map<String,int> bestScores;
 final Map<String,List<String>> days;
 LearningProgress({Map<String,int>? bestScores,Map<String,List<String>>? days}):bestScores=bestScores??{},days=days??{};
 int get xp=>bestScores.entries.fold(0,(sum,e)=>sum+(e.value>=80?60:0));
 int completed(String language)=>bestScores.entries.where((e)=>e.key.startsWith('$language-')&&e.value>=80).length;
 int score(String id)=>bestScores[id]??0;
 bool unlocked(StiloLesson l)=>l.order==0||score('${l.language}-${l.order}')>=80;
 static String dayKey(DateTime now)=>'${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
 static DateTime _day(String key)=>DateTime.utc(int.parse(key.substring(0,4)),int.parse(key.substring(5,7)),int.parse(key.substring(8,10)));
 int streak(String language,DateTime now){
  final dates=(days[language]??[]).where((s)=>s.compareTo(dayKey(now))<=0).toSet().toList()..sort();
  if(dates.isEmpty)return 0;
  final today=_day(dayKey(now)),last=_day(dates.last);
  if(today.difference(last).inDays>1)return 0;
  int n=1;for(int i=dates.length-2;i>=0;i--){if(_day(dates[i+1]).difference(_day(dates[i])).inDays!=1)break;n++;}return n;
 }
 int bestStreak(String language){
  final dates=(days[language]??[]).toSet().toList()..sort();int best=0,current=0;String? before;
  for(final d in dates){current=before!=null&&_day(d).difference(_day(before)).inDays==1?current+1:1;if(current>best)best=current;before=d;}return best;
 }
 void record(String lessonId,int correct,int total,DateTime now){
  final l=stiloLesson(lessonId);
  if(!unlocked(l)||total!=l.pairs.length*2||correct<0||correct>total)throw StateError('Resultado no válido.');
  final value=(correct*100/total).round();if(value>score(lessonId))bestScores[lessonId]=value;
  if(value>=80){final date=dayKey(now),history=days.putIfAbsent(l.language,()=>[]);if(!history.contains(date)){history.add(date);history.sort();}}
 }
 Map<String,dynamic> toJson()=>{'v':1,'scores':bestScores,'days':days};
 factory LearningProgress.fromJson(Map<String,dynamic> d){
  if(d['v']!=1)throw const FormatException('Versión de progreso desconocida.');
  final scores=<String,int>{};final dates=<String,List<String>>{};
  for(final e in Map<String,dynamic>.from(d['scores'] as Map).entries){
   if(!stiloLessons.any((l)=>l.id==e.key)||e.value is! int||e.value<0||e.value>100)throw const FormatException('Puntuación inválida.');scores[e.key]=e.value;
  }
  for(final lang in ['en','fr']){
   final raw=List<String>.from((d['days'] as Map)[lang]??[]);if(raw.length>40000)throw const FormatException('Historial excesivo.');
   for(final day in raw){if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)||dayKey(_day(day))!=day)throw const FormatException('Fecha inválida.');}
   if ((d['days'] as Map).containsKey(lang)) dates[lang]=raw.toSet().toList()..sort();
  }
  return LearningProgress(bestScores:scores,days:dates);
 }
}
class LearningStore {
 static final revision=ValueNotifier<int>(0);
 static Future<void> _tail=Future<void>.value();
 static String key(String uid)=>'sauna.learning.v1.${Uri.encodeComponent(uid)}';
 static Future<LearningProgress> read(String uid)async{
  await _tail;final prefs=await SharedPreferences.getInstance();final raw=prefs.getString(key(uid));
  if(raw==null)return LearningProgress();if(raw.length>1000000)throw const FormatException('No se pudo leer el progreso.');
  return LearningProgress.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map));
 }
 static Future<LearningProgress> record(String uid,String lesson,int correct,int total,DateTime now){
  if(uid.isEmpty)throw ArgumentError('Se requiere una identidad local.');
  final next=_tail.then((_)async{
   final prefs=await SharedPreferences.getInstance(),storageKey=key(uid),raw=prefs.getString(storageKey);
   final progress=raw==null?LearningProgress():LearningProgress.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map));
   progress.record(lesson,correct,total,now);
   if(!await prefs.setString(storageKey,jsonEncode(progress.toJson())))throw StateError('No se confirmó el guardado local.');
   revision.value++;return progress;
  });
  _tail=next.then<void>((_) {},onError:(Object _,StackTrace __){});return next;
 }
}
