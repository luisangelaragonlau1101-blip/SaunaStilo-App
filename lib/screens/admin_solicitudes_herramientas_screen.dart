import '../services/external_transfer.dart';
import '../widgets/warehouse_header.dart';
import '../services/inventario_service.dart';
import 'inventario_admin_screen.dart';
import 'insumo_form_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/warehouse_operations_service.dart';
import '../services/offline_workspace.dart';
import '../widgets/stilo_orbit.dart';

class AdminSolicitudesHerramientasScreen extends StatefulWidget{
  const AdminSolicitudesHerramientasScreen({super.key});
  @override
  State<AdminSolicitudesHerramientasScreen> createState()=>_WarehouseState();
}
class _WarehouseState extends State<AdminSolicitudesHerramientasScreen>{
  String? _busy;String _search='';
  Future<void> _action(String id,String action)async{
    final label=action=='salida'?'Autorizar salida':action=='entrada'?'Confirmar entrada física':'Rechazar solicitud';
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(label),content:Text(action=='entrada'?'Confirma únicamente cuando recibas físicamente la herramienta. La entrada quedará registrada a tu nombre; si tiene daño irá a reparación.':'Se verificará la solicitud vigente. El movimiento y su historial se confirman juntos, con conexión.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Confirmar'))]));
    if(yes!=true||!mounted||_busy!=null)return;setState(()=>_busy=id);
    try{await WarehouseOperationsService().apply(id,action);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Movimiento confirmado. El historial quedó guardado.')));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is StateError?e.message.toString():e is FirebaseException&&e.code=='permission-denied'?'El servidor negó el permiso. Deben publicarse las reglas de Almacén de esta versión.':'No se confirmó el movimiento. Revisa Internet y actualiza la lista antes de reintentar.')));}
    finally{if(mounted)setState(()=>_busy=null);}
  }
  @override
  Widget build(BuildContext context)=>DefaultTabController(length:5,child:Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Almacén'),actions:[IconButton(tooltip:'Registrar herramienta',icon:const Icon(Icons.add_circle_outline_rounded,color:Color(0xFFB7FF2A)),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>InsumoFormScreen(inventarioService:InventarioService())))),IconButton(tooltip:'Ver inventario',icon:const Icon(Icons.inventory_2_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const InventarioAdminScreen())))],bottom:const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,dividerColor:Colors.transparent,indicatorSize:TabBarIndicatorSize.tab,indicator:BoxDecoration(color:Color(0xFF371321),borderRadius:BorderRadius.all(Radius.circular(26))),labelColor:Color(0xFFB7FF2A),unselectedLabelColor:Colors.white60,tabs:[Tab(icon:Icon(Icons.pending_actions_rounded),text:'Solicitudes'),Tab(icon:Icon(Icons.outbox_outlined),text:'En préstamo'),Tab(icon:Icon(Icons.move_to_inbox_outlined),text:'Recibir'),Tab(icon:Icon(Icons.history_rounded),text:'Historial'),Tab(icon:Icon(Icons.swap_horiz_rounded),text:'Compañeros')])),body:Column(children:[
    if(MediaQuery.sizeOf(context).height>650&&MediaQuery.textScalerOf(context).scale(1)<1.5)const Padding(padding:EdgeInsets.fromLTRB(16,16,16,0),child:WarehouseHeader(title:'Cada herramienta, bajo control.',subtitle:'Autoriza la salida · Confirma la devolución · Conserva el historial',compact:true)),
    Padding(padding:const EdgeInsets.all(16),child:TextField(contextMenuBuilder: privacyTextMenu, onChanged:(v)=>setState(()=>_search=v.toLowerCase().trim()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar persona o herramienta'))),
    Expanded(child:TabBarView(children:[for(var i=0;i<4;i++)_list(i),_transfers()])),
  ])));
  Widget _list(int tab)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('solicitudes_herramientas').snapshots(includeMetadataChanges:true),builder:(c,s){
    if(s.hasError)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('No se pudo consultar Almacén. Revisa el rol de tu cuenta y los permisos del servidor.')));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final docs=s.data!.docs.where((doc){final d=doc.data();if(!'${d['trabajadorNombre']} ${d['nombreInsumo']}'.toLowerCase().contains(_search))return false;
      final loan=d['estatus']=='aprobada'&&d['esRetornable']==true&&d['devueltoConfirmadoAdmin']!=true;
      return switch(tab){0=>d['estatus']=='pendiente',1=>loan,2=>loan&&d['marcadoDevueltoTrabajador']==true,_=>true};}).toList();
    docs.sort((a,b)=>_time(b.data()['fechaSolicitud']).compareTo(_time(a.data()['fechaSolicitud'])));
    return Column(children:[OfflineDataBadge(cached:s.data!.metadata.isFromCache,pending:s.data!.metadata.hasPendingWrites),Expanded(child:docs.isEmpty?const Center(child:Text('No hay movimientos en esta vista.')):ListView.builder(padding:const EdgeInsets.fromLTRB(16,0,16,24),itemCount:docs.length,itemBuilder:(c,i){final doc=docs[i],d=doc.data();final returned=d['devueltoConfirmadoAdmin']==true;
      return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[StiloOrbitIcon(icon:Icons.handyman_outlined,color:stiloAccents[tab],size:44),const SizedBox(width:12),Expanded(child:Text('${d['nombreInsumo']??'Herramienta'} × ${d['cantidad']??1}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)))]),
        const SizedBox(height:10),Text('${d['trabajadorNombre']??'Integrante'} · ${returned?'Recibida en almacén':d['estatus']??'pendiente'}'),
        if(d['tieneReporteFalla']==true)const Text('Reportada con daño: recibir en reparación',style:TextStyle(color:Colors.orangeAccent)),
        if((d['observacionesDevolucion']??'').toString().isNotEmpty)Text(d['observacionesDevolucion'].toString()),
        const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[
          if(d['estatus']=='pendiente')...[
            FilledButton(onPressed:_busy!=null?null:()=>_action(doc.id,'salida'),child:const Text('Autorizar salida')),
            TextButton(onPressed:_busy!=null?null:()=>_action(doc.id,'rechazo'),child:const Text('Rechazar'))],
          if(d['estatus']=='aprobada'&&d['esRetornable']==true&&!returned)OutlinedButton.icon(onPressed:_busy!=null?null:()=>_action(doc.id,'entrada'),icon:const Icon(Icons.move_to_inbox_outlined),label:const Text('Confirmar entrada')),
          TextButton.icon(onPressed:()=>_history(doc),icon:const Icon(Icons.history_rounded),label:const Text('Ver historial')),
        ]),if(_busy==doc.id)const LinearProgressIndicator(),
      ])));
    }))]);
  });
  int _time(dynamic v)=>v is Timestamp?v.millisecondsSinceEpoch:0;
  void _history(QueryDocumentSnapshot<Map<String,dynamic>> doc){
    showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,builder:(c)=>SizedBox(height:MediaQuery.sizeOf(c).height*.7,child:Column(children:[
      Padding(padding:const EdgeInsets.all(20),child:Text('Historial · ${doc.data()['nombreInsumo']??''}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800))),
      const Padding(padding:EdgeInsets.symmetric(horizontal:20),child:Text('Se conserva la solicitud original. Los movimientos nuevos incluyen quién autorizó y quién recibió.',style:TextStyle(color:Colors.white60))),
      Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:doc.reference.collection('historial').orderBy('fecha').snapshots(),builder:(c,s){
        if(s.hasError)return const Center(child:Text('No se pudo leer el historial. Revisa los permisos.'));
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        return ListView(children:[ListTile(leading:const Icon(Icons.receipt_long_outlined),title:const Text('Solicitud original'),subtitle:Text('${doc.data()['trabajadorNombre']??''} · ${_date(doc.data()['fechaSolicitud'])}')),
          if(s.data!.docs.isEmpty)const ListTile(title:Text('Sin eventos nuevos'),subtitle:Text('Las solicitudes antiguas conservan sus datos, pero no inventamos la firma de movimientos históricos.')),
          for(final e in s.data!.docs)ListTile(leading:const Icon(Icons.verified_outlined),title:Text(e.data()['accion'].toString()),subtitle:Text('${e.data()['responsableNombre']} · ${_date(e.data()['fecha'])}'))]);
      })),
    ])));
  }
  String _date(dynamic v)=>v is Timestamp?DateFormat('dd/MM/yyyy HH:mm').format(v.toDate()):'Fecha no registrada';
  Widget _transfers()=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('traspasos_inventario').snapshots(includeMetadataChanges:true),builder:(c,s){
    if(s.hasError)return const Center(child:Text('No se pudieron consultar los préstamos entre compañeros.'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final docs=s.data!.docs.where((d)=>'${d.data()['nombre_herramienta']} ${d.data()['origen_usuario_nombre']} ${d.data()['destino_usuario_nombre']}'.toLowerCase().contains(_search)).toList()..sort((a,b)=>_time(b.data()['fecha_creacion']).compareTo(_time(a.data()['fecha_creacion'])));
    return ListView(padding:const EdgeInsets.all(16),children:[const Text('Supervisión de préstamos entre personas. No representan una salida nueva del almacén; la recepción la confirma el destinatario.',style:TextStyle(color:Colors.white60)),OfflineDataBadge(cached:s.data!.metadata.isFromCache),
      if(docs.isEmpty)const ListTile(title:Text('Sin préstamos registrados')),
      for(final doc in docs)Card(child:ListTile(leading:const Icon(Icons.swap_horiz_rounded,color:Color(0xFFB7FF2A)),title:Text(doc.data()['nombre_herramienta']?.toString()??'Herramienta'),subtitle:Text('${doc.data()['origen_usuario_nombre']} → ${doc.data()['destino_usuario_nombre']}\n${doc.data()['estado']} · ${_date(doc.data()['fecha_creacion'])}')))]);
  });
}
