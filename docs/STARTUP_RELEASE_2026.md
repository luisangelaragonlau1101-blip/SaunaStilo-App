# Primera publicación de arranque y acceso

Esta publicación parte de main (9b4d6ae), y conserva los servicios, reglas y datos de Firebase existentes. La modernización empresarial completa permanece en codex/modernizacion-integral-2026, commit 02e3756; no se incorpora esa rama a esta publicación.

Cambios: carga paralela de configuración básica; preferencias locales opcionales sin bloquear el acceso; eliminación de la transición de 600 ms y del logo animado; sesión restaurada por Firebase con perfil actual validado en servidor; roles en caché no habilitan áreas privadas; errores o desactivaciones retiran el área privada y cambiar de cuenta descarta la navegación anterior. Inicio muestra las tareas antes de los accesos secundarios.

Validación local: flutter analyze sin errores (avisos existentes), 126 pruebas Flutter y 124 Node aprobadas. Las cinco pruebas nuevas comprueban acceso inmediato sin espera mínima, caché sin elevación de roles, desactivación/error, cambio de cuenta y ausencia de datos anteriores al reintentar.

La compilación web y el flujo de publicación conservan el procedimiento existente de GitHub Pages y Vercel. La CI incluye las nuevas pruebas de acceso. No requiere desplegar funciones ni reglas nuevas.

Los módulos empresariales nuevos siguen pendientes de integración completa y despliegue autenticado; esta publicación no los anuncia como disponibles.
