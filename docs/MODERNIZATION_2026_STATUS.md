# Modernización integral 2026 — estado de desarrollo

Rama: codex/modernizacion-integral-2026. Esta actualización no está desplegada.

Implementación en curso: arranque sin transición mínima, validación del perfil en servidor antes de mostrar áreas privadas, inicio por secciones independientes, tareas rápidas/compartidas, servicios financieros y órdenes de instalación, productividad, preferencias y avisos de servidor.

Integración realizada: enterpriseFinance y enterpriseInstallations exportados desde functions/app.js; accesos a finanzas/compras/órdenes desde el catálogo y administración financiera desde Gestión de la empresa. Formularios adaptados a FilePicker 12. Detalle de instalaciones actualmente permite consulta; creación/checklists/firmas/devoluciones desde interfaz todavía requieren completar la integración, aunque existen operaciones en el backend.

No afirmar implementación integral terminada: faltan verificar todos los flujos financieros, terminar interacción de instalaciones, integrar lectura inmediata de asistencia (sin AppDeploy), permisos/preferencias en pantalla, enlaces de notificaciones, migración privada de cumpleaños y validación completa de reglas/Storage/concurrencia. Las expectativas de pruebas existentes se actualizaron para el inicio unificado, la ruta explícita Firebase y evidencia obligatoria; se preservaron comprobaciones de identidad, permisos y atomicidad. Se validaron 124 pruebas Node y 23 pruebas aisladas de Firestore (incluida prohibición de contadores o archivos ficticios como evidencia). Flutter: 129 pruebas aprobadas, analyze sin errores, compilación web release correcta. La medición final de rendimiento aún está pendiente. Ver PERFORMANCE_2026.md para baseline reproducible.

Antes de publicar: completar esos flujos; ejecutar analyze, Flutter, Node, emuladores Firestore/Storage, compilación web, comparación antes/después y pruebas de navegación móvil; desplegar backend/reglas/índices y verificar disponibilidad antes del cliente. Nunca cargar datos de prueba en producción. No eliminar historial.

Acceso externo: Firebase CLI projects:list devolvió Failed to authenticate. Hace falta una identidad autorizada de despliegue configurada de forma segura en el entorno; no pegar secretos en el chat. La autorización del usuario para implementar/publicar ya existe. La presencia de variables o un borrador de entorno no confirma autenticación ni despliegue.

Código subido a GitHub en la rama de desarrollo. Eso no publica la aplicación web ni despliega Firebase. La CLI de Firebase volvió a rechazar autenticación al preparar la publicación. No promover a main antes de desplegar y verificar los servicios nuevos: el cliente ya utiliza enterpriseAttendance.
