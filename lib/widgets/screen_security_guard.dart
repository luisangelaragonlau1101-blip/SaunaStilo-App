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
      if(ticket==_generation&&FirebaseAuth.instance.currentUser?.uid==uid&&d.exists)_secure(true);
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

class CapturePolicyControl extends StatelessWidget {
 final String profileId; final bool enabled;
 const CapturePolicyControl({super.key,required this.profileId,required this.enabled});
 @override
 Widget build(BuildContext context)=>const Card(color:Color(0xFF21111B),child:ListTile(
  leading:Icon(Icons.security_rounded,color:Color(0xFFC798FF)),title:Text('Protección general de Sauna Stilo'),
  subtitle:Text('En el nuevo APK Android, las capturas y la grabación del contenido de la app se bloquean en dispositivos compatibles, para todas las cuentas. No depende de este perfil. No bloquea capturas en Chrome/Safari ni fotografías tomadas con otra cámara.'),
 ));
}
