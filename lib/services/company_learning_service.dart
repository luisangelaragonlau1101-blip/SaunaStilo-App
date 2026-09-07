import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Uses the same API origin and app-scoped route as Online Smart's official SDK.
/// The frontend website is a static host, not the service endpoint.
/// Google verifies the session and the server checks the current Firestore role.
/// Never include tokens in URLs, documents, prompts, iframe messages or logs.
class CompanyLearningService {
 static final endpoint=Uri.parse('https://api-v2.appdeploy.ai/app/ollin-smart-vxs23c/api/sauna');
 Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}]) async {
  final user=FirebaseAuth.instance.currentUser;
  if(user==null)throw StateError('Inicia sesión en Sauna Stilo.');
  final token=await user.getIdToken();
  if(token==null||token.isEmpty)throw StateError('No se pudo validar tu sesión. Inicia sesión nuevamente.');
  final response=await http.post(endpoint,headers:{'Content-Type':'application/json','X-Sauna-Token':token},body:jsonEncode({...data,'action':action})).timeout(const Duration(seconds:65));
  if(FirebaseAuth.instance.currentUser?.uid!=user.uid)throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
  dynamic decoded;try{decoded=jsonDecode(response.body);}catch(_){throw StateError('El servicio no respondió correctamente. Reintenta sin salir.');}
  if(response.statusCode!=200){final message=decoded is Map ? decoded['error']??decoded['message'] : null;throw StateError(message is String?message:'No se confirmó la operación. Vuelve a consultar su estado.');}
  if(decoded is! Map)throw StateError('La respuesta del servicio no tiene el formato esperado.');
  return Map<String,dynamic>.from(decoded);
 }
 static String message(Object error)=>error is StateError?error.message.toString():'No se confirmó la operación. Revisa conexión y permisos.';
}
