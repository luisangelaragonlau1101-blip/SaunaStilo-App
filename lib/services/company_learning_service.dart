import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Calls the live service directly and keeps the API gateway as a safe fallback.
/// The gateway can temporarily answer 402 while the deployed app is still healthy.
/// Google verifies the session and the server checks the current Firestore role.
/// Never include tokens in URLs, documents, prompts, iframe messages or logs.
class CompanyLearningService {
 static final endpoint=Uri.parse('https://ollin-smart-vxs23c.v2.appdeploy.ai/api/sauna');
 static final gatewayEndpoint=Uri.parse('https://api-v2.appdeploy.ai/app/ollin-smart-vxs23c/api/sauna');
 bool _paused(http.Response response){
  dynamic decoded;try{decoded=jsonDecode(response.body);}catch(_){decoded=null;}
  return response.statusCode==402 || (decoded is Map && decoded['code']=='APP_TEMPORARILY_UNAVAILABLE');
 }
 Future<http.Response> _post(Uri target,String token,String action,Map<String,dynamic> data)=>http.post(target,headers:{'Content-Type':'application/json','X-Sauna-Token':token},body:jsonEncode({...data,'action':action})).timeout(const Duration(seconds:65));
 Future<http.Response> _request(String token,String action,Map<String,dynamic> data) async {
  try{
   final direct=await _post(endpoint,token,action,data);
   if(!_paused(direct))return direct;
  }catch(_){
   // If the direct host cannot be reached, retry through the API gateway below.
  }
  return _post(gatewayEndpoint,token,action,data);
 }
 Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}]) async {
  final user=FirebaseAuth.instance.currentUser;
  if(user==null)throw StateError('Inicia sesión en Sauna Stilo.');
  final token=await user.getIdToken();
  if(token==null||token.isEmpty)throw StateError('No se pudo validar tu sesión. Inicia sesión nuevamente.');
  var response=await _request(token,action,data);
  if(response.statusCode==401 && FirebaseAuth.instance.currentUser?.uid==user.uid){
   final renewed=await user.getIdToken(true);
   if(renewed!=null && renewed.isNotEmpty)response=await _request(renewed,action,data);
  }
  if(FirebaseAuth.instance.currentUser?.uid!=user.uid)throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
  dynamic decoded;try{decoded=jsonDecode(response.body);}catch(_){throw StateError('El servicio no respondió correctamente. Reintenta sin salir.');}
  if(_paused(response))throw StateError('Este servicio está temporalmente pausado. Intenta más tarde; no se confirmó esta operación.');
  if(response.statusCode!=200){final message=decoded is Map ? decoded['error']??decoded['message'] : null;throw StateError(message is String?message:'No se confirmó la operación. Vuelve a consultar su estado.');}
  if(decoded is! Map)throw StateError('La respuesta del servicio no tiene el formato esperado.');
  return Map<String,dynamic>.from(decoded);
 }
 static String message(Object error)=>error is StateError?error.message.toString():'No se confirmó la operación. Revisa tu conexión y vuelve a intentar.';
}
