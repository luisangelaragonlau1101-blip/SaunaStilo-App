import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/profile_social_links.dart';

String? sharedMediaUrl(String text){
  final matches=RegExp(r'https://[^\s<>]+').allMatches(text);
  for(final m in matches){
    try{
      final url=ProfileSocialLinks.normalize('web',m.group(0)!.replaceAll(RegExp(r'[),.!]+$'),''));
      final h=Uri.parse(url).host.toLowerCase();
      if(['instagram.com','tiktok.com','facebook.com','fb.watch','youtube.com','youtu.be','open.spotify.com','spotify.link'].any((a)=>h==a||h.endsWith('.$a')))return url;
    }on FormatException{/* Do not make invalid stored links actionable. */}
  }
  return null;
}
class SharedMediaCard extends StatelessWidget{
  final String text;
  const SharedMediaCard({super.key,required this.text});
  @override
  Widget build(BuildContext context){final link=sharedMediaUrl(text);if(link==null)return const SizedBox.shrink();
    final music=Uri.parse(link).host.contains('spotify');
    return Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton.icon(icon:Icon(music?Icons.music_note_rounded:Icons.play_circle_outline),label:Text(music?'Abrir en Spotify':'Ver reel o video'),onPressed:()async{
      try{if(!await launchUrl(Uri.parse(link),mode:LaunchMode.externalApplication))throw StateError('open');}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo abrir el enlace. Revisa tu conexión.')));}
    }));
  }
}
Future<void> addSharedLink(BuildContext context,TextEditingController target)async{
  final input=TextEditingController();String? error;
  final url=await showDialog<String>(context:context,builder:(c)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('Compartir un reel o canción'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Copia el enlace desde Instagram, TikTok, Facebook, YouTube o Spotify. Se enviará al pulsar Enviar en el chat.'),const SizedBox(height:12),TextField(controller:input,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'Enlace HTTPS')),if(error!=null)Text(error!,style:const TextStyle(color:Colors.orangeAccent))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),FilledButton(onPressed:(){final u=sharedMediaUrl(input.text.trim());if(u==null){set(()=>error='Usa un enlace válido de una de esas plataformas.');return;}Navigator.pop(c,u);},child:const Text('Agregar al mensaje'))])));
  input.dispose();if(url!=null&&context.mounted){target.text='${target.text.trim()}\n$url'.trim();target.selection=TextSelection.collapsed(offset:target.text.length);}
}
