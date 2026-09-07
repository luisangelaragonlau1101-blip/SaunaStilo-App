import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import '../games/round_match.dart';
import '../games/round_questions.dart';
import '../widgets/stilo_orbit.dart';

class RoundArcadeScreen extends StatefulWidget {
 const RoundArcadeScreen({super.key});
 @override State<RoundArcadeScreen> createState()=>_ArcadeState();
}
class _ArcadeState extends State<RoundArcadeScreen>{
 String _filter='';RoundMatch? _saved;String? _error;bool _opening=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{try{final saved=await RoundStore.read();if(mounted)setState(()=>_saved=saved);}catch(_){if(mounted)setState(()=>_error='La partida anterior no se pudo leer. Puedes comenzar otra.');}}
 Future<void> _open(RoundMatch game)async{await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>RoundBoardScreen(game:game)));if(mounted)_load();}
 Future<void> _start(RoundPack pack)async{
  if(_opening)return;setState(()=>_opening=true);
  final game=await showModalBottomSheet<RoundMatch>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:const Color(0xFF151015),builder:(_)=>_RoundSetup(pack:pack,replace:_saved!=null));
  if(!mounted)return;setState(()=>_opening=false);if(game!=null)await _open(game);
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Retos por rondas')),body:ListView(padding:const EdgeInsets.all(18),children:[
  Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(colors:[Color(0xFF391426),Color(0xFF151015)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[Image.asset('assets/logo_saunastilo.png',width:105,height:52),const Spacer(),const StiloOrbitIcon(icon:Icons.extension_rounded,color:Color(0xFFFFB876),size:54,active:true)]),
   const SizedBox(height:12),const Text('Piensa. Adivina.\nJuega en equipo.',style:TextStyle(fontSize:28,height:1.15,fontWeight:FontWeight.w900)),
   const SizedBox(height:12),const Text('17 tipos de retos · 1–4 jugadores\nSin Internet · por turnos en el mismo teléfono',style:TextStyle(color:Colors.white70,height:1.5)),
  ])),
  const SizedBox(height:16),TextField(contextMenuBuilder: privacyTextMenu, decoration:const InputDecoration(hintText:'Buscar adivinanzas, quiz, palabras…',prefixIcon:Icon(Icons.search)),onChanged:(s)=>setState(()=>_filter=s.toLowerCase().trim())),
  if(_saved!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:OutlinedButton.icon(onPressed:()=>_open(_saved!),icon:const Icon(Icons.play_circle_outline),label:Text(_saved!.finished?'Ver última partida':'Continuar partida guardada'))),
  if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.orangeAccent)),
  const SizedBox(height:12),
  for(final pack in roundPacks.where((p)=>'${p.title} ${p.description}'.toLowerCase().contains(_filter)))Padding(padding:const EdgeInsets.only(bottom:10),child:Card(color:const Color(0xFF111012),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26)),child:ListTile(
   key:ValueKey('round-pack-${pack.id}'),contentPadding:const EdgeInsets.all(16),leading:StiloOrbitIcon(icon:pack.id=='riddles'?Icons.psychology_alt_rounded:pack.id=='english'||pack.id=='french'?Icons.translate_rounded:Icons.quiz_rounded,color:stiloAccents[roundPacks.indexOf(pack)%stiloAccents.length],size:44,active:true),title:Text(pack.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(pack.description),trailing:const Icon(Icons.chevron_right_rounded),onTap:_opening?null:()=>_start(pack)))),
  if(!roundPacks.any((p)=>'${p.title} ${p.description}'.toLowerCase().contains(_filter)))const Padding(padding:EdgeInsets.all(20),child:Text('No hay retos con ese nombre. Prueba otra palabra.')),
  const Text('Todos responden el mismo número de preguntas. Un acierto suma 10 puntos; no hay castigo por fallar ni límite de tiempo. Las preguntas pueden repetirse entre partidas.',style:TextStyle(color:Colors.white54,fontSize:12,height:1.5)),
 ]));
}
class _RoundSetup extends StatefulWidget{
 final RoundPack pack;final bool replace;const _RoundSetup({required this.pack,required this.replace});
 @override State<_RoundSetup> createState()=>_SetupState();
}
class _SetupState extends State<_RoundSetup>{
 int _players=2,_rounds=3;final _names=List.generate(4,(_)=>TextEditingController());
 @override void dispose(){for(final n in _names){n.dispose();}super.dispose();}
 @override Widget build(BuildContext context)=>SingleChildScrollView(padding:EdgeInsets.fromLTRB(22,22,22,22+MediaQuery.viewInsetsOf(context).bottom),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Text(widget.pack.title,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:12),const Text('1–4 jugadores en este teléfono. Cada persona recibe una pregunta por ronda.'),
  const SizedBox(height:14),Wrap(spacing:8,children:[for(int n=1;n<=4;n++)ChoiceChip(key:ValueKey('round-players-$n'),label:Text('$n ${n==1?'jugador':'jugadores'}'),selected:_players==n,onSelected:(_)=>setState(()=>_players=n))]),
  const SizedBox(height:14),Wrap(spacing:8,children:[for(final n in [3,5,10])ChoiceChip(label:Text('$n rondas'),selected:_rounds==n,onSelected:(_)=>setState(()=>_rounds=n))]),
  for(int n=0;n<_players;n++)Padding(padding:const EdgeInsets.only(top:12),child:TextField(contextMenuBuilder: privacyTextMenu, controller:_names[n],maxLength:24,decoration:InputDecoration(labelText:'Jugador ${n+1}',hintText:'Apodo opcional',counterText:''))),
  const SizedBox(height:16),Text(widget.replace?'Empezar reemplaza tu última partida de retos guardada en este dispositivo.':'El progreso de la partida se guarda en este dispositivo.',style:const TextStyle(color:Colors.white54,fontSize:12)),
  const SizedBox(height:12),FilledButton.icon(key:const ValueKey('round-start'),onPressed:()=>Navigator.pop(context,RoundMatch(widget.pack.id,List.generate(_players,(n)=>_names[n].text.trim().isEmpty?'Jugador ${n+1}':_names[n].text.trim()),_rounds)),icon:const Icon(Icons.play_arrow_rounded),label:const Text('Comenzar partida')),
 ]));
}
class RoundBoardScreen extends StatefulWidget{
 final RoundMatch game;const RoundBoardScreen({super.key,required this.game});
 @override State<RoundBoardScreen> createState()=>_RoundBoardState();
}
class _RoundBoardState extends State<RoundBoardScreen>{
 String _save='Guardando…';int _revision=0;
 RoundMatch get g=>widget.game;
 @override void initState(){super.initState();_persist();}
 Future<void> _persist()async{final ticket=++_revision;try{await RoundStore.save(g);if(mounted&&ticket==_revision)setState(()=>_save='Partida guardada en este dispositivo');}catch(_){if(mounted&&ticket==_revision)setState(()=>_save='No se pudo guardar. No cierres esta partida.');}}
 void _act(VoidCallback action){try{setState(action);_persist();}on StateError catch(_) {}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:Text(roundPacks.firstWhere((p)=>p.id==g.pack).title)),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:ListView(padding:const EdgeInsets.all(20),children:[
  Wrap(spacing:8,runSpacing:8,children:[for(int n=0;n<g.names.length;n++)Chip(avatar:Icon(Icons.person_rounded,size:16,color:stiloAccents[n]),label:Text('${g.names[n]} · ${g.scores[n]}'))]),
  const SizedBox(height:16),LinearProgressIndicator(value:g.index/g.questions.length,minHeight:7,borderRadius:BorderRadius.circular(10)),const SizedBox(height:20),
  if(g.finished)...[
   const Center(child:StiloOrbitIcon(icon:Icons.emoji_events_rounded,color:Color(0xFFB7FF2A),size:80,active:true)),const SizedBox(height:18),
   Text(g.winners.length>1?'¡Empate de campeones!':'¡Ganó ${g.names[g.winners.single]}!',textAlign:TextAlign.center,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
   const SizedBox(height:12),Text('Partida completa: ${g.rounds} rondas por persona.\n${g.winners.map((n)=>g.names[n]).join(' · ')}',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),
   const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Elegir otro reto')),
  ]else ...[
   Text('Ronda ${g.round} de ${g.rounds} · ${g.names[g.player]}',key:const ValueKey('round-turn'),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:20),
   if(!g.ready)...[
    const Text('Pasa el teléfono a quien le toca. Sin prisa: lean las preguntas y aprendan de las respuestas.',style:TextStyle(color:Colors.white70,height:1.5)),
    if(g.question.preview.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:24),child:Text('Memoriza de izquierda a derecha:\n${g.question.preview}',style:const TextStyle(fontSize:22,height:1.5))),
    const SizedBox(height:20),FilledButton(key:const ValueKey('round-ready'),onPressed:()=>_act(()=>g.ready=true),child:Text(g.question.preview.isEmpty?'Estoy listo':'Ocultar y responder')),
   ]else ...[
    Text(g.question.text,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w700,height:1.4)),const SizedBox(height:20),
    for(int n=0;n<g.question.choices.length;n++)Padding(padding:const EdgeInsets.only(bottom:12),child:OutlinedButton(key:ValueKey('round-answer-$n'),style:OutlinedButton.styleFrom(padding:const EdgeInsets.all(18),alignment:Alignment.centerLeft,foregroundColor:Colors.white,backgroundColor:g.chosen==null?const Color(0xFF181218):g.question.choices[n]==g.question.answer?const Color(0xFF263713):g.question.choices[n]==g.chosen?const Color(0xFF421524):const Color(0xFF181218)),onPressed:g.chosen!=null?null:()=>_act(()=>g.answer(g.question.choices[n])),child:Text(g.question.choices[n],style:const TextStyle(fontSize:18)))),
    if(g.chosen!=null)...[
     Semantics(liveRegion:true,child:Text(g.chosen==g.question.answer?'¡Bien! +10 puntos':'Esta vez no. La respuesta era: ${g.question.answer}',style:TextStyle(color:g.chosen==g.question.answer?const Color(0xFFB7FF2A):const Color(0xFFFFB876),fontSize:20,fontWeight:FontWeight.w800))),
     const SizedBox(height:8),Text(g.question.explanation,style:const TextStyle(color:Colors.white70,height:1.5)),
     const SizedBox(height:18),FilledButton(key:const ValueKey('round-next'),onPressed:()=>_act(g.next),child:Text(g.index+1==g.questions.length?'Ver resultados':'Siguiente turno')),
    ]
   ]
  ],
  const SizedBox(height:22),Text(_save,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:Colors.white54)),
 ])))));
}
