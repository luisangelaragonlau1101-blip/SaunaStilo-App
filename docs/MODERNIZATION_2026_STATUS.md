# Modernización integral 2026 — entrega de desarrollo

Fecha: 26 de noviembre de 2026. Rama: `codex/modernizacion-integral-2026`.

La ampliación empresarial está implementada en esta rama y conectada mediante servicios de Firebase. Todavía no está publicada en producción: el entorno carece de una sesión válida de despliegue Firebase. No debe promoverse el cliente antes de sus servicios y reglas. La versión pública conserva la mejora independiente de arranque, commit `a392d5288b5a2de7f138a63f5cd1e40a6d684720`, verificada por GitHub Actions 45740450713.

## Funciones integradas

| Área | Implementación |
| --- | --- |
| Arranque | Inicialización imprescindible en paralelo, sin duración mínima del logo; perfil activo verificado en servidor; esqueleto útil y carga independiente por sección; módulos empresariales diferidos. Las actualizaciones de caché no pueden elevar permisos. |
| Inicio | Jornada y actividades prioritarias para trabajadores; entregas y pendientes empresariales para Administración; instalaciones asignadas y avance personal. El blog y otros módulos siguen accesibles. |
| Tareas y proyectos | Iniciar, fotografiar, entregar para revisión; evidencia obligatoria cuando se configura; aprobar, pedir correcciones y reabrir; tareas generales, compartidas y por proyecto sobre la colección existente. Los proyectos conservan sus grupos e integrantes. El progreso visual se deriva de actividades aprobadas, sin alterar silenciosamente estados históricos. |
| Finanzas | Libro existente `gestion_movimientos`, cuentas bancarias y efectivo, transferencias propias sin ingreso duplicado, ingresos/cobros parciales, gastos rápidos con foto, facturas, XML/PDF privados, presupuestos, reservas, conciliación CSV, informes PDF/CSV y rentabilidad por proyecto. Los movimientos anteriores se clasifican expresamente sin duplicarlos. |
| Fiscal estimado | IVA por importe efectivamente pagado/cobrado, tasas configuradas, tratamiento fiscal, retenciones y acreditamiento confirmado; ISR proporcionado por Contabilidad después de confirmar el régimen; declarado, pagado y reservado separados. No calcula nómina ni emite CFDI. |
| Compras | Solicitar con proyecto/proveedor/foto, aprobar, rechazar, solicitar información, avisar al solicitante y convertir la aprobación en una sola compra. Alerta de presupuesto. |
| Instalaciones | Crear órdenes y plantillas, responsables y fechas, checklist editable con cantidades reales, fotos, faltantes y autorización. La preparación aparece como actividad existente en Inicio. |
| Firmas e inventario | Firmas propias con dedo, identidad/fecha/huella del registro; validación administrativa si coincide quien entrega y recibe; PDF privado con firmas y fotografías; préstamo temporal desde inventario o Cajita; traspasos de custodia, incidencias, devolución, conciliación de faltantes y cierre. Transacciones e identificadores estables evitan dobles reservas/devoluciones. |
| Jornada | Lectura directa y progresiva de Firebase; entrada, comida, regreso y salida; pausas temporales; ubicación verificada o permiso manual explícito; hora de servidor; recibos locales antiguos conservados y separados de registros oficiales. |
| Notificaciones | Centro existente, destinos a tarea/orden/facturas/compras/jornada/cumpleaños, preferencias por categoría, comprobación de permisos actuales para avisos privados; recordatorios de servidor con deduplicación y cancelación al registrar; sin creación automática de asistencia. |
| Avance | Totales administrativos y personales, gráficos semanales/mensuales, rachas con descansos y permisos, una actividad canónica aunque sea compartida y sin clasificación pública obligatoria. |
| Personalización | Tema actual y opción original conservados; decoraciones opcionales de diciembre, Año Nuevo y aniversario configurable, sin capturar toques; respetan movimiento reducido y se pausan en segundo plano. Cumpleaños con consentimiento y migración privada del histórico. |
| Permisos | Pantalla administrativa de capacidades empresariales, autorización manual y horario de comida; validación en callables, Firestore y Storage. Cuentas inactivas o sin perfil bloqueadas para datos y archivos de la empresa; documentos fiscales inmutables y auditoría protegida. |

## Verificación y alcance

- Flutter: **152 pruebas aprobadas**, cero fallidas. Recuento, comandos y alcance en `validation/modernization-2026-checks.json`.
- Node: **136 pruebas aprobadas**.
- Firestore/Storage: **60 pruebas aprobadas** de permisos, tareas, evidencias, inventario, transacciones reales aisladas, privacidad histórica, permisos administrativos y recordatorios sin asistencia automática.
- La prueba de gasto recorre captura de imagen simulada, carga, solicitud de factura y recuperación tras fallo de red, reutilizando operación y archivo. No equivale a probar la cámara física.
- Compilación JavaScript release correcta. La comprobación opcional Wasm sigue señalando incompatibilidades anteriores de plugins; no se anuncia soporte Wasm.
- Analizador ejecutado con advertencias no fatales: sin errores y con 1077 observaciones (lints y advertencias pendientes); no se presenta como análisis limpio.
- Acta de ejemplo validada con `pdfinfo` y `pdfimages`: PDF A4 con firmas vectoriales e imagen JPEG incrustada.
- Mediciones reales de arranque y sus límites en [PERFORMANCE_2026.md](PERFORMANCE_2026.md). Ninguna medición anónima representa el inicio autenticado de empleados.

Las pruebas usan exclusivamente proyectos `demo-*`, datos ficticios y servicios inyectados. No se crearon compras, asistencias, firmas ni notificaciones de prueba en producción. Los logs locales están en `/workspace/.cloud-setup/`.

## Pendiente para disponibilidad real

1. Autenticar Firebase y desplegar las funciones, reglas e índices; confirmar su disponibilidad antes del cliente. La autorización del usuario ya existe; falta la credencial operativa del entorno, no una nueva aprobación.
2. Revisar las reglas remotas y conservar cualquier cambio hecho directamente en la consola antes de reemplazarlas. El entorno no pudo leer la versión remota por falta de autenticación.
3. Ejecutar la migración privada de cumpleaños desde Administración y configurar las capacidades reales. Hasta migrar, los campos históricos de cumpleaños aún presentes en documentos generales no se vuelven privados por ocultarlos en la interfaz.
4. Validar con cuentas autorizadas y dispositivos físicos: sesión de trabajador/maestro/administrador, cámara, micrófono, firma, GPS, FCM con la app cerrada y red lenta; configurar APNs/VAPID/permisos según plataforma. No se han validado cobros ni datos fiscales reales.
5. La app nativa iOS tiene una configuración anterior de otro proyecto (`saunastylo-dbd87`), mientras web y Android usan `saunastiloapp-17e15`; falta obtener la configuración iOS correcta de Firebase antes de certificar una versión nativa. No se inventaron identificadores ni se trasladaron sus datos. Este entorno Linux no tiene Xcode ni SDK Android configurado; no se entrega una compilación nativa probada.
6. La verificación CFDI actual comprueba estructura, UUID, RFC, importes, IVA y duplicados; **no** consulta vigencia/cancelación del SAT ni sustituye la revisión contable. CFDI de otras monedas, notas de crédito, complementos y tratamientos mixtos en un solo comprobante requieren revisión específica de Contabilidad.
7. El costo de proyecto es un estimado sobre pagos y compras asociados. El consumo de madera/equipos queda en el inventario y sus actas; su valoración monetaria no se inventa si no hay un costo registrado/estimado para ese proyecto.

Archivos: [MODERNIZATION_2026_FILES.md](MODERNIZATION_2026_FILES.md). Publicación: [MODERNIZATION_2026_DEPLOYMENT.md](MODERNIZATION_2026_DEPLOYMENT.md).
