/// Included user manual. These answers never claim to be AI or to query live data.
class LocalGuide {
  static String? answer(String question, String role) {
    var q = question.toLowerCase();
    const accented = 'áéíóúüñ';
    const plain = 'aeiouun';
    for (var i = 0; i < accented.length; i++) { q = q.replaceAll(accented[i], plain[i]); }
    if (!RegExp(r'\b(como|donde|ayuda|guia|instrucciones)\b').hasMatch(q)) return null;
    if (RegExp(r'\b(internet|noticias|busca|web)\b').hasMatch(q)) return null;
    if (q.contains('voz') || q.contains('grabo')) {
      if (role != 'admin') return 'Solo Administración configura la voz oficial. Puedes escuchar respuestas con el botón de altavoz en Sauna IA o Guía. La voz sintética no es un mensaje personal del administrador.';
      return '1. Vuelve a Inicio y busca “Mi voz”.\n2. En Estudio de voz, graba el consentimiento indicado y una muestra de 3 a 10 segundos.\n3. Escucha ambas grabaciones y toca “CREAR MI VOZ”.\n4. Cuando el servidor la confirme, toca “PROBAR MI VOZ”.\nSe requiere que Firebase esté publicado y Google autorice Instant Custom Voice. Las muestras se envían a ese proveedor solo al crear la voz.';
    }
    if (RegExp(r'\b(entrada|salida|comida|jornada|asistencia|regreso)\b').hasMatch(q)) {
      if (role == 'admin') return '1. En Inicio busca “Asistencias”.\n2. Selecciona al integrante y revisa sus registros y solicitudes.\n3. Confirma cualquier ajuste desde esa pantalla.\nLa guía no registra ni modifica horas por sí sola.';
      return '1. En Inicio abre “Asistencia” o “Tu jornada”.\n2. Elige el registro correspondiente: entrada, comida, regreso o salida.\n3. Autoriza la ubicación cuando se solicite y comprueba el resultado en pantalla.\nLa comida está prevista a las 15:00; una solicitud pendiente requiere autorización de Administración. La guía no registra tu asistencia automáticamente.';
    }
    if (q.contains('herramienta') || q.contains('inventario') || q.contains('cajita')) {
      return '1. En Inicio busca “Inventario”.\n2. Busca la herramienta y abre su detalle.\n3. Usa la opción de solicitud disponible para tu rol y verifica su estado antes de retirar el material.\n4. Consulta las herramientas asignadas en “Mi cajita” o “Cajitas”.\nLa disponibilidad se verifica en el inventario; esta guía no confirma existencias ni autoriza préstamos.';
    }
    if (RegExp(r'\b(mensaje|mensajes|chat|llamada|videollamada)\b').hasMatch(q)) {
      return '1. En Inicio toca “Chat” o “Mensajes”.\n2. Elige al integrante del equipo.\n3. Escribe el mensaje o utiliza las opciones de adjuntos.\n4. Para una llamada, toca el icono de teléfono o cámara y entra a la reunión.\nLos avisos requieren permiso en cada dispositivo. Las llamadas actuales usan una sala externa, no un timbrado telefónico nativo.';
    }
    if (q.contains('proyecto') || q.contains('evidencia') || q.contains('avance')) {
      return '1. En Inicio busca “Proyectos”.\n2. Abre un proyecto al que tengas acceso.\n3. En su actividad registra el avance y adjunta la evidencia.\n4. Espera la confirmación de guardado antes de salir.\nSolo aparecen las opciones permitidas para tu rol; esta guía no modifica proyectos.';
    }
    if (q.contains('cliente') || q.contains('cotizacion') || q.contains('venta')) {
      if (role != 'admin') return 'Clientes, cotizaciones y ventas son módulos de Administración. Solicita la información que necesites al administrador; tu cuenta conserva sus permisos actuales.';
      return 'En Inicio usa el buscador para abrir “Clientes”, “Cotizaciones” o “Ventas”. Selecciona el registro y revisa sus detalles antes de guardar cambios. Sauna IA puede ayudarte a redactar; la guía no confirma pagos ni modifica importes.';
    }
    if (q.contains('aviso') || q.contains('notificacion')) {
      return '1. En Inicio abre el centro de conexión y toca “Activar avisos”.\n2. Concede permiso en este dispositivo. En iPhone abre la app desde el icono agregado a la pantalla de inicio.\n3. Revisa Silencio y Enfoque en el teléfono.\n4. Prueba con otra cuenta y la pantalla bloqueada.\nRegistrar el dispositivo no confirma la entrega: también debe estar publicado el servidor de notificaciones.';
    }
    return null;
  }
}
