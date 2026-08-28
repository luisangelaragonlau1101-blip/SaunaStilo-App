import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sauna_model.dart';
class SaunaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener lista 
  Stream<List<Sauna>> getSaunas() {
    return _db.collection('cat_saunas').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Sauna.fromFirestore(doc)).toList());
  }
}