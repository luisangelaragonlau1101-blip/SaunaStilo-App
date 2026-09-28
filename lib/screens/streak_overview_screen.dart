import '../presentation/appearance.dart';
import '../services/attendance_history_service.dart';
import '../services/attendance_gateway_service.dart';
import '../widgets/attendance_admin_sync.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';
import '../services/recorded_streak.dart';
import '../services/offline_workspace.dart';
import '../widgets/stilo_orbit.dart';

class StreakOverviewScreen extends StatelessWidget{
  final UserModel user;
  const StreakOverviewScreen({super.key,required this.user});
  @override
  Widget build(BuildContext context){
    final admin=user.rol==AppRoles.admin;
    final db=FirebaseFirestore.instance;
    final query=AttendanceHistoryService.watch(user.id, team: admin);
    return Scaffold(backgroundColor:StiloColors.background,appBar:AppBar(title:Text(admin?'Rachas del equipo':'Mi constancia')),body:StreamBuilder<AttendanceHistory>(stream:query,builder:(c,s){
      if(s.hasError)return Center(child:Padding(padding:EdgeInsets.all(24),child:Text('No se pudieron consultar las rachas. Solo Administración puede ver los registros del equipo completo.')));
      if(!s.hasData)return Center(child:CircularProgressIndicator());
      final groups=<String,List<AsistenciaModel>>{};
      for(final a in s.data!.rows){groups.putIfAbsent(a.trabajadorId,()=>[]).add(a);}
      if(!admin)groups.putIfAbsent(user.id,()=>[]);
      return ListView(padding:EdgeInsets.all(20),children:[
        if(admin)AttendanceAdminSync(day:AttendanceGatewayService.today),
        Row(children:[StiloOrbitIcon(icon:Icons.local_fire_department_rounded,color:Color(0xFFFFB876),size:54,active:true),SizedBox(width:14),Expanded(child:Text('Cada día cuenta',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)))]),
        SizedBox(height:12),Text('A tiempo: suma un día. Justificada: conserva la secuencia sin sumar. Los demás estados la reinician. Se cuentan los días registrados; un día sin registro no se inventa como asistencia ni como falta.',style:TextStyle(color:StiloColors.text.withValues(alpha: .70),height:1.5)),
        OfflineDataBadge(cached:s.data!.cached),
        if(s.data!.notice!=null)Text(s.data!.notice!,style:TextStyle(color:Colors.orangeAccent)),
        if(groups.isEmpty)ListTile(title:Text('Todavía no hay registros para calcular una racha.')),
        for(final group in groups.entries)_card(context,group.key,group.value,admin),
      ]);
    }));
  }
  Widget _card(BuildContext context,String uid,List<AsistenciaModel> rows,bool admin){
    final ordered=rows..sort((a,b)=>a.fecha.compareTo(b.fecha));
    final result=RecordedStreak.from(ordered.map((a)=>AttendancePoint(a.fecha,a.estatus.trim().toLowerCase())).toList());
    return Card(margin:EdgeInsets.symmetric(vertical:12),child:Padding(padding:EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(admin)StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),builder:(c,s)=>Text(s.data?.data()?['nombre']?.toString()??'Integrante',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700))),
      Wrap(spacing:26,runSpacing:10,children:[_number('${result.current}','Última secuencia',StiloColors.accent),_number('${result.best}','Mejor racha',StiloColors.accent)]),
      SizedBox(height:12),Text('Próxima meta: ${result.nextMilestone} días · faltan ${result.nextMilestone-result.current}',style:TextStyle(color:StiloColors.text.withValues(alpha: .70))),
      SizedBox(height:9),ClipRRect(borderRadius:BorderRadius.circular(16),child:LinearProgressIndicator(value:result.current/result.nextMilestone,minHeight:8)),
      SizedBox(height:12),Text(ordered.isEmpty?'Sin registros.':'Último registro: ${DateFormat('dd/MM/yyyy').format(ordered.last.fecha)} · ${ordered.last.estatus.replaceAll('_',' ')}',style:TextStyle(color:StiloColors.text.withValues(alpha: .54),fontSize:12)),
      ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('Ver días que forman el cálculo'),children:[for(final a in ordered.reversed.take(30))ListTile(dense:true,leading:Icon(a.estatus=='a_tiempo'?Icons.check_circle_outline:Icons.event_note_outlined),title:Text(DateFormat('dd/MM/yyyy').format(a.fecha)),trailing:Text(a.estatus.replaceAll('_',' ')))])
    ])));
  }
  Widget _number(String number,String label,Color color)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(number,style:TextStyle(fontSize:42,color:color,fontWeight:FontWeight.w900)),Text(label,style:TextStyle(fontSize:12,color:StiloColors.text.withValues(alpha: .60)))]);
}
