import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/offline_workspace.dart';

class OfflineDeskScreen extends StatefulWidget {
  final UserModel user;
  const OfflineDeskScreen({super.key, required this.user});
  @override
  State<OfflineDeskScreen> createState() => _OfflineDeskScreenState();
}
class _OfflineDeskScreenState extends State<OfflineDeskScreen> {
  final _text=TextEditingController();String? _message;bool _busy=false;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {try{final d=await OfflineWorkspace.read(widget.user.id,'cuaderno');if(mounted)_text.text=d?['texto']??'';}catch(_){if(mounted)setState(()=>_message='No se pudo recuperar tu cuaderno local.');}}
  @override
  void dispose(){_text.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Mi espacio sin conexión')),body:ListView(padding:EdgeInsets.all(20),children:[
    Icon(Icons.offline_bolt_rounded,size:48,color:StiloColors.accent),SizedBox(height:12),
    Text('Avanza aunque no tengas señal',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),SizedBox(height:12),
    Text('Consulta los datos que ya cargaste y prepara borradores. Las aprobaciones de almacén, la asistencia, el envío de evidencias, los juegos entre teléfonos y la IA necesitan conexión. No se marcan como realizados mientras estés sin Internet.',style:TextStyle(color:StiloColors.text.withValues(alpha: .70),height:1.5)),
    SizedBox(height:14),OutlinedButton.icon(onPressed:_busy?null:()async{final yes=await OfflineWorkspace.confirmDevice(context);if(yes&&mounted)setState(()=>_message='Dispositivo autorizado. Cierra y vuelve a abrir la aplicación con Internet para preparar la copia local.');},icon:Icon(Icons.download_for_offline_outlined),label:Text('Preparar este dispositivo')),
    if(OfflineWorkspace.cacheProblem!=null)Text(OfflineWorkspace.cacheProblem!,style:TextStyle(color:Colors.orangeAccent)),
    SizedBox(height:18),TextField(contextMenuBuilder: privacyTextMenu, controller:_text,maxLines:9,maxLength:8000,decoration:InputDecoration(labelText:'Mi borrador privado en este equipo',alignLabelWithHint:true)),
    FilledButton.icon(onPressed:_busy?null:()async{if(!await OfflineWorkspace.confirmDevice(context)||!mounted)return;setState(()=>_busy=true);try{await OfflineWorkspace.save(widget.user.id,'cuaderno',{'texto':_text.text});if(mounted)setState(()=>_message='Guardado en este dispositivo. No se ha enviado a ninguna persona.');}catch(_){if(mounted)setState(()=>_message='No se guardó. Conserva el texto antes de cerrar.');}finally{if(mounted)setState(()=>_busy=false);}},icon:Icon(Icons.save_outlined),label:Text('Guardar sin enviar')),
    if(_message!=null)Padding(padding:EdgeInsets.symmetric(vertical:15),child:Text(_message!,style:TextStyle(color:StiloColors.accent))),
    Text('En Tareas puedes guardar y recuperar un borrador de asignación. En Juegos puedes jugar en este teléfono sin conexión. Los datos descargados no sustituyen la autorización vigente del servidor.',style:TextStyle(color:StiloColors.text.withValues(alpha: .54),fontSize:12,height:1.5)),
  ]));
}
