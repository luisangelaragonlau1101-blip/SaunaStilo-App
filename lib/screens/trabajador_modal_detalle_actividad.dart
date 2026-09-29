import 'package:flutter/material.dart';
import '../models/actividad_model.dart';
import '../widgets/activity_detail_sheet.dart';

class ModalDetalleActividad extends StatelessWidget {
  final ActividadModel actividad;
  const ModalDetalleActividad({super.key, required this.actividad});
  @override Widget build(BuildContext context) => ActivityDetailSheet(activity: actividad);
}
