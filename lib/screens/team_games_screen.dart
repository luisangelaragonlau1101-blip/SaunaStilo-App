import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/team_games.dart';
import '../services/offline_workspace.dart';
import '../widgets/stilo_orbit.dart';

class TeamGamesScreen extends StatefulWidget{
  final UserModel user;
  const TeamGamesScreen({super.key,required this.user});
  @override
  State<TeamGamesScreen> createState()=>_GamesState();
}
class _GamesState extends State<TeamGamesScreen>{
  late final _service=TeamGamesService();bool _busy=false;final _ids=<String,String>{};
  Future<void> _invite()async{
    final person=await showModalBottomSheet<UserModel>(context:context,isScrollControlled:true,useSafeArea:true,builder:(c)=>SizedBox(height:MediaQuery.sizeOf(c).height*.65,child:Column(children:[const Padding(padding:EdgeInsets.all(20),child:Text('Invitar a jugar Gato',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('usuarios').snapshots(),builder:(c,s){
      if(s.hasError)return const Center(child:Text('No se pudo consultar el equipo.'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final people=s.data!.docs.where((d)=>d.id!=widget.user.id&&d.data()['activo']!=false).map(UserModel.fromFirestore).toList();
      return ListView(children:[for(final p in people)ListTile(title:Text(p.nombre),trailing:const Icon(Icons.sports_esports_outlined),onTap:()=>Navigator.pop(c,p))]);
    }))])));
    if(person==null||!mounted)return;
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('¿Invitar a ${person.nombre}?'),content:const Text('La partida aparecerá en Juegos. Se intentará enviar la invitación a su chat; no se manda una alerta general.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Invitar'))]));
    if(yes!=true||!mounted)return;setState(()=>_busy=true);
    try{final id=_ids.putIfAbsent(person.id,()=>'juego_${widget.user.id}_${_service.games.doc().id}');await _service.invite(widget.user,person,id);_ids.remove(person.id);if(mounted)Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TeamGameBoard(user:widget.user,gameId:id)));}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se confirmó la invitación. Revisa conexión y reglas de Juegos antes de reintentar.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>DefaultTabController(length:2,child:Scaffold(appBar:AppBar(title:const Text('Pausa Stilo · Juegos'),bottom:const TabBar(tabs:[Tab(text:'En este teléfono'),Tab(text:'Con el equipo')])),body:TabBarView(children:[
    ListView(padding:const EdgeInsets.all(20),children:[const Text('Una pausa para conectar',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:12),const Text('Dos juegos para turnarse en el mismo teléfono, incluso sin Internet. Sin apuestas ni compras.',style:TextStyle(color:Colors.white60)),const SizedBox(height:16),
      _tile('Gato','Dos personas · mismo teléfono',Icons.grid_3x3_rounded,0,()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TeamGameBoard(user:widget.user)))),
      _tile('Memoria','Encuentra pares · dos jugadores',Icons.extension_outlined,2,()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const TeamMemoryGame()))),
    ]),
    Column(children:[Padding(padding:const EdgeInsets.all(18),child:FilledButton.icon(onPressed:_busy?null:_invite,icon:const Icon(Icons.person_add_alt),label:Text(_busy?'Creando invitación…':'Invitar a una persona'))),const Padding(padding:EdgeInsets.symmetric(horizontal:20),child:Text('Cada jugador usa su cuenta. Necesitan Internet para aceptar y registrar turnos.',style:TextStyle(color:Colors.white60))),Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:_service.games.where('jugadores',arrayContains:widget.user.id).snapshots(includeMetadataChanges:true),builder:(c,s){
      if(s.hasError)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('El servidor no autorizó consultar partidas. Administración debe publicar las reglas de esta versión. Los juegos locales siguen disponibles.')));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final docs=s.data!.docs.toList()..sort((a,b){int date(Map<String,dynamic>d)=>d['actualizadaEn']is Timestamp?(d['actualizadaEn']as Timestamp).millisecondsSinceEpoch:0;return date(b.data()).compareTo(date(a.data()));});
      return ListView(padding:const EdgeInsets.all(16),children:[OfflineDataBadge(cached:s.data!.metadata.isFromCache),if(docs.isEmpty)const ListTile(title:Text('Aún no hay partidas. Invita a un compañero.')),for(final d in docs)Card(child:ListTile(leading:const Icon(Icons.sports_esports_outlined,color:Color(0xFFB7FF2A)),title:Text((d.data()['nombres']as List).join(' vs. ')),subtitle:Text(d.data()['estado'].toString()),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TeamGameBoard(user:widget.user,gameId:d.id))))) ]);
    }))]),
  ])));
  Widget _tile(String title,String text,IconData icon,int color,VoidCallback tap)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(18),leading:StiloOrbitIcon(icon:icon,color:stiloAccents[color],size:52,active:true),title:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),subtitle:Text(text),trailing:const Icon(Icons.chevron_right_rounded),onTap:tap));
}
class TeamGameBoard extends StatefulWidget{
  final UserModel user;final String? gameId;
  const TeamGameBoard({super.key,required this.user,this.gameId});
  @override
  State<TeamGameBoard> createState()=>_BoardState();
}
class _BoardState extends State<TeamGameBoard>{
  List<String> _local=List.filled(9,'');String _turn='X';bool _busy=false;
  late final _service=TeamGamesService();
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.gameId==null?'Gato · en este teléfono':'Gato · con el equipo')),body:widget.gameId==null?_content(_local,_turn,boardResult(_local),'jugando',false,null):StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:_service.games.doc(widget.gameId).snapshots(includeMetadataChanges:true),builder:(c,s){
    if(s.hasError)return const Center(child:Text('No se pudo leer la partida. Revisa conexión y permisos.'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(!s.data!.exists)return const Center(child:Text('La partida ya no existe.'));
    final d=s.data!.data()!;return _content(List<String>.from(d['tablero']),d['turno'].toString(),d['resultado'].toString(),d['estado'].toString(),s.data!.metadata.isFromCache,d);
  }));
  Future<void> _online({int? cell,bool accept=false,bool cancel=false})async{
    if(_busy||!mounted)return;setState(()=>_busy=true);
    try{await _service.change(widget.gameId!,cell:cell,accept:accept,cancel:cancel);}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se confirmó la jugada. Revisa Internet y el turno actual.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Widget _content(List<String>b,String turn,String result,String status,bool cached,Map<String,dynamic>?d){
    final local=d==null;final players=local?<String>[]:List<String>.from(d['jugadores']);
    final names=local?<String>['Jugador X','Jugador O']:List<String>.from(d['nombres']);
    final name=local?turn:names[players.indexOf(turn).clamp(0,1)];
    return ListView(padding:const EdgeInsets.all(24),children:[
      Text(status=='invitada'?'Invitación pendiente':status=='cancelada'?'Partida cancelada':result=='empate'?'¡Empate!':result.isNotEmpty?'Ganó ${result=='X'?names[0]:names[1]}':'Turno de $name',textAlign:TextAlign.center,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      if(!local)OfflineDataBadge(cached:cached),const SizedBox(height:20),
      Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:400),child:GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:9,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:10,mainAxisSpacing:10),itemBuilder:(c,i)=>Semantics(label:'Casilla ${i+1}: ${b[i].isEmpty?'vacía':b[i]}',button:true,child:FilledButton.tonal(style:FilledButton.styleFrom(backgroundColor:const Color(0xFF20111A),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28))),onPressed:_busy||result.isNotEmpty||status!='jugando'||(!local&&(turn!=widget.user.id||cached))||b[i].isNotEmpty?null:(){if(local){setState((){_local=placeMark(b,i,turn);_turn=turn=='X'?'O':'X';});}else{_online(cell:i);}},child:Text(b[i],style:TextStyle(fontSize:42,fontWeight:FontWeight.w900,color:b[i]=='X'?const Color(0xFFB7FF2A):const Color(0xFFC798FF)))))))),
      const SizedBox(height:20),if(_busy)const LinearProgressIndicator(),
      if(local)OutlinedButton(onPressed:()=>setState((){_local=List.filled(9,'');_turn='X';}),child:const Text('Nueva partida')),
      if(!local&&status=='invitada'&&players[1]==widget.user.id)FilledButton(onPressed:_busy||cached?null:()=>_online(accept:true),child:const Text('Aceptar invitación')),
      if(!local&&['invitada','jugando'].contains(status))TextButton(onPressed:_busy||cached?null:()async{final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('¿Salir de esta partida?'),content:const Text('Quedará cancelada para ambos jugadores.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Seguir')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Cancelar partida'))]));if(yes==true)_online(cancel:true);},child:const Text('Cancelar partida')),
    ]);
  }
}
class TeamMemoryGame extends StatefulWidget{
  const TeamMemoryGame({super.key});
  @override
  State<TeamMemoryGame> createState()=>_MemoryState();
}
class _MemoryState extends State<TeamMemoryGame>{
  final _cards=<int>[0,0,1,1,2,2,3,3,4,4,5,5]..shuffle(Random());
  final _matched=<int>{};final _open=<int>[];final _scores=[0,0];int _player=0;Timer? _timer;
  static const _icons=[Icons.local_fire_department_rounded,Icons.handyman_rounded,Icons.spa_rounded,Icons.favorite_rounded,Icons.star_rounded,Icons.music_note_rounded];
  @override
  void dispose(){_timer?.cancel();super.dispose();}
  void _pick(int i){if(_open.length==2||_matched.contains(i)||_open.contains(i))return;setState(()=>_open.add(i));if(_open.length==2){
    if(_cards[_open[0]]==_cards[_open[1]]){setState((){_matched.addAll(_open);_open.clear();_scores[_player]++;});}
    else{_timer=Timer(const Duration(milliseconds:900),(){if(mounted)setState((){_open.clear();_player=1-_player;});});}
  }}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Memoria Stilo')),body:ListView(padding:const EdgeInsets.all(22),children:[
    Text(_matched.length==12?'¡Partida terminada!':'Turno del jugador ${_player+1}',textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    Padding(padding:const EdgeInsets.all(18),child:Text('Jugador 1: ${_scores[0]} pares  ·  Jugador 2: ${_scores[1]} pares',textAlign:TextAlign.center)),
    GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:12,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:10,mainAxisSpacing:10),itemBuilder:(c,i){final show=_matched.contains(i)||_open.contains(i);return FilledButton.tonal(style:FilledButton.styleFrom(backgroundColor:const Color(0xFF241222),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26))),onPressed:()=>_pick(i),child:Icon(show?_icons[_cards[i]]:Icons.question_mark_rounded,size:32,color:show?stiloAccents[_cards[i]%5]:Colors.white54));}),
    const SizedBox(height:20),OutlinedButton(onPressed:(){_timer?.cancel();setState((){_cards.shuffle();_matched.clear();_open.clear();_scores[0]=0;_scores[1]=0;_player=0;});},child:const Text('Volver a jugar')),
  ]));
}
