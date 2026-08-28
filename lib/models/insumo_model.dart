import 'package:cloud_firestore/cloud_firestore.dart';

class InsumoModel {
  final String id;
  final String categoria;     // material, herramienta, máquinas
  final String subcategoria;  // material eléctrico, madera...
  final String nombre;
  final String descripcion;
  final int cantidadDisponible;
  final String unidadMedida;
  final int stockMinimo;
  final DateTime ultimaActualizacion;
  final bool esProductoTienda; 
  final double precio;
  final String? imagenUrl; 
  final String? codigoBarras; // 1. NUEVO CAMPO

  InsumoModel({
    required this.id,
    required this.categoria,
    required this.subcategoria,
    required this.nombre,
    required this.descripcion,
    required this.cantidadDisponible,
    required this.unidadMedida,
    required this.stockMinimo,
    required this.ultimaActualizacion,
    required this.esProductoTienda,
    required this.precio,
    this.imagenUrl, 
    this.codigoBarras, // 2. AGREGADO AL CONSTRUCTOR
  });

  factory InsumoModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {}; 
    
    // Protección estricta para la fecha
    DateTime fechaUpdate = DateTime.now();
    if (data['ultima_actualizacion'] != null) {
      if (data['ultima_actualizacion'] is Timestamp) {
        fechaUpdate = (data['ultima_actualizacion'] as Timestamp).toDate();
      } else if (data['ultima_actualizacion'] is String) {
        fechaUpdate = DateTime.tryParse(data['ultima_actualizacion']) ?? DateTime.now();
      }
    }

    // Protección para el precio numérico
    double precioParseado = 0.0;
    if (data['precio'] != null) {
      precioParseado = data['precio'] is num 
          ? (data['precio'] as num).toDouble() 
          : double.tryParse(data['precio'].toString()) ?? 0.0;
    }

    return InsumoModel(
      id: doc.id,
      categoria: data['categoria'] ?? '',
      subcategoria: data['subcategoria'] ?? '',
      nombre: data['nombre'] ?? 'Sin nombre',
      descripcion: data['descripcion'] ?? '',
      cantidadDisponible: (data['cantidad_disponible'] is num) 
          ? (data['cantidad_disponible'] as num).toInt() 
          : int.tryParse(data['cantidad_disponible'].toString()) ?? 0,
      unidadMedida: data['unidad_medida'] ?? '',
      stockMinimo: (data['stock_minimo'] is num) 
          ? (data['stock_minimo'] as num).toInt() 
          : int.tryParse(data['stock_minimo'].toString()) ?? 0,
      ultimaActualizacion: fechaUpdate,
      esProductoTienda: data['es_producto_tienda'] ?? false,
      precio: precioParseado, 
      imagenUrl: data['imagen_url'], 
      codigoBarras: data['codigo_barras'], // 3. MAPEO DESDE FIRESTORE
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoria': categoria,
      'subcategoria': subcategoria,
      'nombre': nombre,
      'descripcion': descripcion,
      'cantidad_disponible': cantidadDisponible,
      'unidad_medida': unidadMedida,
      'stock_minimo': stockMinimo,
      'ultima_actualizacion': Timestamp.fromDate(ultimaActualizacion),
      'es_producto_tienda': esProductoTienda,
      'precio': precio, 
      'imagen_url': imagenUrl, 
      'codigo_barras': codigoBarras, // 4. MAPEO HACIA FIRESTORE
    };
  }
}