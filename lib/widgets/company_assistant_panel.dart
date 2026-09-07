import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';

class CompanyAssistantPanel extends StatefulWidget{
 final CompanyLearningService? service;
 const CompanyAssistantPanel({super.key,this.service});
 @override State<CompanyAssistantPanel> createState()=>_CompanyAssistantState();
}
class _CompanyAssistantState extends State<CompanyAssistantPanel>{
 final input=TextEditingController();final _messages=<Map<String,dynamic>>[];bool _busy=false;String? _error;FlutterTts? _tts;int _speech=0;
 @override void dispose(){_speech++;input.dispose();_tts?.stop();super.dispose();}
 Future<void> _send()async{final q=input.text.trim();if(q.isEmpty||_busy)return;setState((){_busy=true;_error=null;});try{final r=await (widget.service??CompanyLearningService()).call('manual-ask',{'question':q});if(mounted){setState((){_messages.add({'question':q,...r});if(_messages.length>15)_messages.removeAt(0);});input.clear();}}catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}finally{if(mounted)setState(()=>_busy=false);}}
 Future<void> _speak(String text)async{final ticket=++_speech;try{final t=_tts??=FlutterTts();await t.stop();await t.setLanguage('es-MX');if(!mounted||ticket!=_speech)return;await t.speak(text);}catch(_){if(mounted)setState(()=>_error='La voz del dispositivo no está disponible. La respuesta sigue en pantalla.');}}
 @override Widget build(BuildContext context)=>Column(children:[Expanded(child:ListView(padding:const EdgeInsets.all(18),children:[
  const Text('Online Smart · Sauna Stilo',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Inteligencia artificial mexicana creada por ANGEL ZALDÍVAR. Pregunta cómo realizar una actividad; consultaré los manuales publicados para tu cuenta.',style:TextStyle(color:Colors.white60,height:1.5)),
  if(_messages.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('Ejemplo: “¿Cómo uso el control del sauna?”\nIncluye el modelo o equipo para encontrar el procedimiento correcto.',style:TextStyle(color:Colors.white70))),
  for(final m in _messages)Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Card(color:const Color(0xFF2A101C),child:Padding(padding:const EdgeInsets.all(16),child:Text(m['question'],style:const TextStyle(fontWeight:FontWeight.w700)))),Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(m['text'],style:const TextStyle(height:1.55)),const SizedBox(height:10),Text(m['hasManuals']==true?'Respuesta con manuales autorizados':'Sin un manual coincidente · orientación general',style:const TextStyle(fontSize:11,color:Color(0xFFC798FF))),TextButton.icon(onPressed:()=>_speak(m['text']),icon:const Icon(Icons.volume_up_rounded),label:const Text('Escuchar · voz del dispositivo')),for(final source in (m['sources'] as List? ??[]))ExpansionTile(title:Text('${source['title']} · v${source['version']}'),subtitle:Text('Fragmento ${source['section']}'),children:[Padding(padding:const EdgeInsets.all(12),child:Text(source['text'],style:const TextStyle(color:Colors.white70,height:1.5)))])])))]),
  if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
 ])),SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Expanded(child:TextField(contextMenuBuilder:privacyTextMenu,controller:input,enabled:!_busy,minLines:1,maxLines:4,maxLength:2500,decoration:const InputDecoration(hintText:'¿Cómo le hago con…?',counterText:''),onSubmitted:(_)=>_send())),const SizedBox(width:8),IconButton.filled(tooltip:'Enviar pregunta',onPressed:_busy?null:_send,icon:_busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send_rounded))])))]);
}
