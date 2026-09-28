import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PayrollRecognitions extends StatelessWidget {
  final String profileId;
  const PayrollRecognitions({super.key, required this.profileId});
  @override Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('usuarios').doc(profileId).snapshots(), builder: (c,s) {
    if (s.hasError) return const Text('No se pudieron cargar las insignias.');
    if (!s.hasData) return const SizedBox.shrink();
    final raw = s.data!.data()?['insigniasAdmin'];
    final badges = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Reconocimientos · no modifican el pago', style: TextStyle(color: Colors.white60, fontSize: 12)),
      if (badges.isEmpty) const Text('Sin insignias otorgadas todavía.'),
      Wrap(spacing: 6, children: [for (final badge in badges) Chip(avatar: const Icon(Icons.military_tech_outlined, size: 18), label: Text(badge['nombre']?.toString() ?? 'Reconocimiento'))]),
    ]));
  });
}
