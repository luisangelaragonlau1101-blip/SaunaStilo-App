import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'round_questions.dart';
class RoundMatch {
 final String pack; final List<String> names; final int rounds;
 final List<ChoiceQuestion> questions; final List<int> scores;
 int index=0;String? chosen;bool ready=false;
 RoundMatch(this.pack,List<String> players,this.rounds,{Random? random}):names=List.unmodifiable(players),scores=List.filled(players.length,0),questions=[]{
  if(!roundPacks.any((p)=>p.id==pack)||players.isEmpty||players.length>4||players.any((n)=>n.trim().isEmpty||n.length>24)||![3,5,10].contains(rounds))throw ArgumentError('Configuración inválida.');
  final r=random??Random();final seen=<String>{};
  for(var n=0;n<players.length*rounds;n++){
   var q=roundQuestion(pack,r);for(var attempt=0;attempt<40&&seen.contains(q.text+'|'+q.choices.join());attempt++){q=roundQuestion(pack,r);}seen.add(q.text+'|'+q.choices.join());questions.add(q);
  }
 }
 bool get finished=>index>=questions.length;
 int get player=>index%names.length;
 int get round=>index~/names.length+1;
 ChoiceQuestion get question=>questions[index];
 List<int> get winners{if(!finished)return [];final best=scores.reduce(max);return [for(var i=0;i<scores.length;i++)if(scores[i]==best)i];}
 void answer(String choice){if(finished||!ready||chosen!=null||!question.choices.contains(choice))throw StateError('Respuesta no permitida.');chosen=choice;if(choice==question.answer)scores[player]+=10;}
 void next(){if(finished||chosen==null)throw StateError('Primero responde.');index++;chosen=null;ready=false;}
 Map<String,dynamic> toJson()=>{'v':1,'pack':pack,'names':names,'rounds':rounds,'questions':questions.map((q)=>q.toJson()).toList(),'scores':scores,'index':index,'chosen':chosen,'ready':ready};
 factory RoundMatch.fromJson(Map<String,dynamic>d){
  if(d['v']!=1)throw const FormatException('Versión desconocida.');
  final m=RoundMatch(d['pack'],List<String>.from(d['names']),d['rounds'],random:Random(0));
  final qs=(d['questions'] as List).map((q)=>ChoiceQuestion.fromJson(Map<String,dynamic>.from(q))).toList();
  final scores=List<int>.from(d['scores']);final index=d['index'];
  if(qs.length!=m.questions.length||scores.length!=m.names.length||scores.any((n)=>n<0||n>m.rounds*10||n%10!=0)||index is! int||index<0||index>qs.length||d['ready'] is! bool)throw const FormatException('Partida inválida.');
  m.questions..clear()..addAll(qs);m.scores.setAll(0,scores);m.index=index;m.chosen=d['chosen'];m.ready=d['ready'];
  if(m.chosen!=null&&(m.finished||!m.ready||!m.question.choices.contains(m.chosen)))throw const FormatException('Respuesta inválida.');return m;
 }
}
class RoundStore{
 static const key='sauna.rounds.local.v1';static Future<void> _tail=Future<void>.value();
 static Future<RoundMatch?> read()async{await _tail;final p=await SharedPreferences.getInstance(),raw=p.getString(key);if(raw==null)return null;if(raw.length>150000)throw const FormatException('Partida demasiado grande.');return RoundMatch.fromJson(Map<String,dynamic>.from(jsonDecode(raw)));}
 static Future<void> save(RoundMatch m){final raw=jsonEncode(m.toJson());final f=_tail.then((_)async{final p=await SharedPreferences.getInstance();if(!await p.setString(key,raw))throw StateError('Guardado no confirmado.');});_tail=f.catchError((Object _){});return f;}
}
