import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineWorkspace {
  static bool _configured = false;
  static const trustedKey = 'sauna.offline.trusted';
  static String? cacheProblem;
  static Future<void> configure() async {
    if (_configured) return;
    _configured = true;
    try {
      final p = await SharedPreferences.getInstance();
      final trusted = p.getBool(trustedKey) == true;
      FirebaseFirestore.instance.settings = Settings(persistenceEnabled: trusted, cacheSizeBytes: 40 * 1024 * 1024, webPersistentTabManager: kIsWeb && trusted ? const WebPersistentMultipleTabManager() : null);
    } catch (_) {cacheProblem = 'Este dispositivo no pudo activar la copia persistente. Los borradores locales siguen disponibles.';}
  }
  static Future<bool> confirmDevice(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(trustedKey) == true) return true;
    if (!context.mounted) return false;
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('¿Este dispositivo es de confianza?'),
      content: const Text('Se guardarán datos y borradores en este equipo. No actives esta opción en un teléfono o computadora compartidos. La copia de datos se aplica al cerrar y volver a abrir la app con Internet.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c,false),child: const Text('Cancelar')),FilledButton(onPressed: () => Navigator.pop(c,true),child: const Text('Guardar en este equipo'))]));
    if (yes != true) return false;
    return p.setBool(trustedKey,true);
  }
  static String _key(String uid,String name) {
    if (uid.isEmpty || FirebaseAuth.instance.currentUser?.uid != uid) throw StateError('La sesión cambió.');
    return 'sauna.draft.$uid.$name';
  }
  static Future<void> save(String uid,String name,Map<String,String> data) async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(trustedKey) != true) throw StateError('Autoriza primero el almacenamiento local.');
    final value = jsonEncode(data);
    if (value.length > 16000) throw StateError('El borrador es demasiado grande.');
    if (!await p.setString(_key(uid,name),value)) throw StateError('No se guardó el borrador.');
  }
  static Future<Map<String,String>?> read(String uid,String name) async {
    final p = await SharedPreferences.getInstance();final v=p.getString(_key(uid,name));
    return v == null ? null : Map<String,String>.from(jsonDecode(v) as Map);
  }
  static Future<void> remove(String uid,String name) async {final p=await SharedPreferences.getInstance();await p.remove(_key(uid,name));}
}

class OfflineDataBadge extends StatelessWidget {
  final bool cached, pending;
  const OfflineDataBadge({super.key,required this.cached,this.pending=false});
  @override
  Widget build(BuildContext context) => cached || pending ? Padding(padding: const EdgeInsets.symmetric(horizontal:16,vertical:8),child: Row(children:[
    Icon(pending?Icons.cloud_upload_outlined:Icons.offline_bolt_outlined,size:18,color:Colors.amberAccent),const SizedBox(width:8),
    Expanded(child: Text(pending?'Pendiente de sincronizar: no es una confirmación del servidor.':'Copia local: puede estar incompleta o desactualizada.',style: const TextStyle(color:Colors.amberAccent,fontSize:12))),
  ])) : const SizedBox.shrink();
}
