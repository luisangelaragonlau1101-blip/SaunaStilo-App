import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/personal_day_screen.dart';

class PersonalPanelControl extends StatefulWidget {
 final UserModel administrator;
 final String profileId, name;
 final bool enabled;
 const PersonalPanelControl({super.key,required this.administrator,required this.profileId,required this.name,required this.enabled});
 @override State<PersonalPanelControl> createState()=>_PersonalPanelControlState();
}
class _PersonalPanelControlState extends State<PersonalPanelControl>{
 bool _busy=false;String? _error;
 Future<void> _change(bool enabled)async{
  if(_busy||widget.administrator.rol!=AppRoles.admin)return;
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(enabled?'¿Activar el panel Mi día?':'¿Volver al panel habitual?'),content:Text(enabled?'${widget.name} tendrá comidas, compras, eventos y pendientes en su Inicio. Conserva su asistencia, racha, insignias, chats, idiomas e IA. No cambia su rol.':'Se conserva el historial y su cuenta. Solo cambia el panel de Inicio.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirmar'))]));
  if(yes!=true||!mounted)return;setState((){_busy=true;_error=null;});
  try{final ref=FirebaseFirestore.instance.collection('usuarios').doc(widget.profileId);await FirebaseFirestore.instance.runTransaction((t)async{final p=await t.get(ref);if(!p.exists||p.data()?['rol']!=AppRoles.trabajador||p.data()?['activo']==false)throw StateError('Selecciona una cuenta activa del personal.');t.update(ref,{'panelPersonal':enabled});});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(enabled?'Panel activado. Ya puedes organizar su día.':'Panel habitual restaurado.')));}
  catch(_){if(mounted)setState(()=>_error='No se confirmó el cambio. Revisa la conexión y el permiso de Administración.');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context){if(widget.administrator.rol!=AppRoles.admin)return const SizedBox.shrink();return Card(color:const Color(0xFF21131C),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26)),child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
  SwitchListTile(title:const Text('Panel personal · Mi día',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Comidas, compras, eventos y pendientes. Sin cambiar su rol ni su asistencia.'),value:widget.enabled,onChanged:_busy?null:_change,activeThumbColor:const Color(0xFFB7FF2A)),
  if(widget.enabled)TextButton.icon(onPressed:_busy?null:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>PersonalDayScreen(user:widget.administrator,targetId:widget.profileId,targetName:widget.name))),icon:const Icon(Icons.edit_calendar_rounded),label:const Text('Organizar su día')),
  if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
 ])));}
}
