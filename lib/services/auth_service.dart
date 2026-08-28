import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'push_notifications_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener el usuario de Firebase Auth
  Stream<User?> get userStream => _auth.authStateChanges();

  // Iniciar Sesión
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Cerrar Sesión
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      await PushNotificationsService().deactivateFor(user.uid);
    }
    await _auth.signOut();
  }

  // Obtener los datos del usuario desde Firestore (para saber su rol)
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print("Error al obtener datos del usuario: $e");
    }
    return null;
  }

  // Registrar un usuario nuevo (Opcional por si quieres probar la creación desde la app hoy)
  Future<void> registerUser({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    DateTime? cumpleanos,
  }) async {
    UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    
    UserModel nuevoUsuario = UserModel(
      id: res.user!.uid,
      nombre: nombre,
      correo: email,
      rol: rol,
      cumpleanos: cumpleanos,
      fechaRegistro: DateTime.now(),
    );

    await _db.collection('usuarios').doc(res.user!.uid).set(nuevoUsuario.toFirestore());
  }
}
