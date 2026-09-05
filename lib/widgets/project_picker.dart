import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';

Future<Proyecto?> elegirProyecto(BuildContext context, UserModel usuario, {String titulo = 'Elige un proyecto'}) {
  final db = FirebaseFirestore.instance;
  final Query<Map<String, dynamic>> query = usuario.rol == AppRoles.admin
      ? db.collection('proyectos')
      : db.collection('proyectos').where('encargados', arrayContains: usuario.id);
  return showModalBottomSheet<Proyecto>(context: context, isScrollControlled: true,
    backgroundColor: const Color(0xFF111012),
    builder: (context) => SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Solo aparecen los proyectos permitidos para tu cuenta.', style: TextStyle(color: Colors.white60))),
        const SizedBox(height: 12),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(), builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('No se pudieron consultar los proyectos. Revisa la conexión y los permisos.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Todavía no tienes proyectos asignados. Administración puede agregarte a uno.')));
          return ListView.builder(itemCount: docs.length, itemBuilder: (context, i) {
            final proyecto = Proyecto.fromFirestore(docs[i]);
            return ListTile(leading: const Icon(Icons.folder_shared_outlined), title: Text(proyecto.titulo),
              trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.pop(context, proyecto));
          });
        })),
      ]),
    )));
}
