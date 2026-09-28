import '../presentation/appearance.dart';
import '../services/inventory_photo_codec.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:video_player/video_player.dart';

/// A view, not a downloader. No share/print/external-open action is exposed.
Future<void> showProtectedMedia(BuildContext context,String url)async{
 if (url.startsWith('data:image/png;base64,')) {
  try { final bytes = InventoryPhotoCodec.decode(url)!;
   await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: Text('Evidencia')), body: Center(child: InteractiveViewer(child: Image.memory(bytes))))));
  } catch (_) { if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('No se pudo abrir la imagen.'))); }
  return;
 }
 final uri=Uri.tryParse(url);
 if(uri==null||uri.scheme!='https'||!['firebasestorage.googleapis.com','storage.googleapis.com'].contains(uri.host)){
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content:Text('No se puede abrir este archivo fuera de Sauna Stilo.')));return;
 }
 await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>_ProtectedMedia(uri:uri)));
}
class _ProtectedMedia extends StatefulWidget{
 final Uri uri;_ProtectedMedia({required this.uri});
 @override State<_ProtectedMedia> createState()=>_MediaState();
}
class _MediaState extends State<_ProtectedMedia>{
 VideoPlayerController? _video;Uint8List? _pdf;String? _error;bool _loading=true,_image=false;
 final _client=http.Client();
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{
  try{
   final path=Uri.decodeComponent(widget.uri.path).toLowerCase();
   if(RegExp(r'\.(jpg|jpeg|png|webp|gif)$').hasMatch(path)){if(mounted)setState((){_image=true;_loading=false;});return;}
   if(RegExp(r'\.(mp4|webm|mov|m4v)$').hasMatch(path)){
    final v=_video=VideoPlayerController.networkUrl(widget.uri);await v.initialize().timeout(Duration(seconds:25));
    if(!mounted)return;setState(()=>_loading=false);return;
   }
   if(!path.endsWith('.pdf'))throw StateError('Este formato no tiene visor interno. El archivo sigue guardado, pero su exportación está desactivada.');
   final response=await _client.send(http.Request('GET',widget.uri)).timeout(Duration(seconds:20));
   if(response.statusCode!=200||(response.contentLength??0)>20*1024*1024)throw StateError('No se pudo abrir el documento o supera 20 MB.');
   final bytes=BytesBuilder();await for(final chunk in response.stream.timeout(Duration(seconds:20))){bytes.add(chunk);if(bytes.length>20*1024*1024)throw StateError('El documento supera 20 MB.');}
   final data=bytes.takeBytes();if(data.length<5||String.fromCharCodes(data.take(5))!='%PDF-')throw StateError('El archivo no es un PDF válido.');
   if(mounted)setState((){_pdf=data;_loading=false;});
  }catch(e){if(mounted)setState((){_error=e is StateError?e.message.toString():'No se pudo cargar el archivo. Revisa conexión y acceso.';_loading=false;});}
 }
 @override void dispose(){_client.close();_video?.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:StiloColors.background,appBar:AppBar(title:Text('Vista protegida')),body:_loading?Center(child:CircularProgressIndicator()):_error!=null?Center(child:Padding(padding:EdgeInsets.all(24),child:Text(_error!))):_image?InteractiveViewer(child:Center(child:Image.network(widget.uri.toString(),errorBuilder:(_,__,___)=>Text('No se pudo cargar la imagen.')))):_pdf!=null?PdfPreview(build:(_)=>_pdf!,allowPrinting:false,allowSharing:false,useActions:false,canChangeOrientation:false,canChangePageFormat:false):_video!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[AspectRatio(aspectRatio:_video!.value.aspectRatio,child:VideoPlayer(_video!)),IconButton(tooltip:_video!.value.isPlaying?'Pausar':'Reproducir',icon:Icon(_video!.value.isPlaying?Icons.pause_circle:Icons.play_circle,size:44),onPressed:()async{if(_video!.value.isPlaying){await _video!.pause();}else{await _video!.play();}if(mounted)setState((){});})])):SizedBox.shrink());
}
