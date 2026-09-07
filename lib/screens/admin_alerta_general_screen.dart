import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/external_transfer.dart';
import '../services/personalized_alert.dart';

class AdminAlertaGeneralScreen extends StatefulWidget{
 const AdminAlertaGeneralScreen({super.key});
 @override State<AdminAlertaGeneralScreen> createState()=>_AdminAlertState();
}
class _AdminAlertState extends State<AdminAlertaGeneralScreen>{
 final _title=TextEditingController(text:'🚨 ALERTA GENERAL · SAUNA STILO');
 final _message=TextEditingController(text:'Atención equipo Sauna Stilo. Comuníquense con Administración de inmediato.');
 String _audience='todos',_role='trabajador',_search='';final _people=<String>{};bool _sending=false;String? _error,_batchId;List<Map<String,dynamic>>? _pending;
 @override void dispose(){_title.dispose();_message.dispose();super.dispose();}
 Future<void> _send()async{
  if(_sending)return;final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null){setState(()=>_error='Inicia sesión como administrador.');return;}
  setState(()=>_sending=true);
  try{
   final payloads=_pending??personalizedAlertPayloads(senderId:uid,title:_title.text,message:_message.text,audience:_audience,users:_people.toList(),role:_role);
   final label=_audience=='todos'?'TODO EL EQUIPO':_audience=='personas'?'${_people.length} personas seleccionadas':'el rol $_role';
   final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('¿Enviar a $label?'),content:Text('${_title.text}\n\n${_message.text}\n\nSe solicita sonido urgente. La recepción y el volumen dependen de conexión, permisos y ajustes del teléfono.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ENVIAR ALERTA'))]));if(yes!=true||!mounted)return;
   setState((){_sending=true;_error=null;});
   if(payloads.any((p)=>p['creadoPor']!=uid))throw StateError('La sesión cambió. Abre de nuevo esta pantalla.');
   final db=FirebaseFirestore.instance;final profile=await db.collection('usuarios').doc(uid).get(const GetOptions(source:Source.server));
   if(profile.data()?['rol']!='admin'||profile.data()?['activo']==false)throw StateError('Solo una cuenta activa de Administración puede enviar la alerta.');
   _batchId??=db.collection('notificaciones').doc().id;_pending=payloads;
   final batch=db.batch();for(var i=0;i<payloads.length;i++){batch.set(db.collection('notificaciones').doc('${_batchId}_$i'),{...payloads[i],'fecha':FieldValue.serverTimestamp(),'loteId':_batchId});}
   // Same IDs are retained for retry. The existing push trigger runs only on create.
   await batch.commit();
   if(!mounted)return;setState((){_batchId=null;_pending=null;});
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Alerta registrada para sus destinatarios. Esto no confirma que haya sonado en cada teléfono.')));
  }catch(e){if(mounted)setState(()=>_error=e is StateError?e.message.toString():e is ArgumentError?e.message.toString():'No se confirmó el envío. Reintentar conserva el mismo identificador para evitar duplicados.');}
  finally{if(mounted)setState(()=>_sending=false);}
 }
 @override Widget build(BuildContext context){final locked=_sending||_pending!=null;
 return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Alerta General · Personalizada')),body:ListView(padding:const EdgeInsets.all(20),children:[
  Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(colors:[Color(0xFF401024),Color(0xFF141015)]),border:Border.all(color:const Color(0xFF8E1538))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.campaign_rounded,size:46,color:Color(0xFFFF729C)),SizedBox(height:12),Text('La atención del equipo,\ncon tu mensaje.',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),SizedBox(height:10),Text('Conserva la alarma general o elige exactamente a quién avisar.',style:TextStyle(color:Colors.white70))])),
  const SizedBox(height:20),DropdownButtonFormField<String>(initialValue:_audience,decoration:const InputDecoration(labelText:'Destinatarios'),items:const [DropdownMenuItem(value:'todos',child:Text('Todo el equipo')),DropdownMenuItem(value:'personas',child:Text('Elegir personas')),DropdownMenuItem(value:'rol',child:Text('Un rol del equipo'))],onChanged:locked?null:(v)=>setState(()=>_audience=v!)),
  if(_audience=='rol')Padding(padding:const EdgeInsets.only(top:12),child:DropdownButtonFormField<String>(initialValue:_role,items:const [DropdownMenuItem(value:'trabajador',child:Text('Trabajadores')),DropdownMenuItem(value:'maestro',child:Text('Maestros')),DropdownMenuItem(value:'almacenista',child:Text('Almacén')),DropdownMenuItem(value:'admin',child:Text('Administración'))],onChanged:locked?null:(v)=>setState(()=>_role=v!))),
  if(_audience=='personas')...[
   const SizedBox(height:12),TextField(contextMenuBuilder:privacyTextMenu,enabled:!locked,decoration:const InputDecoration(hintText:'Buscar una persona'),onChanged:(v)=>setState(()=>_search=v.toLowerCase())),
   StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('usuarios').snapshots(),builder:(c,s){if(s.hasError)return const Text('No se pudo leer el equipo.');if(!s.hasData)return const LinearProgressIndicator();final people=s.data!.docs.where((d)=>d.data()['activo']!=false&&(d.data()['nombre']??'').toString().toLowerCase().contains(_search)).toList();return Column(children:[for(final d in people)CheckboxListTile(value:_people.contains(d.id),title:Text(d.data()['nombre']?.toString()??'Integrante'),subtitle:Text(d.data()['rol']?.toString()??''),onChanged:locked?null:(v)=>setState((){if(v==true){_people.add(d.id);}else{_people.remove(d.id);}}))]);}),
  ],
  const SizedBox(height:18),TextField(contextMenuBuilder:privacyTextMenu,controller:_title,enabled:!locked,maxLength:80,decoration:const InputDecoration(labelText:'Título personalizado')),
  TextField(contextMenuBuilder:privacyTextMenu,controller:_message,enabled:!locked,minLines:3,maxLines:6,maxLength:420,decoration:const InputDecoration(labelText:'Mensaje que recibirán')),
  if(_error!=null)Padding(padding:const EdgeInsets.only(bottom:16),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
  FilledButton.icon(onPressed:_sending?null:_send,style:FilledButton.styleFrom(backgroundColor:const Color(0xFF8E1538),foregroundColor:Colors.white,minimumSize:const Size.fromHeight(58)),icon:const Icon(Icons.notifications_active_rounded),label:Text(_sending?'ENVIANDO…':_pending!=null?'REINTENTAR EL MISMO ENVÍO':_audience=='todos'?'ACTIVAR ALERTA GENERAL':'ENVIAR ALERTA PERSONALIZADA')),
  const SizedBox(height:18),const Text('El sonido urgente existente se conserva. Personalizar no fuerza volumen máximo, no omite Silencio/Enfoque y no cambia los permisos de notificaciones. El servidor mantiene la validación de Administración antes de distribuir el aviso.',style:TextStyle(color:Colors.white54,fontSize:12,height:1.5)),
 ]));}
}
