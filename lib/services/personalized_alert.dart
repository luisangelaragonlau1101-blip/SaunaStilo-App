/// One audience mode at a time: a targeted alarm can never inherit a global role.
List<Map<String,dynamic>> personalizedAlertPayloads({required String senderId,required String title,required String message,required String audience,List<String> users=const [],String? role}) {
 final t=title.trim(),m=message.trim();
 if(senderId.isEmpty||t.isEmpty||t.length>80||m.isEmpty||m.length>420)throw ArgumentError('Escribe título (hasta 80) y mensaje (hasta 420 caracteres).');
 if(!['todos','personas','rol'].contains(audience))throw ArgumentError('Selecciona destinatarios.');
 final ids=users.toSet().toList();
 if(audience=='personas'&&(ids.isEmpty||ids.length>100||ids.any((u)=>u.isEmpty||u=='todos'||u.contains('/'))))throw ArgumentError('Selecciona de 1 a 100 personas.');
 if(audience=='rol'&&!['admin','maestro','almacenista','trabajador'].contains(role))throw ArgumentError('Selecciona un rol.');
 final targets=audience=='personas'?ids:[''];
 return targets.map((id)=><String,dynamic>{'titulo':t,'mensaje':m,'tipo':'alarma_admin','destinatarioId':audience=='todos'?'todos':id,'rolesDestinatarios':audience=='todos'?['todos']:audience=='rol'?[role!]:<String>[],'creadoPor':senderId,'leidosPor':<String>[],'prioridad':'critica','requiereAtencion':true,'ruta':'avisos','personalizada':true}).toList();
}
