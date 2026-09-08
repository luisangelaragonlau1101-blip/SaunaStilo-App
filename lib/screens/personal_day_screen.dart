import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../services/team_profile_helpers.dart';
import '../widgets/company_assistant_panel.dart';
import '../widgets/home_progress_panel.dart';
import '../widgets/jornada_compacta.dart';
import '../widgets/stilo_orbit.dart';
import 'streak_overview_screen.dart';
import 'training_access_screen.dart';
import 'extra_work_screen.dart';

String personalDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
const personalKinds = {'task': 'Pendientes', 'meal': 'Comidas', 'shopping': 'Compras', 'event': 'Eventos'};
const personalIcons = {'task': Icons.checklist_rounded, 'meal': Icons.restaurant_rounded, 'shopping': Icons.shopping_basket_rounded, 'event': Icons.celebration_rounded};
const personalColors = {'task': Color(0xFFB7FF2A), 'meal': Color(0xFFFFB876), 'shopping': Color(0xFFC798FF), 'event': Color(0xFFFF729C)};

/// A distinct home for an administrator-enabled staff account. No role elevation.
class PersonalDayScreen extends StatefulWidget {
  final UserModel user;
  final String? targetId, targetName;
  final bool embedded;
  final VoidCallback? onOptions, onProfile;
  final CompanyLearningService? service;
  const PersonalDayScreen({super.key, required this.user, this.targetId, this.targetName, this.embedded = false, this.onOptions, this.onProfile, this.service});
  @override State<PersonalDayScreen> createState() => _PersonalDayState();
}
class _PersonalDayState extends State<PersonalDayScreen> with WidgetsBindingObserver {
  late final CompanyLearningService service = widget.service ?? CompanyLearningService();
  DateTime _day = mexicoToday();
  int _tab = 0, _generation = 0;
  bool _loading = true, _busy = false;
  String? _error;
  Map<String,dynamic>? _data, _upcoming;
  String get uid => widget.targetId ?? widget.user.id;
  bool get _own => uid == widget.user.id;
  bool get _admin => widget.user.rol == AppRoles.admin;
  List<Map<String,dynamic>> get items => (_data?['items'] as List? ?? []).map((v) => Map<String,dynamic>.from(v as Map)).toList();
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override void dispose() { _generation++; WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed && !_busy) _load(); }
  Future<void> _load() async {
    final generation = ++_generation, date = personalDate(_day);
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        service.call('personal-list', {'userId':uid,'date':date}),
        service.call('personal-upcoming', {'userId':uid,'date':date}),
      ]);
      if (mounted && generation == _generation) setState(() { _data = values[0]; _upcoming = values[1]; });
    } catch (e) { if (mounted && generation == _generation) setState(() => _error = CompanyLearningService.message(e)); }
    finally { if (mounted && generation == _generation) setState(() => _loading = false); }
  }
  void _changeDay(DateTime value) { setState(() { _day = value; _data = null; _upcoming = null; }); _load(); }
  Future<void> _chooseDay() async { final picked = await showDatePicker(context:context, initialDate:_day, firstDate:DateTime(2020), lastDate:DateTime(2099,12,31)); if (picked != null && mounted) _changeDay(picked); }
  Future<void> _complete(Map<String,dynamic> item, bool done, {int? step}) async {
    if (_busy || _loading || _error != null) return;
    setState(() => _busy = true);
    try {
      await service.call('personal-change', {'userId':uid,'date':item['date'],'scope':item['kind']=='event'?'events':'day','id':item['id'],'change':step==null?'complete':'step','done':done,if(step!=null)'step':step,'operationId':const Uuid().v4()});
      if (mounted) await _load();
    } catch (e) { if (mounted) setState(() => _error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _edit(String kind, [Map<String,dynamic>? item]) async {
    if (!_admin) return;
    final date = await showModalBottomSheet<DateTime>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:const Color(0xFF111012),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(30))),builder:(_) => PersonalItemForm(kind:kind,initialDate:_day,item:item,save:(fields,op) => service.call(item==null?'personal-create':'personal-change',{'userId':uid,'scope':kind=='event'?'events':'day',...fields,if(item!=null)...{'id':item['id'],'change':'edit'},'operationId':op})));
    if (mounted && date != null) { _changeDay(date); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Guardado. El plan se comparte con la persona asignada y Administración.'))); }
  }
  Future<void> _archive(Map<String,dynamic> item) async {
    if (!_admin) return;
    final yes = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('¿Retirar esta actividad?'),content:const Text('Dejará de aparecer como pendiente, pero conservará su historial.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Retirar'))]));
    if (yes != true || !mounted || _busy) return;
    setState(()=>_busy=true);
    try { await service.call('personal-change',{'userId':uid,'date':item['date'],'scope':item['kind']=='event'?'events':'day','id':item['id'],'change':'archive','operationId':const Uuid().v4()}); if(mounted)await _load(); }
    catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _help() async {
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Consultar mi plan con Online Smart'),content:const Text('Se utilizarán las comidas, compras y pendientes de esta fecha, además de los manuales autorizados, para orientarte. La IA no modifica tu plan ni registra asistencia.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Consultar'))]));
    if(yes!=true||!mounted)return;
    Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Online Smart · Mi día')),body:CompanyAssistantPanel(service:_PersonalAssistantService(service,uid,personalDate(_day)),description:'Organiza tus actividades con los datos de esta fecha y los manuales autorizados. Las propuestas no cambian el plan. Administración autoriza y asigna las actividades.',example:'Por ejemplo: “¿Qué debo preparar primero?” o “Ayúdame a organizar las compras para la comida”.'))));
  }
  void _finished() {
    if(!mounted)return;
    showDialog<void>(context:context,builder:(c)=>AlertDialog(icon:const Icon(Icons.celebration_rounded,color:Color(0xFFB7FF2A),size:52),title:const Text('¡Terminaste tu jornada laboral!'),content:const Text('Excelente trabajo. Tu salida fue confirmada. Gracias por todo lo que haces. ✨'),actions:[FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('¡Gracias!'))]));
  }
  @override Widget build(BuildContext context) {
    final body=SafeArea(bottom:false,child:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(18,12,18,28),children:[
      if(widget.embedded)...[
        Row(children:[Image.asset('assets/logo_saunastilo.png',width:124,height:48),const Spacer(),IconButton(tooltip:'Todas mis opciones',onPressed:widget.onOptions,icon:const Icon(Icons.apps_rounded))]),
        const SizedBox(height:14),Text('Hola, ${widget.user.nombre.split(' ').first}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
        const Text('Tu día, organizado contigo.',style:TextStyle(color:Colors.white60)),const SizedBox(height:18),
        HomeProgressPanel(user:widget.user,onStreak:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>StreakOverviewScreen(user:widget.user))),onProfile:widget.onProfile??(){},onLearn:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TrainingAccessScreen(user:widget.user)))),
        JornadaCompacta(usuario:widget.user,onExitConfirmed:_finished),const SizedBox(height:18),
      ],
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(colors:[Color(0xFF36101F),Color(0xFF141115)]),border:Border.all(color:const Color(0xFF603047))),child:Row(children:[const StiloOrbitIcon(icon:Icons.wb_sunny_rounded,color:Color(0xFFFFB876),size:52,active:true),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_own?'Mi día':'Día de ${widget.targetName??'la persona'}',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Comidas · compras · eventos · pendientes',style:TextStyle(color:Colors.white60,fontSize:12,height:1.4))]))])),
      Row(children:[IconButton(tooltip:'Día anterior',onPressed:_busy?null:()=>_changeDay(_day.subtract(const Duration(days:1))),icon:const Icon(Icons.chevron_left_rounded)),Expanded(child:TextButton.icon(onPressed:_busy?null:_chooseDay,icon:const Icon(Icons.calendar_month_rounded),label:Text(DateFormat('dd/MM/yyyy').format(_day)))),IconButton(tooltip:'Día siguiente',onPressed:_busy?null:()=>_changeDay(_day.add(const Duration(days:1))),icon:const Icon(Icons.chevron_right_rounded)),IconButton(tooltip:'Actualizar plan',onPressed:_busy?null:_load,icon:const Icon(Icons.refresh_rounded))]),
      Wrap(spacing:8,runSpacing:8,children:[for(var i=0;i<4;i++)ChoiceChip(key:ValueKey('personal-tab-$i'),label:Text(['Mi plan','Compras','Eventos','Historial'][i]),selected:_tab==i,onSelected:(_)=>setState(()=>_tab=i))]),
      const SizedBox(height:18),
      if(_loading||_busy)const LinearProgressIndicator(),
      if(_error!=null)Container(margin:const EdgeInsets.symmetric(vertical:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFF29131A),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(_error!,style:const TextStyle(color:Colors.orangeAccent)),const Text('Lo que siga visible puede ser anterior. No se confirmó un cambio sin conexión.',style:TextStyle(color:Colors.white60,fontSize:12)),TextButton(onPressed:_busy?null:_load,child:const Text('Reintentar y actualizar'))])),
      if(_data!=null&&_error==null)...[
        if(_tab==0)...[
          PersonalCompletionBanner(items:items),
          _section('meal','¿Qué habrá de comer?',items.where((i)=>i['kind']=='meal').toList()),
          _section('task','Mis pendientes',items.where((i)=>i['kind']=='task').toList()),
        ],
        if(_tab==1)_section('shopping','Lista de compras y faltantes',items.where((i)=>i['kind']=='shopping').toList()),
        if(_tab==2)...[
          Row(children:[const Expanded(child:Text('Próximos eventos',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),if(_admin)IconButton(tooltip:'Agregar evento',onPressed:_busy||_loading?null:()=>_edit('event'),icon:const Icon(Icons.add_circle_rounded,color:Color(0xFFFF729C)))]),
          Text('Desde la fecha seleccionada hasta ${_upcoming?['through']??''}. Cambia de mes para consultar fechas posteriores.',style:const TextStyle(color:Colors.white54,fontSize:12)),const SizedBox(height:12),
          if((_upcoming?['items'] as List? ??[]).isEmpty)const Text('Todavía no hay eventos en este periodo.',style:TextStyle(color:Colors.white60)),
          for(final event in (_upcoming?['items'] as List? ??[]))_event(Map<String,dynamic>.from(event as Map)),
        ],
        if(_tab==3)...[
          const Text('Historial del día',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
          if((_data?['history'] as List? ??[]).isEmpty)const Text('No hay movimientos para esta fecha.',style:TextStyle(color:Colors.white60)),
          for(final record in (_data?['history'] as List? ??[]))_history(Map<String,dynamic>.from(record as Map)),
          const SizedBox(height:16),const Text('Historial de eventos del periodo',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
          for(final record in (_upcoming?['history'] as List? ??[]).take(50))_history(Map<String,dynamic>.from(record as Map)),
        ],
      ],
      if (!_admin) Padding(padding: const EdgeInsets.only(top: 14), child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkScreen(user: widget.user))), icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFB876)), label: const Text('Reportar tarea extra o faltante'))),
      const SizedBox(height:22),OutlinedButton.icon(onPressed:_busy||_loading||_error!=null?null:_help,icon:const Icon(Icons.auto_awesome_rounded,color:Color(0xFFC798FF)),label:const Text('Organizar mi día con la IA')),
      const Text('Visible solo para esta persona y Administración. Actualiza para ver las nuevas asignaciones. Completar pendientes no registra automáticamente la salida.',style:TextStyle(color:Colors.white54,fontSize:11,height:1.5)),
      if(widget.embedded)TextButton.icon(onPressed:widget.onOptions,icon:const Icon(Icons.apps_rounded),label:const Text('Todas las opciones de mi cuenta')),
    ])));
    return widget.embedded?body:Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Plan del personal')),body:body);
  }
  Widget _section(String kind,String title,List<Map<String,dynamic>> rows)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[Icon(personalIcons[kind],color:personalColors[kind]),const SizedBox(width:10),Expanded(child:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800))),if(_admin)IconButton(tooltip:'Agregar ${personalKinds[kind]}',onPressed:_busy||_loading?null:()=>_edit(kind),icon:Icon(Icons.add_circle_rounded,color:personalColors[kind]))]),
    if(kind=='shopping')const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Marca las compras asignadas. Para informar lo que falta, envía un reporte; Administración actualiza la lista.',style:TextStyle(color:Colors.white60,fontSize:12))),
    if(rows.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Sin actividades en esta sección. Administración puede asignarlas.',style:TextStyle(color:Colors.white54))),
    for(final item in rows)_item(item),const SizedBox(height:16),
  ]);
  Widget _item(Map<String,dynamic> item){final done=item['done']==true,canEdit=_admin;
    return Card(color:const Color(0xFF121114),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),side:BorderSide(color:personalColors[item['kind']]!.withValues(alpha:.25))),child:Column(children:[
      CheckboxListTile(key:ValueKey('personal-check-${item['id']}'),controlAffinity:ListTileControlAffinity.leading,value:done,onChanged:_busy||_loading?null:(v)=>_complete(item,v==true),activeColor:personalColors[item['kind']],title:Text(item['title'],style:TextStyle(fontWeight:FontWeight.w800,color:done?Colors.white54:Colors.white,decoration:done?TextDecoration.lineThrough:null)),subtitle:Text([if((item['time']??'')!='')item['time'],if((item['quantity']??'')!='')item['quantity'],if((item['details']??'')!='')item['details'],done?'${item['kind']=='shopping'?'Comprado':'Completado'} · ${item['lastBy']}':'Agregado por ${item['createdByName']}'].join('\n'),style:const TextStyle(height:1.45,color:Colors.white60))),
      if(canEdit)Row(mainAxisAlignment:MainAxisAlignment.end,children:[TextButton(onPressed:_busy?null:()=>_edit(item['kind'],item),child:const Text('Editar')),TextButton(onPressed:_busy?null:()=>_archive(item),child:const Text('Retirar'))]),
    ]));
  }
  Widget _event(Map<String,dynamic> item)=>Card(color:const Color(0xFF21121B),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28),side:const BorderSide(color:Color(0xFF663046))),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(item['title'],style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text('${item['date']}  ${item['time']} · ${item['guests']} personas',style:const TextStyle(color:Color(0xFFFFB876))),
    if((item['theme']??'')!='')Text('Temática: ${item['theme']}',style:const TextStyle(color:Color(0xFFC798FF))),
    if((item['menu']??'')!='')Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Text('Menú: ${item['menu']}',style:const TextStyle(height:1.5))),
    if((item['details']??'')!='')Text(item['details'],style:const TextStyle(color:Colors.white60)),
    for(var i=0;i<(item['steps'] as List? ??[]).length;i++)CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,value:(item['stepsDone'] as List? ??[]).contains(i),onChanged:_busy||_loading?null:(v)=>_complete(item,v==true,step:i),title:Text(item['steps'][i],style:TextStyle(decoration:(item['stepsDone'] as List? ??[]).contains(i)?TextDecoration.lineThrough:null))),
    Row(children:[Expanded(child:Text('Último cambio: ${item['lastBy']}',style:const TextStyle(color:Colors.white54,fontSize:11))),if(_admin)...[IconButton(tooltip:'Editar evento',onPressed:_busy?null:()=>_edit('event',item),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Retirar evento',onPressed:_busy?null:()=>_archive(item),icon:const Icon(Icons.archive_outlined))]]),
  ])));
  Widget _history(Map<String,dynamic> record)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.history_rounded,color:Color(0xFFC798FF)),title:Text(record['title']??'Actividad'),subtitle:Text('${const {'create':'Agregado','edit':'Editado','archive':'Retirado','complete':'Estado actualizado','step':'Preparativo actualizado'}[record['action']]??'Cambio'} · ${record['actorName']}\n${record['at']}',style:const TextStyle(fontSize:11,color:Colors.white54)));
}

class PersonalCompletionBanner extends StatelessWidget {
 final List<Map<String,dynamic>> items;
 const PersonalCompletionBanner({super.key,required this.items});
 @override Widget build(BuildContext context){final done=items.where((i)=>i['done']==true).length,all=items.isNotEmpty&&done==items.length;
  return Container(margin:const EdgeInsets.only(bottom:16),padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:const Color(0xFF192012),borderRadius:BorderRadius.circular(25)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(all?'¡Pendientes del día completados! ✨':'Tu avance: $done de ${items.length}',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFFB7FF2A))),const SizedBox(height:9),LinearProgressIndicator(value:items.isEmpty?0:done/items.length,borderRadius:BorderRadius.circular(10)),if(all)const Padding(padding:EdgeInsets.only(top:9),child:Text('Cuando termine tu horario, confirma tu salida en Mi jornada.',style:TextStyle(color:Colors.white70,fontSize:12)))]));
 }
}
class _PersonalAssistantService extends CompanyLearningService {
 final CompanyLearningService parent;final String uid,date;
 _PersonalAssistantService(this.parent,this.uid,this.date);
 @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> data=const {}])=>parent.call('personal-ask',{...data,'userId':uid,'date':date,'includePlan':true});
}

class PersonalItemForm extends StatefulWidget {
 final String kind;final DateTime initialDate;final Map<String,dynamic>? item;
 final Future<Map<String,dynamic>> Function(Map<String,dynamic>,String) save;
 const PersonalItemForm({super.key,required this.kind,required this.initialDate,required this.save,this.item});
 @override State<PersonalItemForm> createState()=>_PersonalItemFormState();
}
class _PersonalItemFormState extends State<PersonalItemForm>{
 late final title=TextEditingController(text:widget.item?['title']??''),details=TextEditingController(text:widget.item?['details']??''),quantity=TextEditingController(text:widget.item?['quantity']??''),time=TextEditingController(text:widget.item?['time']??''),theme=TextEditingController(text:widget.item?['theme']??''),menu=TextEditingController(text:widget.item?['menu']??''),guests=TextEditingController(text:(widget.item?['guests']??'').toString()),steps=TextEditingController(text:(widget.item?['steps'] as List? ??[]).join('\n'));
 late DateTime _date=widget.item==null?widget.initialDate:DateTime.parse(widget.item!['date']);
 bool _busy=false;String? _error;String? _operationId;String? _fingerprint;
 @override void dispose(){for(final c in [title,details,quantity,time,theme,menu,guests,steps]){c.dispose();}super.dispose();}
 Future<void> _save()async{
  if(_busy)return;if(title.text.trim().isEmpty){setState(()=>_error='Escribe un nombre para la actividad.');return;}
  final values=<String,dynamic>{'kind':widget.kind,'title':title.text.trim(),'details':details.text.trim(),'quantity':quantity.text.trim(),'time':time.text.trim(),'date':personalDate(_date),'theme':theme.text.trim(),'menu':menu.text.trim(),'guests':int.tryParse(guests.text.trim())??0,'steps':steps.text.split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList()};
  final fingerprint=values.toString();if(_fingerprint!=fingerprint){_fingerprint=fingerprint;_operationId=const Uuid().v4();}
  setState((){_busy=true;_error=null;});
  try{await widget.save(values,_operationId!);if(mounted)Navigator.pop(context,_date);}
  catch(e){if(mounted)setState(()=>_error=CompanyLearningService.message(e));}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context)=>PopScope(canPop:!_busy,child:Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.88),child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
  Text('${widget.item==null?'Agregar':'Editar'} ${personalKinds[widget.kind]!.toLowerCase()}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
  const SizedBox(height:12),_field(title,widget.kind=='event'?'Nombre del evento':widget.kind=='meal'?'¿Qué se preparará?':widget.kind=='shopping'?'¿Qué hace falta?':'¿Qué hay que hacer?',120,key:const ValueKey('personal-title')),
  OutlinedButton.icon(onPressed:_busy||widget.item!=null?null:()async{final p=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2020),lastDate:DateTime(2099,12,31));if(p!=null&&mounted)setState(()=>_date=p);},icon:const Icon(Icons.event_rounded),label:Text(DateFormat('dd/MM/yyyy').format(_date))),
  _field(time,'Hora (opcional, HH:mm)',5),
  if(widget.kind=='shopping'||widget.kind=='meal')_field(quantity,widget.kind=='meal'?'Porciones o cantidad':'Cantidad y unidad',60),
  if(widget.kind=='event')...[_field(theme,'Temática o ambiente',120),_field(guests,'Número de personas',4,number:true),_field(menu,'Menú o lo que se servirá',1600,lines:3),if(widget.item==null)_field(steps,'Preparativos, uno por renglón',4000,lines:4)],
  _field(details,'Indicaciones y comentarios',1600,lines:3),
  if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:const TextStyle(color:Colors.orangeAccent))),
  FilledButton.icon(key:const ValueKey('personal-save'),onPressed:_busy?null:_save,icon:const Icon(Icons.check_rounded),label:Text(_busy?'Guardando…':'Guardar actividad')),
  TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('Cancelar')),
 ])))));
 Widget _field(TextEditingController c,String label,int max,{int lines=1,bool number=false,Key? key})=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:TextField(key:key,contextMenuBuilder:privacyTextMenu,controller:c,enabled:!_busy,maxLength:max,minLines:lines,maxLines:lines+2,keyboardType:number?TextInputType.number:TextInputType.multiline,decoration:InputDecoration(labelText:label,alignLabelWithHint:lines>1,counterText:'')));
}

class PersonalPlanningAdminScreen extends StatelessWidget{
 final UserModel user;
 const PersonalPlanningAdminScreen({super.key,required this.user});
 @override Widget build(BuildContext context){if(user.rol!=AppRoles.admin)return const Scaffold(body:Center(child:Text('Solo Administración.')));
 return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Organizar al personal')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('usuarios').snapshots(),builder:(c,s){
  if(s.hasError)return const Center(child:Text('No se pudo cargar el personal. Revisa conexión y permisos.'));
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final people=s.data!.docs.where((d)=>d.data()['panelPersonal']==true&&d.data()['rol']==AppRoles.trabajador&&d.data()['activo']!=false).toList();
  return ListView(padding:const EdgeInsets.all(20),children:[const Text('Su día, bien organizado',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),const SizedBox(height:12),const Text('Asigna comidas, compras, eventos y tareas. Cada persona verá únicamente su propio plan.',style:TextStyle(color:Colors.white60,height:1.5)),if(people.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:22),child:Text('Primero entra a Administrar perfiles, selecciona a la persona y activa Panel personal · Mi día. No cambia su rol ni su asistencia.')),for(final p in people)Card(child:ListTile(leading:const StiloOrbitIcon(icon:Icons.person_rounded,color:Color(0xFFFFB876),active:true),title:Text(p.data()['nombre']??'Personal'),subtitle:const Text('Comidas · eventos · compras · pendientes'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>PersonalDayScreen(user:user,targetId:p.id,targetName:p.data()['nombre']?.toString())))))]);
 }));}
}
