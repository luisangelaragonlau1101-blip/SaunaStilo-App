{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Carga el motor gráfico desde el mismo sitio. Esto evita pantallas vacías
    // cuando una red móvil o un filtro bloquea el CDN externo de CanvasKit.
    canvasKitBaseUrl: 'canvaskit/'
  }
});
