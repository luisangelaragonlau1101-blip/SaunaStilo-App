import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';

class CompanyManualsScreen extends StatefulWidget{
 final UserModel user;
 const CompanyManualsScreen({super.key,required this.user});
 @override State<CompanyManualsScreen> createState()=>_ManualsState();
}
class _ManualsState extends State<CompanyManualsScreen>{
 List<Map<String,dynamic>>? _items;String? _error;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{try{final s=await CompanyLearningService().call('manual-list');if(mounted)setState((){_items=(s['items'] as List).map((e)=>Map<String,dynamic>.from(e)).toList();_error=null;});}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}}
 Future<void> _edit([Map<String,dynamic>? item])async{await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CompanyManualEditor(item:item)));if(mounted)await _load();}
 @override Widget build(BuildContext context){
  if(widget.user.rol!=AppRoles.admin)return const Scaffold(body:Center(child:Text('Solo Administración administra el conocimiento.')));
  return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Conocimiento de la IA'),actions:[IconButton(tooltip:'Actualizar',onPressed:_load,icon:const Icon(Icons.refresh_rounded))]),body:ListView(padding:const EdgeInsets.all(20),children:[
   const Text('Los procedimientos de Sauna Stilo',style:TextStyle(fontSize:27,fontWeight:FontWeight.w800)),const SizedBox(height:12),const Text('Carga un manual, revisa su contenido y decide quién puede consultarlo. La IA utiliza solo versiones publicadas y muestra los fragmentos que respaldan su respuesta.',style:TextStyle(color:Colors.white70,height:1.5)),const SizedBox(height:20),
   FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.note_add_rounded),label:const Text('Agregar manual o conocimiento')),
   if(_error!=null)Padding(padding:const EdgeInsets.all(16),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
   if(_items==null&&_error==null)const LinearProgressIndicator(),
   if(_items?.isEmpty==true)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No hay manuales publicados todavía. Agrega el primero; no se cargaron documentos de la empresa automáticamente.')),
   for(final d in _items??[])Card(margin:const EdgeInsets.only(top:14),child:ListTile(leading:Icon(d['status']=='published'?Icons.auto_stories_rounded:Icons.edit_note_rounded,color:d['status']=='published'?const Color(0xFFB7FF2A):const Color(0xFFC798FF)),title:Text(d['title'],style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${d['category']} · versión ${d['version']}\n${d['status']=='published'?'Publicado':d['status']=='archived'?'Retirado':'Borrador, aún no lo usa la IA'}'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>_edit(d))),
   const SizedBox(height:22),const Text('PDF con texto, TXT o MD · hasta 2 MB y 30 páginas. Se conserva el texto revisado, no el archivo original. PDFs escaneados requieren transcripción. No incluyas contraseñas ni datos de clientes innecesarios. Biblioteca privada en el servicio de Online Smart, con autorización de tu cuenta de Sauna Stilo.',style:TextStyle(color:Colors.white54,fontSize:12,height:1.5)),
  ]));
 }
}
class CompanyManualEditor extends StatefulWidget{
 final Map<String,dynamic>? item;
 final CompanyLearningService? service;
 const CompanyManualEditor({super.key,this.item,this.service});
 @override State<CompanyManualEditor> createState()=>_ManualEditorState();
}
class _ManualEditorState extends State<CompanyManualEditor>{
 late final service=widget.service??CompanyLearningService();final title=TextEditingController(),category=TextEditingController(text:'General'),content=TextEditingController();
 final roles=<String>{'trabajador','maestro','almacenista'};String? _id,_error;String _filename='Texto revisado',_status='draft';int _version=0;bool _busy=false,_reviewed=false;String? _savedSnapshot;
 String get _snapshot=>jsonEncode([title.text,category.text,content.text,roles.toList()..sort(),_filename]);
 bool get _dirty=>_savedSnapshot!=_snapshot;
 void _changed(){if(mounted)setState(()=>_reviewed=false);}
 @override void initState(){super.initState();for(final c in [title,category,content]){c.addListener(_changed);}if(widget.item!=null)_read();}
 Future<void> _read()async{setState(()=>_busy=true);try{final id=widget.item!['id'];final d=await service.call('manual-read',{'id':id});if(!mounted)return;title.text=d['title'];category.text=d['category'];content.text=d['content'];setState((){_id=id;_version=d['version'];_filename=d['filename']??'Texto';_status=d['status'];roles..clear()..addAll((d['roles'] as List).cast<String>());_savedSnapshot=_snapshot;});}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 @override void dispose(){for(final c in [title,category,content]){c.removeListener(_changed);c.dispose();}super.dispose();}
 Future<void> _import()async{setState(()=>_busy=true);try{final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['pdf','txt','md'],allowMultiple:false);if(files.isEmpty)return;final file=files.single;if(await file.length()>2*1024*1024)throw StateError('Selecciona un archivo legible de hasta 2 MB.');final bytes=await file.readAsBytes();if(bytes.isEmpty||bytes.length>2*1024*1024)throw StateError('Selecciona un archivo legible de hasta 2 MB.');final r=await service.call('manual-import',{'filename':file.name,'base64':base64Encode(bytes)});if(mounted){content.text=r['content'];setState((){_filename=file.name;_reviewed=false;_error=null;});}}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 Future<void> _save()async{if(title.text.trim().isEmpty||content.text.trim().length<30||roles.isEmpty){setState(()=>_error='Escribe título, contenido y al menos un rol autorizado.');return;}setState(()=>_busy=true);try{final r=await service.call('manual-save',{'id':_id,'version':_version,'title':title.text,'content':content.text,'category':category.text,'roles':roles.toList(),'filename':_filename});if(mounted){setState((){_id=r['id'];_version++;_status='draft';_reviewed=false;_savedSnapshot=_snapshot;_error=null;});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Borrador guardado. Revisa y publica para que lo use la IA.')));}}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 Future<void> _publish(bool archive)async{
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(archive?'¿Retirar de la IA?':'¿Publicar la versión guardada?'),content:Text(archive?'La IA dejará de usar este documento en nuevas respuestas.':'Se usará la última versión guardada, para los roles seleccionados. Guarda primero cualquier cambio pendiente.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirmar'))]));if(yes!=true||!mounted)return;
  setState(()=>_busy=true);try{await service.call(archive?'manual-archive':'manual-publish',{'id':_id,'version':_version,'confirmReviewed':true});if(mounted)setState((){_status=archive?'archived':'published';_error=null;});}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Manual de Sauna Stilo')),body:ListView(padding:const EdgeInsets.all(18),children:[
  OutlinedButton.icon(onPressed:_busy?null:_import,icon:const Icon(Icons.upload_file_rounded),label:const Text('Cargar PDF / TXT / MD')),
  const SizedBox(height:14),TextField(contextMenuBuilder:privacyTextMenu,controller:title,enabled:!_busy,maxLength:100,decoration:const InputDecoration(labelText:'Título del manual')),
  TextField(contextMenuBuilder:privacyTextMenu,controller:category,enabled:!_busy,maxLength:60,decoration:const InputDecoration(labelText:'Tema o equipo / modelo')),
  TextField(contextMenuBuilder:privacyTextMenu,controller:content,enabled:!_busy,minLines:12,maxLines:24,maxLength:40000,decoration:const InputDecoration(labelText:'Contenido revisado',alignLabelWithHint:true,hintText:'Instrucciones, pasos, mantenimiento, uso de controles…')),
  const Text('QUIÉN PUEDE CONSULTARLO',style:TextStyle(fontWeight:FontWeight.w800)),
  Wrap(spacing:8,children:[for(final role in ['trabajador','maestro','almacenista','admin'])FilterChip(label:Text(role=='admin'?'Administración':role),selected:roles.contains(role),onSelected:_busy?null:(v)=>setState((){if(v){roles.add(role);}else{roles.remove(role);}_reviewed=false;}))]),
  const Text('Administración puede revisar toda la biblioteca. Un borrador o documento retirado no se envía a la IA.',style:TextStyle(color:Colors.white54,fontSize:12)),const SizedBox(height:18),
  FilledButton(onPressed:_busy?null:_save,child:Text(_busy?'Procesando…':'Guardar borrador')),
  if(_id!=null)...[if(_dirty)const Text('Hay cambios sin guardar. Guarda y vuelve a revisar antes de publicar.',style:TextStyle(color:Colors.orangeAccent)),const SizedBox(height:14),Text('Versión $_version · ${_status=='published'?'Publicada':_status=='archived'?'Retirada':'Borrador'}'),CheckboxListTile(value:_reviewed,onChanged:_busy||_dirty?null:(v)=>setState(()=>_reviewed=v==true),title:const Text('Revisé el texto guardado y autorizo su uso por la IA.')),OutlinedButton.icon(onPressed:_busy||!_reviewed||_dirty?null:()=>_publish(false),icon:const Icon(Icons.publish_rounded),label:const Text('Publicar versión guardada')),if(_status=='published')TextButton(onPressed:_busy?null:()=>_publish(true),child:const Text('Retirar de futuras respuestas'))],
  if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
 ]));
}
