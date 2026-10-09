# Interfaz moderna de STILO

La interfaz moderna está activada por defecto. En **Perfil → Mi estilo → Interfaz moderna** se puede volver a la navegación y al inicio originales. La elección se guarda por cuenta en este dispositivo; se conservan el logo, la paleta seleccionada y los permisos existentes.

- En móvil, la navegación usa una barra inferior compacta con la sección activa identificada. En computadora, desde 1000 px, aparece un menú lateral; el contenido mantiene un ancho de lectura cómodo.
- El contenido de cada sección se conserva al redimensionar la ventana. El menú lateral admite desplazamiento en ventanas de poca altura.
- Inicio presenta una cabecera con detalles vino y accesos en tarjetas. Los registros de jornada y las tareas siguen usando sus fuentes existentes; no se agregaron indicadores ficticios.
- Proyectos y tareas usa pestañas agrupadas, accesibles mediante desplazamiento horizontal. Se conservan las acciones de entrega, aprobación y cierre.
- Se unifican títulos, campos, listas, diálogos y hojas de detalle mediante el tema compartido. Las demás paletas y la interfaz original siguen disponibles.
- El acceso conserva el formulario y el proceso de autenticación, con una presentación de marca actualizada.

Validación: 105 pruebas Flutter y 124 pruebas de servicios aprobadas; las nuevas comprobaciones cubren navegación móvil/escritorio, conservación del contenido al redimensionar, pestañas con texto ampliado y persistencia de preferencias por cuenta. El análisis no presenta errores; permanecen avisos existentes del repositorio. Los permisos y reglas de Firebase no cambian en esta actualización.
