import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../academy/lesson_catalog.dart';
import '../academy/learning_progress.dart';
import '../games/round_questions.dart';
import '../widgets/stilo_orbit.dart';

class StiloAcademyScreen extends StatefulWidget{
 final String userId; final List<String> allowedLanguages;
 const StiloAcademyScreen({super.key,required this.userId,this.allowedLanguages=const ['en','fr']});
 @override State<StiloAcademyScreen> createState()=>_AcademyState();
}
class _AcademyState extends State<StiloAcademyScreen>{
 String _language='en';LearningProgress? _progress;String? _error;
 @override void initState(){super.initState();_language=widget.allowedLanguages.first;_load();}
 Future<void> _load()async{try{final p=await LearningStore.read(widget.userId);if(mounted)setState((){_progress=p;_error=null;});}catch(_){if(mounted)setState(()=>_error='No se pudo leer el progreso local. No se borró.');}}
 Future<void> _open(StiloLesson lesson)async{await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>StiloLessonScreen(userId:widget.userId,lesson:lesson)));if(mounted)await _load();}
 @override Widget build(BuildContext context){final p=_progress,lessons=stiloLessons.where((l)=>l.language==_language).toList();
  return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Stilo Aprende')),body:ListView(padding:const EdgeInsets.all(18),children:[
   Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(colors:[Color(0xFF30143F),Color(0xFF171018)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Image.asset('assets/logo_saunastilo.png',width:104,height:50),const Spacer(),const StiloOrbitIcon(icon:Icons.school_rounded,color:Color(0xFFC798FF),size:54,active:true)]),
    const SizedBox(height:14),const Text('Un idioma.\nUn paso cada día.',style:TextStyle(fontSize:29,height:1.12,fontWeight:FontWeight.w900)),
    const SizedBox(height:14),const Text('Lecciones cortas para empezar desde cero. Aprende, practica y celebra tu avance.',style:TextStyle(color:Colors.white70,height:1.5)),
   ]),),
   const SizedBox(height:16),Wrap(spacing:10,children:[for(final lang in widget.allowedLanguages)ChoiceChip(key:ValueKey('language-$lang'),label:Text(lang=='en'?'Inglés':'Francés'),selected:_language==lang,onSelected:(_)=>setState(()=>_language=lang))]),
   const SizedBox(height:16),
   if(_error!=null)...[Text(_error!,style:const TextStyle(color:Colors.orangeAccent)),TextButton(onPressed:_load,child:const Text('Reintentar'))]
   else if(p==null)const LinearProgressIndicator()
   else ...[
    Wrap(spacing:8,runSpacing:8,children:[Chip(avatar:const Icon(Icons.local_fire_department_rounded,color:Color(0xFFFFB876)),label:Text('${p.streak(_language,DateTime.now())} días de racha')),Chip(avatar:const Icon(Icons.star_rounded,color:Color(0xFFB7FF2A)),label:Text('${p.xp} XP total')),Chip(label:Text('${p.completed(_language)}/12 lecciones'))]),
    const SizedBox(height:12),Text('Mejor racha: ${p.bestStreak(_language)} días · meta diaria: una lección aprobada.',style:const TextStyle(color:Colors.white60,fontSize:12)),
    const SizedBox(height:14),ClipRRect(borderRadius:BorderRadius.circular(12),child:LinearProgressIndicator(value:p.completed(_language)/12,minHeight:9)),
    const SizedBox(height:16),const Text('TU RUTA DE APRENDIZAJE',style:TextStyle(color:Colors.white54,fontWeight:FontWeight.w800,letterSpacing:1)),
    for(final l in lessons)Padding(padding:EdgeInsets.fromLTRB(l.order.isEven?0:18,14,l.order.isEven?18:0,0),child:Card(color:const Color(0xFF151015),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(27),side:BorderSide(color:p.score(l.id)>=80?const Color(0x667DAB29):const Color(0xFF332134))),child:ListTile(key:ValueKey('lesson-${l.id}'),contentPadding:const EdgeInsets.all(15),leading:StiloOrbitIcon(icon:p.score(l.id)>=80?Icons.check_circle_rounded:p.unlocked(l)?Icons.play_arrow_rounded:Icons.lock_rounded,color:stiloAccents[l.order%stiloAccents.length],size:49,active:p.unlocked(l)),
     title:Text('${l.order+1}. ${l.title}',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(p.score(l.id)>=80?'Completada · mejor resultado ${p.score(l.id)}%':p.unlocked(l)?'6 expresiones · 12 ejercicios':'Completa la lección anterior'),trailing:p.score(l.id)>=80?const Icon(Icons.star_rounded,color:Color(0xFFFFB876)):null,onTap:p.unlocked(l)?()=>_open(l):null))),
    const SizedBox(height:22),Wrap(spacing:8,runSpacing:8,children:[for(final milestone in [1,3,6,12])Chip(avatar:Icon(p.completed(_language)>=milestone?Icons.workspace_premium_rounded:Icons.lock_outline_rounded,color:p.completed(_language)>=milestone?const Color(0xFFB7FF2A):Colors.white38),label:Text('$milestone ${milestone==1?'lección':'lecciones'}'))]),
   ],
   const SizedBox(height:20),const Text('Curso introductorio. La constancia empresarial requiere evaluación final en línea y revisión de Administración. El texto y los ejercicios funcionan sin Internet después de descargarse la app. La pronunciación depende de las voces disponibles en tu dispositivo.\n\nEl progreso es local, separado por cuenta y dispositivo. No modifica tus rachas laborales. La racha de estudio cuenta días del reloj de este dispositivo; repetir una lección mantiene la práctica, pero no duplica los XP.',style:TextStyle(color:Colors.white54,fontSize:12,height:1.5)),
  ]));
 }
}
class StiloLessonScreen extends StatefulWidget{
 final String userId;final StiloLesson lesson;
 const StiloLessonScreen({super.key,required this.userId,required this.lesson});
 @override State<StiloLessonScreen> createState()=>_LessonState();
}
class _LessonState extends State<StiloLessonScreen>{
 late final List<ChoiceQuestion> _questions;
 bool _studying=true,_busy=false,_finished=false;int _index=0,_correct=0,_voiceTicket=0;String? _chosen,_error;
 final _missed=<int>[];LearningProgress? _result;FlutterTts? _tts;
 StiloLesson get lesson=>widget.lesson;
 @override void initState(){super.initState();final r=Random();_questions=List.generate(lesson.pairs.length*2,(n)=>languageQuestion(lesson,n,r))..shuffle(r);}
 @override void dispose(){_voiceTicket++;_tts?.stop();super.dispose();}
 Future<void> _speak(String text)async{
  final ticket=++_voiceTicket;
  try{
   final tts=_tts??=FlutterTts();await tts.stop();
   final available=await tts.isLanguageAvailable(lesson.locale);
   if(available!=true&&available!=1)throw StateError('Voice unavailable');
   await tts.setLanguage(lesson.locale);await tts.setSpeechRate(.45);await tts.setPitch(1);
   if(!mounted||ticket!=_voiceTicket)return;
   await tts.speak(text);
  }catch(_){if(mounted&&ticket==_voiceTicket)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No hay una voz disponible para este idioma. Puedes continuar con el texto; revisa las voces descargadas en tu teléfono.')));}
 }
 Future<void> _complete()async{
  if(_busy)return;setState((){_busy=true;_error=null;});
  try{final result=await LearningStore.record(widget.userId,lesson.id,_correct,_questions.length,DateTime.now());if(mounted)setState((){_result=result;_finished=true;});}
  catch(_){if(mounted)setState(()=>_error='No se confirmó el guardado local. Tu resultado sigue aquí; reintenta sin salir.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 void _answer(String value){if(_chosen!=null||_finished)return;setState((){_chosen=value;if(value==_questions[_index].answer){_correct++;}else{_missed.add(_index);}});}
 void _next(){if(_chosen==null||_busy)return;if(_index==_questions.length-1){_complete();}else{setState((){_index++;_chosen=null;});}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:Text('${lesson.languageName} · ${lesson.order+1}')),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:ListView(padding:const EdgeInsets.all(20),children:[
  Text(lesson.title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900)),const SizedBox(height:16),
  if(_studying)...[
   Text(lesson.tip,style:const TextStyle(color:Colors.white70,height:1.5)),const SizedBox(height:18),
   for(final p in lesson.pairs)Card(color:const Color(0xFF19111D),child:ListTile(contentPadding:const EdgeInsets.all(15),title:Text(p.foreign,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w700)),subtitle:Text(p.spanish,style:const TextStyle(color:Colors.white60)),trailing:IconButton(tooltip:'Escuchar ${p.foreign}',icon:const Icon(Icons.volume_up_rounded,color:Color(0xFFC798FF)),onPressed:()=>_speak(p.foreign)))),
   const SizedBox(height:18),FilledButton.icon(key:const ValueKey('lesson-practice'),onPressed:(){_voiceTicket++;_tts?.stop();setState(()=>_studying=false);},icon:const Icon(Icons.play_arrow_rounded),label:const Text('Practicar · 12 ejercicios')),
  ]else if(_finished)...[
   const Center(child:StiloOrbitIcon(icon:Icons.emoji_events_rounded,color:Color(0xFFB7FF2A),size:80,active:true)),const SizedBox(height:20),
   Text(_correct*100/_questions.length>=80?'¡Muy bien! Otro paso adelante.':'¡Buen esfuerzo! Vamos a repasar.',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:12),
   Text('$_correct de ${_questions.length} respuestas correctas · ${(_correct*100/_questions.length).round()}%',style:const TextStyle(fontSize:18,color:Colors.white70)),
   const SizedBox(height:10),Text(_correct*100/_questions.length>=80?'Lección aprobada. Tu mejor resultado quedó guardado.\n${_result!.streak(lesson.language,DateTime.now())} días de racha · ${_result!.xp} XP total.':'Necesitas al menos 80% para desbloquear la siguiente. Tu mejor intento quedó guardado, sin sumar un día de racha.',style:const TextStyle(color:Colors.white70,height:1.5)),
   if(_missed.isNotEmpty)...[const SizedBox(height:20),const Text('REPASA ESTAS RESPUESTAS',style:TextStyle(fontWeight:FontWeight.w800)),for(final n in _missed)Card(child:ListTile(title:Text(_questions[n].text),subtitle:Text(_questions[n].explanation)))],
   const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Volver a mi ruta')),
  ]else ...[
   LinearProgressIndicator(value:(_index+1)/_questions.length,minHeight:8,borderRadius:BorderRadius.circular(12)),const SizedBox(height:12),Text('Ejercicio ${_index+1} de ${_questions.length}',style:const TextStyle(color:Colors.white60)),const SizedBox(height:22),
   Text(_questions[_index].text,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,height:1.4)),const SizedBox(height:20),
   for(int n=0;n<4;n++)Padding(padding:const EdgeInsets.only(bottom:12),child:OutlinedButton(key:ValueKey('lesson-answer-$n'),style:OutlinedButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(18),foregroundColor:Colors.white,backgroundColor:_chosen!=null&&_questions[_index].choices[n]==_questions[_index].answer?const Color(0xFF253815):const Color(0xFF1C1420)),onPressed:_chosen!=null?null:()=>_answer(_questions[_index].choices[n]),child:Text(_questions[_index].choices[n],style:const TextStyle(fontSize:18)))),
   if(_chosen!=null)...[
    Semantics(liveRegion:true,child:Text(_chosen==_questions[_index].answer?'¡Correcto!':'Aprendamos de esta respuesta',style:const TextStyle(color:Color(0xFFB7FF2A),fontSize:19,fontWeight:FontWeight.w800))),
    const SizedBox(height:8),Text(_questions[_index].explanation,style:const TextStyle(color:Colors.white70,height:1.5)),const SizedBox(height:16),
    FilledButton(key:const ValueKey('lesson-next'),onPressed:_busy?null:_next,child:Text(_busy?'Guardando…':_index==_questions.length-1?'Terminar lección':'Continuar')),
   ],
   if(_error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
  ]
 ])))));
}
