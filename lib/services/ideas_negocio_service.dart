import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/idea_negocio_model.dart';

class IdeasNegocioService {
  final CollectionReference _ideasCollection =
      FirebaseFirestore.instance.collection('ideas_lineas_negocio');

  // 1. CREAR UNA NUEVA IDEA
  Future<void> crearIdea(IdeaNegocioModel idea) async {
    try {
      await _ideasCollection.add(idea.toMap());
    } catch (e) {
      print("Error en IdeasNegocioService (crearIdea): $e");
      rethrow;
    }
  }

  // 2. OBTENER TODAS LAS IDEAS EN TIEMPO REAL (STREAM)
  // Ideal para la pantalla de listado
  Stream<List<IdeaNegocioModel>> getIdeasStream() {
    return _ideasCollection
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return IdeaNegocioModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // 3. ACTUALIZAR EL ESTATUS DE LA IDEA GENERAL
  // Ej: De 'planeacion' a 'desarrollo'
  Future<void> actualizarEstatusIdea(String ideaId, String nuevoEstatus) async {
    try {
      await _ideasCollection.doc(ideaId).update({'estatus': nuevoEstatus});
    } catch (e) {
      print("Error en IdeasNegocioService (actualizarEstatusIdea): $e");
      rethrow;
    }
  }

  // 4. ACTUALIZAR EL ESTATUS DE UNA TAREA ESPECÍFICA
  // Como las tareas están en un Array, leemos el documento, 
  // modificamos la lista localmente y la volvemos a subir.
  Future<void> actualizarEstatusTarea(
    String ideaId, 
    int tareaIndex, 
    String nuevoEstatus
  ) async {
    try {
      DocumentSnapshot doc = await _ideasCollection.doc(ideaId).get();
      if (doc.exists) {
        List tareasRaw = doc.get('tareas') as List;
        
        // Modificamos solo la tarea que nos interesa
        tareasRaw[tareaIndex]['estatus'] = nuevoEstatus;

        await _ideasCollection.doc(ideaId).update({
          'tareas': tareasRaw,
        });
      }
    } catch (e) {
      print("Error en IdeasNegocioService (actualizarEstatusTarea): $e");
      rethrow;
    }
  }

  // 5. ELIMINAR IDEA
  Future<void> eliminarIdea(String ideaId) async {
    try {
      await _ideasCollection.doc(ideaId).delete();
    } catch (e) {
      print("Error en IdeasNegocioService (eliminarIdea): $e");
      rethrow;
    }
  }
}