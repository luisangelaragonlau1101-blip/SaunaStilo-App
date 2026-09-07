import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';
import '../services/recorded_streak.dart';
import '../academy/learning_progress.dart';
import 'stilo_orbit.dart';
import 'team_profile_details.dart';

/// Shows real recorded work streaks and admin-granted badges. Never invents attendance for admins.
class HomeProgressPanel extends StatefulWidget{
 final UserModel user;final VoidCallback onStreak,onProfile,onLearn;
 const HomeProgressPanel({super.key,required this.user,required this.onStreak,required this.onProfile,required this.onLearn});
 @override State<HomeProgressPanel> createState()=>_HomeProgressState();
}
class _HomeProgressState extends State<HomeProgressPanel>{
 LearningProgress? _learning;bool _learningError=false;
 @override void initState(){super.initState();LearningStore.revision.addListener(_refresh);_refresh();}
 @override void didUpdateWidget(covariant HomeProgressPanel old){super.didUpdateWidget(old);if(old.user.id!=widget.user.id){_learning=null;_refresh();}}
 void _refresh()async{final uid=widget.user.id;try{final p=await LearningStore.read(uid);if(mounted&&widget.user.id==uid)setState((){_learning=p;_learningError=false;});}catch(_){if(mounted&&widget.user.id==uid)setState(()=>_learningError=true);}}
 @override void dispose(){LearningStore.revision.removeListener(_refresh);super.dispose();}
 @override Widget build(BuildContext context){
  final admin=widget.user.rol==AppRoles.admin,db=FirebaseFirestore.instance;
  final attendance=admin?db.collection('asistencias'):db.collection('asistencias').where('trabajadorId',isEqualTo:widget.user.id);
  return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:attendance.snapshots(includeMetadataChanges:true),builder:(context,s){
   final groups=<String,List<AttendancePoint>>{};
   for(final row in s.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[]){try{final a=AsistenciaModel.fromFirestore(row);groups.putIfAbsent(a.trabajadorId,()=>[]).add(AttendancePoint(a.fecha,a.estatus.trim().toLowerCase()));}catch(_){}}
   final streak=groups.values.map(RecordedStreak.from).fold<int>(0,(best,r)=>max(best,r.current));
   return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:db.collection('usuarios').doc(widget.user.id).snapshots(),builder:(context,profile){
    final raw=profile.data?.data()?['insigniasAdmin'];final badges=raw is List?raw.whereType<Map>().toList():<Map>[];
    return HomeProgressView(admin:admin,streak:s.hasData?'$streak':'—',badges:badges,loadingBadges:!profile.hasData,workUnavailable:s.hasError||profile.hasError,cached:s.data?.metadata.isFromCache==true,
      learning:_learning,learningError:_learningError,onStreak:widget.onStreak,onProfile:widget.onProfile,onLearn:widget.onLearn);
   });
  });
 }
}
class HomeProgressView extends StatelessWidget{
 final bool admin,loadingBadges,workUnavailable,cached,learningError;final String streak;final List<Map> badges;final LearningProgress? learning;
 final VoidCallback onStreak,onProfile,onLearn;
 const HomeProgressView({super.key,required this.admin,required this.streak,required this.badges,this.loadingBadges=false,this.workUnavailable=false,this.cached=false,this.learningError=false,this.learning,required this.onStreak,required this.onProfile,required this.onLearn});
 @override Widget build(BuildContext context)=>Container(key:const ValueKey('home-progress'),margin:const EdgeInsets.only(bottom:18),padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF291018),Color(0xFF151116),Color(0xFF090B08)]),border:Border.all(color:const Color(0xFF513041)),boxShadow:const [BoxShadow(color:Color(0x198E1538),blurRadius:24)]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text('CADA PASO CUENTA',style:TextStyle(color:Colors.white60,fontSize:11,letterSpacing:1.6,fontWeight:FontWeight.w800)),const SizedBox(height:14),
  Wrap(spacing:10,runSpacing:10,children:[
   _pill(Icons.local_fire_department_rounded,streak,admin?'Mejor secuencia del equipo':'Mi racha registrada',const Color(0xFFFFB876),onStreak),
   _pill(Icons.workspace_premium_rounded,loadingBadges?'—':'${badges.length}','Insignias otorgadas',const Color(0xFFB7FF2A),onProfile),
   _pill(Icons.auto_awesome_rounded,learning==null?'—':'${learning!.xp}','XP de idiomas',const Color(0xFFC798FF),onLearn),
  ]),
  if(cached)const Padding(padding:EdgeInsets.only(top:9),child:Text('Asistencia: copia local, pendiente de actualización.',style:TextStyle(color:Colors.white54,fontSize:11))),
  if(workUnavailable)const Padding(padding:EdgeInsets.only(top:9),child:Text('No se pudo actualizar la información laboral.',style:TextStyle(color:Colors.orangeAccent,fontSize:12))),
  if(badges.isNotEmpty)...[const SizedBox(height:12),Wrap(spacing:7,runSpacing:7,children:[for(final b in badges.take(4))Chip(avatar:Icon(recognitionIcons[b['icono']]??Icons.verified_rounded,size:17,color:stiloAccents[(b['acento'] is int?(b['acento'] as int).abs():0)%stiloAccents.length]),label:Text(b['nombre']?.toString()??'Insignia'))])],
  const SizedBox(height:9),TextButton.icon(onPressed:onProfile,icon:const Icon(Icons.military_tech_rounded,size:19),label:const Text('Ver todos mis logros')),
  const Divider(color:Colors.white12),const SizedBox(height:8),
  Row(children:[const StiloOrbitIcon(icon:Icons.translate_rounded,color:Color(0xFFC798FF),size:46,active:true),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Stilo Aprende',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),const SizedBox(height:4),Text(learningError?'Tu progreso local no se pudo leer.':learning==null?'Preparando tu progreso…':'Inglés: ${learning!.streak('en',DateTime.now())} días · Francés: ${learning!.streak('fr',DateTime.now())} días',style:const TextStyle(color:Colors.white60,fontSize:12))]))]),
  const SizedBox(height:12),FilledButton.icon(key:const ValueKey('home-learn'),onPressed:onLearn,icon:const Icon(Icons.school_rounded),label:const Text('Continuar aprendiendo')),
 ]));
 Widget _pill(IconData icon,String number,String label,Color color,VoidCallback tap)=>InkWell(borderRadius:BorderRadius.circular(24),onTap:tap,child:Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:color.withValues(alpha:.07),borderRadius:BorderRadius.circular(24),border:Border.all(color:color.withValues(alpha:.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:color,size:25),const SizedBox(width:7),Text(number,style:TextStyle(color:color,fontSize:26,fontWeight:FontWeight.w900))]),const SizedBox(height:4),Text(label,style:const TextStyle(color:Colors.white70,fontSize:10))])));
}
