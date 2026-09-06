import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'team_contact_service.dart';

String boardResult(List<String> b){
  if(b.length!=9)throw ArgumentError('Tablero inválido');
  for(final line in const [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]){
    if(b[line[0]].isNotEmpty&&b[line[0]]==b[line[1]]&&b[line[0]]==b[line[2]])return b[line[0]];
  }
  return b.contains('')?'':'empate';
}
List<String> placeMark(List<String> b,int i,String mark){
  if(i<0||i>8||!['X','O'].contains(mark)||boardResult(b).isNotEmpty||b[i].isNotEmpty)throw StateError('Jugada no permitida.');
  return List<String>.of(b)..[i]=mark;
}
class TeamGamesService{
  final db=FirebaseFirestore.instance;
  CollectionReference<Map<String,dynamic>> get games=>db.collection('partidas_equipo');
  Future<String> invite(UserModel host,UserModel guest,String id)async{
    if(FirebaseAuth.instance.currentUser?.uid!=host.id||host.id==guest.id||!id.startsWith('juego_${host.id}_'))throw StateError('Selecciona a otra persona.');
    final person=await db.collection('usuarios').doc(guest.id).get(const GetOptions(source:Source.server)).timeout(const Duration(seconds:12));
    if(!person.exists||person.data()?['activo']==false)throw StateError('Esa persona no está disponible.');
    await db.runTransaction((tx) async { final ref=games.doc(id); final old=await tx.get(ref); if(old.exists){ if(old.data()?['creadoPor']!=host.id || !List<String>.from(old.data()?['jugadores']??[]).contains(guest.id)) throw StateError('Invitación no autorizada.'); return; } tx.set(ref,{'jugadores':[host.id,guest.id],'nombres':[host.nombre,guest.nombre],'tablero':List.filled(9,''),
      'estado':'invitada','turno':host.id,'resultado':'','creadoPor':host.id,'fecha':FieldValue.serverTimestamp(),'actualizadaEn':FieldValue.serverTimestamp()}); });
    try{await TeamContactService().saveMessage(user:host,contact:guest,messageId:'juego_$id',data:{'tipo':'texto','texto':'Te invité a jugar Gato. Abre Inicio → Juegos → Con el equipo. Partida $id','partidaId':id});}catch(_){/* The invitation is already visible in Games. */}
    return id;
  }
  Future<void> change(String id,{int? cell,bool accept=false,bool cancel=false})async{
    final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null)throw StateError('Inicia sesión.');
    await db.runTransaction((t)async{
      final ref=games.doc(id);final snap=await t.get(ref);if(!snap.exists)throw StateError('La partida no existe.');
      final d=snap.data()!,players=List<String>.from(snap.data()!['jugadores']);
      if(!players.contains(uid))throw StateError('No formas parte de esta partida.');
      if(accept){if(d['estado']!='invitada'||uid!=players[1])throw StateError('La invitación ya cambió.');t.update(ref,{'estado':'jugando','actualizadaEn':FieldValue.serverTimestamp()});return;}
      if(cancel){if(!['invitada','jugando'].contains(d['estado']))throw StateError('La partida ya terminó.');t.update(ref,{'estado':'cancelada','actualizadaEn':FieldValue.serverTimestamp()});return;}
      if(d['estado']!='jugando'||d['turno']!=uid||cell==null)throw StateError('Espera tu turno.');
      final board=placeMark(List<String>.from(d['tablero']),cell,uid==players[0]?'X':'O');final result=boardResult(board);
      t.update(ref,{'tablero':board,'resultado':result,'estado':result.isEmpty?'jugando':'terminada','turno':uid==players[0]?players[1]:players[0],'actualizadaEn':FieldValue.serverTimestamp()});
    });
  }
}
