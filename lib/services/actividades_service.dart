import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actividad_model.dart';

class ActividadesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Colección principal en Firestore
  CollectionReference get _actividadesRef => _db.collection('actividades');

  // 1. Crear una nueva actividad (Acción del Admin)
  Future<void> crearActividad(ActividadModel actividad) async {
    try {
      await _actividadesRef.add(actividad.toJson());
    } catch (e) {
      throw Exception('Error al crear la actividad: $e');
    }
  }

  // 2. Obtener actividades por proyecto
  Stream<List<ActividadModel>> obtenerActividadesPorProyecto(String proyectoId) {
    return _actividadesRef
        .where('proyectoId', isEqualTo: proyectoId) // <-- Solo dejamos el filtro
        .snapshots()
        .map((snapshot) {
      
      // 1. Convertimos los documentos a tu modelo
      List<ActividadModel> lista = snapshot.docs.map((doc) {
        return ActividadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // 2. Ordenamos la lista en Flutter por fecha de inicio (del más antiguo al más nuevo)
      lista.sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

      return lista;
    });
  }

  // 3. Actualizar estatus de la actividad (pendiente, en_progreso, completado)
  Future<void> actualizarEstatusActividad(String actividadId, String nuevoEstatus) async {
    try {
      await _actividadesRef.doc(actividadId).update({
        'estatus': nuevoEstatus,
      });
    } catch (e) {
      throw Exception('Error al actualizar el estatus: $e');
    }
  }

  // 4. Registrar observaciones del Admin (multas, suspensiones, incentivos, etc.)
  Future<void> registrarObservacionesAdmin(String actividadId, String observaciones) async {
    try {
      await _actividadesRef.doc(actividadId).update({
        'observacionesAdmin': observaciones,
      });
    } catch (e) {
      throw Exception('Error al registrar observaciones: $e');
    }
  }

  // 5. Control de Herramientas: Marcar una herramienta como entregada de vuelta
  // Esto deshace la alerta de multa si se entrega a tiempo
  Future<void> devolverHerramienta(String actividadId, int posicionHerramienta) async {
    try {
      DocumentSnapshot doc = await _actividadesRef.doc(actividadId).get();
      if (doc.exists) {
        List<dynamic> herramientas = doc.get('herramientasSolicitadas') ?? [];
        if (posicionHerramienta < herramientas.length) {
          herramientas[posicionHerramienta]['entregada'] = true;
          
          await _actividadesRef.doc(actividadId).update({
            'herramientasSolicitadas': herramientas,
          });
        }
      }
    } catch (e) {
      throw Exception('Error al registrar la devolución de la herramienta: $e');
    }
  }

  // ---------------------------------------------------------
  // FUNCIONES PARA EDICIÓN Y ELIMINACIÓN
  // ---------------------------------------------------------

  // 6. Eliminar actividad
  Future<void> eliminarActividad(String actividadId) async {
    try {
      await _actividadesRef.doc(actividadId).delete();
    } catch (e) {
      throw Exception('Error al eliminar la actividad: $e');
    }
  }

  // 7. Actualizar actividad completa (usado al editar actividades "pendientes")
  Future<void> actualizarActividad(ActividadModel actividad) async {
    try {
      // Usamos update() y le pasamos todo el JSON actualizado
      await _actividadesRef.doc(actividad.id).update(actividad.toJson());
    } catch (e) {
      throw Exception('Error al editar la actividad: $e');
    }
  }
}
