import 'package:flutter/material.dart';
import '../models/seguimiento_cotizaciones_model.dart';
import '../services/seguimiento_cotizaciones_service.dart';

class SeguimientoCotizacionesProvider extends ChangeNotifier {
  final SeguimientoCotizacionesServicio _servicio = SeguimientoCotizacionesServicio();

  // Lista local para mostrar en la interfaz
  List<SeguimientoCotizacionModel> _cotizacionesPendientes = [];
  List<SeguimientoCotizacionModel> get cotizacionesPendientes => _cotizacionesPendientes;

  // Bandera para mostrar un indicador de carga durante el guardado
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SeguimientoCotizacionesProvider() {
    _inicializarStream();
  }

  void _inicializarStream() {
   
    _servicio.escucharCotizacionesPendientes().listen(
      (cotizaciones) {
        _cotizacionesPendientes = cotizaciones;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("Error al escuchar las cotizaciones: $error");
      },
    );
  }

  // Método que la IU llamará cuando el admin presione "Aceptar Cotización"
  Future<bool> aceptarCotizacion(SeguimientoCotizacionModel cotizacion) async {
    _isLoading = true;
    notifyListeners(); // Congela la pantalla / muestra spinner

    try {
      await _servicio.aceptarYConvertirCotizacion(cotizacion);
      
      _isLoading = false;
      notifyListeners();
      return true; // Retorna true si todo fue un éxito
    } catch (e) {
      debugPrint("Error al procesar la cotización: $e");
      
      _isLoading = false;
      notifyListeners();
      return false; // Retorna false para que la IU muestre un SnackBar de error
    }
  }

  // Método para agregar una nota nueva desde la IU
  Future<void> agregarNota(String cotizacionId, NotaSeguimiento nuevaNota) async {
    try {
      await _servicio.agregarNotaSeguimiento(cotizacionId, nuevaNota);
    } catch (e) {
      debugPrint("Error al agregar nota: $e");
    }
  }


Future<void> agregarNuevaCotizacion(SeguimientoCotizacionModel cotizacion) async {
  try {
    await _servicio.crearCotizacion(cotizacion);
  } catch (e) {
    debugPrint("Error al crear cotización: $e");
  }
}

}