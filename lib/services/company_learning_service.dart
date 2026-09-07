import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// HTTPS session is validated by Google's Auth service and the current Firestore role.
/// Tokens are never placed in URLs, documents, prompts or the embedded public guide.
class CompanyLearningService {
 static final endpoint=Uri.parse('https://ollin-smart-vxs23c.v2.appdeploy.ai/api/sauna');
 Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}]) async {
  final user=FirebaseAuth.instance.currentUser;
  if(user==null)throw StateError('Inicia sesión en Sauna Stilo.');
  final token=await user.getIdToken();
  final response=await http.post(endpoint,headers:{'Content-Type':'application/json','X-Sauna-Token':token??''},body:jsonEncode({'action':action,...data})).timeout(const Duration(seconds:65));
  dynamic decoded;try{decoded=jsonDecode(response.body);}catch(_){throw StateError('El servicio no respondió correctamente. Reintenta sin salir.');}
  if(response.statusCode!=200){final message=decoded is Map ? decoded['error']??decoded['message'] : null;throw StateError(message is String?message:'No se confirmó la operación. Vuelve a consultar su estado.');}
  if(FirebaseAuth.instance.currentUser?.uid!=user.uid)throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
  return Map<String,dynamic>.from(decoded as Map);
 }
 static String message(Object error)=>error is StateError?error.message.toString():'No se confirmó la operación. Revisa conexión y permisos.';
}
