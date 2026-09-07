import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../academy/learning_progress.dart';
import '../academy/lesson_catalog.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import 'stilo_academy_screen.dart';

String trainingLanguage(String l)=>l=='en'?'Inglés':'Francés';
String trainingStatus(String s)=>const {'none':'Sin solicitud','request':'Solicitud pendiente','approve':'Autorizado','deny':'No autorizado','revoke':'Acceso revocado'}[s]??s;
class TrainingAccessScreen extends StatefulWidget {
 final UserModel user;
 final CompanyLearningService? service;
 const TrainingAccessScreen({super.key,required this.user,this.service});
 @override State<TrainingAccessScreen> createState()=>_TrainingAccessState();
}
class _TrainingAccessState extends State<TrainingAccessScreen>{
 late final service=widget.service??CompanyLearningService();Map<String,dynamic>? _state;String? _error;bool _busy=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{try{final s=await service.call('training-state');if(mounted)setState((){_state=s;_error=null;});}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}}
 Future<void> _request(String l)async{setState(()=>_busy=true);try{final s=await service.call('training-request',{'language':l,'operationId':'request-${DateTime.now().microsecondsSinceEpoch}'});if(mounted)setState((){_state=s;_error=null;});}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 Future<void> _study(String lang)async{
  setState(()=>_busy=true);
  try{final s=await service.call('training-state');final access=(s['languages'] as List).cast<Map>().firstWhere((v)=>v['language']==lang);
   if(access['status']!='approve')throw StateError('Administración debe autorizar el curso.');
   if(!mounted)return;
   await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>StiloAcademyScreen(userId:widget.user.id,allowedLanguages:[lang])));
   await _load();
  }catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _exam(String lang)async{
  setState(()=>_busy=true);
  try{final p=await LearningStore.read(widget.user.id);final completed=stiloLessons.where((l)=>l.language==lang&&p.score(l.id)>=80).map((l)=>l.id).toList();
   if(completed.length!=12)throw StateError('Completa las doce lecciones del idioma antes de la evaluación final.');
   final exam=await service.call('exam-start',{'language':lang,'completedLessons':completed});if(!mounted)return;
   await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CompanyExamScreen(exam:exam)));
   await _load();
  }catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Idiomas · Stilo Aprende'),actions:[IconButton(tooltip:'Actualizar autorización',onPressed:_busy?null:_load,icon:const Icon(Icons.refresh_rounded))]),body:ListView(padding:const EdgeInsets.all(20),children:[
  const Text('Aprende con autorización',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800)),const SizedBox(height:12),
  const Text('Solicita inglés o francés. Administración revisa tu acceso; después podrás estudiar y presentar una evaluación final. La constancia de Sauna Stilo requiere validación de Administración.',style:TextStyle(color:Colors.white70,height:1.5)),
  if(widget.user.rol==AppRoles.admin)Padding(padding:const EdgeInsets.only(top:18),child:OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TrainingAdminScreen(user:widget.user))),icon:const Icon(Icons.admin_panel_settings_rounded),label:const Text('Solicitudes y constancias del equipo'))),
  if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
  if(_state==null&&_error==null)const Padding(padding:EdgeInsets.all(24),child:LinearProgressIndicator()),
  for(final item in (_state?['languages'] as List? ??[]).cast<Map>())Card(margin:const EdgeInsets.only(top:18),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(children:[const Icon(Icons.translate_rounded,color:Color(0xFFC798FF)),const SizedBox(width:12),Text(trainingLanguage(item['language']),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800))]),
   const SizedBox(height:8),Text(trainingStatus(item['status']),style:const TextStyle(color:Color(0xFFB7FF2A),fontWeight:FontWeight.w700)),
   if((item['comment']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text(item['comment'],style:const TextStyle(color:Colors.white60))),
   const SizedBox(height:16),
   if(['none','deny','revoke'].contains(item['status']))FilledButton(onPressed:_busy?null:()=>_request(item['language']),child:const Text('Solicitar acceso')),
   if(item['status']=='request')const Text('Tu solicitud está pendiente. Actualiza aquí después de que Administración la revise.',style:TextStyle(color:Colors.white60)),
   if(item['status']=='approve')...[
    FilledButton.icon(onPressed:_busy?null:()=>_study(item['language']),icon:const Icon(Icons.menu_book_rounded),label:const Text('Entrar al curso')),
    const SizedBox(height:8),OutlinedButton(onPressed:_busy?null:()=>_exam(item['language']),child:const Text('Evaluación final · requiere Internet')),
    if(item['exam']!=null)Text('Evaluación: ${item['exam']['score']}%. ${item['exam']['score']>=80?'Pendiente de validación para constancia.':'Puedes volver a practicar.'}',style:const TextStyle(color:Colors.white70)),
   ],
   if(item['certificate']!=null)TextButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CompanyCertificateScreen(certificate:Map<String,dynamic>.from(item['certificate'])))),icon:const Icon(Icons.workspace_premium_rounded),label:const Text('Ver constancia empresarial')),
  ]))),
  const SizedBox(height:20),const Text('La autorización, evaluación y constancia se consultan en línea. Dentro de una sesión autorizada, las lecciones conservan práctica y progreso local. La constancia acredita el alcance introductorio evaluado, no dominio completo del idioma.',style:TextStyle(color:Colors.white54,fontSize:12,height:1.5)),
 ]));
}
class TrainingAdminScreen extends StatefulWidget{
 final UserModel user;
 const TrainingAdminScreen({super.key,required this.user});
 @override State<TrainingAdminScreen> createState()=>_TrainingAdminState();
}
class _TrainingAdminState extends State<TrainingAdminScreen>{
 final service=CompanyLearningService();String? _uid,_name,_error;Map<String,dynamic>? _state;bool _busy=false;
 Future<void> _select(String uid,String name)async{setState((){_uid=uid;_name=name;_state=null;_error=null;});await _load();}
 Future<void> _load()async{final uid=_uid;if(uid==null)return;try{final s=await service.call('training-state',{'userId':uid});if(mounted&&_uid==uid)setState(()=>_state=s);}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}}
 Future<void> _decision(Map item,String action)async{
  final controller=TextEditingController();bool checked=false;
  final approved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text(action=='certificate'?'Validar aprendizaje y emitir':'${action=='approve'?'Autorizar':action=='deny'?'Rechazar':'Revocar'} ${trainingLanguage(item['language'])}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   Text(_name??'Integrante'),if(action=='certificate')Text('Resultado del servidor: ${item['exam']?['score']}%. Revisa personalmente el aprovechamiento antes de emitir una constancia con tu nombre.'),
   const SizedBox(height:12),TextField(contextMenuBuilder:privacyTextMenu,controller:controller,minLines:2,maxLines:5,maxLength:700,decoration:const InputDecoration(labelText:'Observaciones de la revisión')),
   if(action=='certificate')CheckboxListTile(value:checked,onChanged:(v)=>update(()=>checked=v==true),title:const Text('Revisé el aprendizaje y autorizo la constancia introductoria.')),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:action=='certificate'&&!checked?null:()=>Navigator.pop(c,true),child:const Text('Confirmar'))])));
  final comment=controller.text.trim();controller.dispose();if(approved!=true||!mounted)return;
  if(action=='certificate'&&comment.length<20){setState(()=>_error='Describe la revisión en al menos 20 caracteres antes de emitir.');return;}
  setState(()=>_busy=true);try{
   final s=await service.call(action=='certificate'?'training-issue':'training-decision',{'userId':_uid,'language':item['language'],'expectedId':item['eventId'],'decision':action,'examId':item['exam']?['id'],'comment':comment.isEmpty?'Revisado por Administración.':comment,'confirmReviewed':checked,'operationId':'${action}-${DateTime.now().microsecondsSinceEpoch}'});
   if(mounted)setState((){_state=s;_error=null;});
  }catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context){
  if(widget.user.rol!=AppRoles.admin)return const Scaffold(body:Center(child:Text('Solo Administración.')));
  return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Formación del equipo'),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh_rounded))]),body:ListView(padding:const EdgeInsets.all(18),children:[
   const Text('Solicitudes · revisión · constancias',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:16),
   StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('usuarios').snapshots(),builder:(c,s){if(s.hasError)return const Text('No se pudo leer el equipo.');if(!s.hasData)return const LinearProgressIndicator();final people=s.data!.docs.where((d)=>d.data()['activo']!=false).toList()..sort((a,b)=>(a.data()['nombre']??'').toString().compareTo((b.data()['nombre']??'').toString()));return DropdownButtonFormField<String>(isExpanded:true,initialValue:people.any((p)=>p.id==_uid)?_uid:null,decoration:const InputDecoration(labelText:'Selecciona a una persona'),items:people.map((d)=>DropdownMenuItem(value:d.id,child:Text(d.data()['nombre']?.toString()??'Integrante',overflow:TextOverflow.ellipsis))).toList(),onChanged:_busy?null:(v){if(v!=null)_select(v,people.firstWhere((p)=>p.id==v).data()['nombre']?.toString()??'Integrante');});}),
   if(_error!=null)Padding(padding:const EdgeInsets.all(14),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
   for(final item in (_state?['languages'] as List? ??[]).cast<Map>())Card(margin:const EdgeInsets.only(top:16),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(trainingLanguage(item['language']),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),Text(trainingStatus(item['status'])),const SizedBox(height:12),
    if(item['status']=='request')Wrap(spacing:10,children:[FilledButton(onPressed:_busy?null:()=>_decision(item,'approve'),child:const Text('Aprobar acceso')),TextButton(onPressed:_busy?null:()=>_decision(item,'deny'),child:const Text('Rechazar'))]),
    if(item['status']=='approve')OutlinedButton(onPressed:_busy?null:()=>_decision(item,'revoke'),child:const Text('Revocar acceso')),
    if(item['exam']!=null)Text('Evaluación final: ${item['exam']['score']}% · calculada por servidor'),
    if(item['exam']!=null&&item['exam']['score']>=80&&(item['certificate']==null||item['certificate']['valid']!=true))FilledButton.icon(onPressed:_busy?null:()=>_decision(item,'certificate'),icon:const Icon(Icons.verified_rounded),label:const Text('Revisar y emitir constancia')),
    if(item['certificate']!=null)TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CompanyCertificateScreen(certificate:Map<String,dynamic>.from(item['certificate'])))),child:const Text('Ver constancia y validez')),
   ]))),
   if(_state!=null)...[const SizedBox(height:20),const Text('HISTORIAL DE FORMACIÓN',style:TextStyle(fontWeight:FontWeight.w800)),for(final e in (_state!['history'] as List).reversed)ListTile(leading:const Icon(Icons.history_rounded),title:Text('${trainingLanguage(e['language'])} · ${e['kind']=='certificate'?'Constancia emitida':trainingStatus(e['kind'])}'),subtitle:Text('${e['actorName']} · ${e['at']}'))],
  ]));
 }
}
class CompanyExamScreen extends StatefulWidget{
 final Map<String,dynamic> exam;
 const CompanyExamScreen({super.key,required this.exam});
 @override State<CompanyExamScreen> createState()=>_CompanyExamState();
}
class _CompanyExamState extends State<CompanyExamScreen>{
 late final List<int?> _answers;bool _busy=false;String? _error;Map<String,dynamic>? _result;
 @override void initState(){super.initState();_answers=List.filled((widget.exam['questions'] as List).length,null);}
 Future<void> _submit()async{if(_answers.contains(null)){setState(()=>_error='Responde todos los ejercicios.');return;}setState(()=>_busy=true);try{final r=await CompanyLearningService().call('exam-submit',{'examId':widget.exam['id'],'answers':_answers});if(mounted)setState(()=>_result=r);}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Evaluación final')),body:ListView(padding:const EdgeInsets.all(20),children:[
  if(_result!=null)...[const Icon(Icons.workspace_premium_rounded,size:75,color:Color(0xFFB7FF2A)),Text('${_result!['score']}%',textAlign:TextAlign.center,style:const TextStyle(fontSize:40,fontWeight:FontWeight.w900)),Text(_result!['passed']==true?'Evaluación aprobada. Administración debe revisar el aprendizaje y emitir tu constancia.':'Sigue practicando. Se requiere al menos 80%.',textAlign:TextAlign.center),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Volver'))]
  else ...[const Text('Tienes 20 minutos. Se calcula el resultado en el servidor; terminar las lecciones no emite una constancia automáticamente.',style:TextStyle(color:Colors.white70,height:1.5)),
   for(var i=0;i<_answers.length;i++)Card(margin:const EdgeInsets.only(top:15),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text('${i+1}. ${widget.exam['questions'][i]['prompt']}',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:18)),for(var j=0;j<4;j++)RadioListTile<int>(value:j,groupValue:_answers[i],onChanged:_busy?null:(v)=>setState(()=>_answers[i]=v),title:Text(widget.exam['questions'][i]['choices'][j]))]))),
   if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.orangeAccent)),const SizedBox(height:15),FilledButton(onPressed:_busy?null:_submit,child:Text(_busy?'Verificando…':'Enviar evaluación')),
  ],
 ]));
}
class CompanyCertificateScreen extends StatelessWidget{
 final Map<String,dynamic> certificate;
 const CompanyCertificateScreen({super.key,required this.certificate});
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Constancia Sauna Stilo')),body:ListView(padding:const EdgeInsets.all(20),children:[Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:const Color(0xFF111012),borderRadius:BorderRadius.circular(30),border:Border.all(color:const Color(0xFF8E1538),width:2)),child:Column(children:[Image.asset('assets/logo_saunastilo.png',height:80),const SizedBox(height:22),const Icon(Icons.verified_rounded,color:Color(0xFFB7FF2A),size:60),const SizedBox(height:18),const Text('CONSTANCIA EMPRESARIAL\nDE APROVECHAMIENTO',textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,letterSpacing:1)),const SizedBox(height:22),Text(certificate['learnerName']??'',textAlign:TextAlign.center,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:16),Text(certificate['course']??'',textAlign:TextAlign.center,style:const TextStyle(fontSize:20,color:Color(0xFFC798FF))),const SizedBox(height:18),Text(certificate['scope']??'',textAlign:TextAlign.center,style:const TextStyle(height:1.5,color:Colors.white70)),const SizedBox(height:18),Text('Evaluación interna: ${certificate['score']}%'),Text('Validó: ${certificate['actorName']}'),Text('Emisión: ${certificate['at']}'),const SizedBox(height:15),Text('Folio: SS-${certificate['language']?.toString().toUpperCase()}-${certificate['id']}',textAlign:TextAlign.center,style:const TextStyle(fontSize:11,color:Colors.white60)),const SizedBox(height:16),Text(certificate['valid']==true?'Vigente al consultar el servidor':'Revocada o sin autorización vigente',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w800,color:certificate['valid']==true?const Color(0xFFB7FF2A):Colors.orangeAccent)),const SizedBox(height:10),const Text('Documento interno de Sauna Stilo. No es certificación gubernamental ni un título de dominio completo del idioma.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.white54))]))]));
}
