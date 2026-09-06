import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// This is outside the Navigator: it applies to every Flutter route, not only profiles.
class ScreenSecurityGuard extends StatefulWidget {
  final Widget child;
  const ScreenSecurityGuard({super.key,required this.child});
  @override
  State<ScreenSecurityGuard> createState()=>_GuardState();
}
class _GuardState extends State<ScreenSecurityGuard>{
  static const _channel=MethodChannel('sauna_stilo/security');
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String,dynamic>>>? _profile;
  bool _failed=false; int _generation=0;
  @override
  void initState(){super.initState();_auth=FirebaseAuth.instance.authStateChanges().listen(_bind);}
  Future<void> _bind(User? user)async{
    final ticket=++_generation; await _profile?.cancel(); await _secure(true);
    if(user==null||!mounted||ticket!=_generation)return;
    final uid=user.uid;
    _profile=FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots().listen((d){
      if(ticket==_generation&&FirebaseAuth.instance.currentUser?.uid==uid&&d.exists)_secure(d.data()?['bloquearCapturas']==true);
    },onError:(_){_secure(true);});
  }
  Future<void> _secure(bool flag)async{
    if(kIsWeb||defaultTargetPlatform!=TargetPlatform.android)return;
    try{await _channel.invokeMethod<void>('setSecure',flag);if(mounted&&_failed)setState(()=>_failed=false);}
    catch(_){if(mounted&&flag)setState(()=>_failed=true);}
  }
  @override
  void dispose(){_auth?.cancel();_profile?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context)=>Stack(children:[widget.child,if(_failed)Positioned(left:12,right:12,top:0,child:SafeArea(child:Material(color:const Color(0xFF4B172B),borderRadius:BorderRadius.circular(18),child:const Padding(padding:EdgeInsets.all(12),child:Text('Protección de capturas no confirmada. Este APK necesita actualizarse.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:12))))))]);
}

class CapturePolicyControl extends StatefulWidget{
  final String profileId;final bool enabled;
  const CapturePolicyControl({super.key,required this.profileId,required this.enabled});
  @override
  State<CapturePolicyControl> createState()=>_CaptureControlState();
}
class _CaptureControlState extends State<CapturePolicyControl>{
  bool _busy=false;String? _error;
  @override
  Widget build(BuildContext context)=>Card(color:const Color(0xFF21111B),child:Column(children:[
    SwitchListTile(title:const Text('Bloquear capturas en el APK'),secondary:const Icon(Icons.security_rounded,color:Color(0xFFC798FF)),
      subtitle:const Text('Se aplica a todas las pantallas de Sauna Stilo en Android compatible. No bloquea Chrome/Safari, otras apps ni fotografías con otra cámara.'),value:widget.enabled,onChanged:_busy?null:(v)async{
        final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(v?'Activar protección':'Desactivar protección'),content:const Text('La política se guarda para esta persona. Su APK la recibe con conexión y conserva la última política recibida cuando está sin señal.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Guardar'))]));
        if(yes!=true||!mounted)return;setState((){_busy=true;_error=null;});
        try{await FirebaseFirestore.instance.collection('usuarios').doc(widget.profileId).update({'bloquearCapturas':v});}
        catch(_){if(mounted)setState(()=>_error='El servidor no confirmó el cambio. Revisa tu permiso de Administración.');}
        finally{if(mounted)setState(()=>_busy=false);}
      }),
    if(_busy)const LinearProgressIndicator(),if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
  ]));
}
