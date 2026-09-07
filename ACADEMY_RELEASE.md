# Sauna Stilo 3.3 · constancia, retos e idiomas

## Inicio
Racha laboral registrada y reconocimientos otorgados visibles bajo el saludo, junto con XP de idiomas y acceso directo a Stilo Aprende. Para Administración se muestra la mejor secuencia registrada del equipo, no asistencia propia. Mantiene ALERTA GENERAL, logo y estética nocturna negro/vino con acentos distintos. La racha laboral sigue calculándose con los registros existentes; no inventa días ni cambia las reglas de asistencia. Los logros completos siguen en Perfil.

## Juegos
Los tres tableros de Pausa Stilo se conservan y se añaden **17 categorías de retos por rondas**: adivinanzas, quiz general, suma, resta, multiplicación, reparto, series, número mayor, intruso, palabras revueltas, alfabeto, conteo, reloj, cambio exacto, inglés, francés y memoria fugaz. Son 20 opciones locales en total; los 17 retos usan preguntas de selección, no se presentan como 17 tableros distintos. Los bancos de preguntas son finitos y hay desafíos numéricos generados para variar las partidas.

Rondas de 3, 5 o 10 preguntas por jugador, de 1 a 4 personas, por turnos en **un mismo teléfono/tableta**. Marcador, respuesta explicada, ganador/empate y guardado local. No apuestas, compras, anuncios ni recompensas laborales. Funcionan sin Wi-Fi/datos después de descargar los archivos de la web o instalar el APK. No se implementó Bluetooth ni juego entre varios teléfonos sin conexión.

## Stilo Aprende
24 lecciones introductorias: 12 inglés, 12 francés. Cada una incluye 6 palabras/expresiones, explicación inicial y 12 ejercicios de reconocimiento en ambos sentidos: 144 pares de traducción y 288 ejercicios base. 80% para aprobar/desbloquear la siguiente, repaso de errores, felicitación, mejor resultado y 60 XP una sola vez por lección aprobada. Repetir no multiplica XP; una práctica aprobada puede sostener la racha diaria. Rachas separadas por idioma y calculadas con el día del dispositivo; no son logros de asistencia.

El progreso es **local por cuenta y dispositivo**, con una identidad de invitado separada al entrar desde Juegos. No se sincroniza entre teléfonos ni implica certificación/fluidez o equivalencia a un curso completo de Duolingo. El curso textual funciona offline; escuchar utiliza la voz del sistema si está disponible. Algunas voces requieren descarga o Internet: no se promete pronunciación offline en todos los equipos. No evalúa automáticamente la pronunciación del alumno ni cambia la voz de la IA.

## Protección real, no absoluta
El APK Android nuevo fija FLAG_SECURE para todas las cuentas y pantallas Flutter de Sauna Stilo y lo restablece al reanudar. La política no puede desactivarse desde un perfil de esta versión. Se mantiene un aviso cuando el puente de protección no confirma. Se eliminan los menús de copiar/cortar/compartir en los campos y la selección de mensajes/notas, conservando la edición y el pegado. Los reportes no se envían a la hoja de compartir del sistema. Las evidencias se abren en un visor interno de imágenes, video o PDF sin botones de imprimir/compartir; archivos no compatibles permanecen guardados sin exportarse.

Chrome/Safari no permiten impedir capturas del sistema. Las restricciones de copiar/guardar de la web solo evitan las acciones normales de la app: no resisten herramientas de desarrollo, extensiones, dispositivos modificados ni fotografías con otra cámara. Las ventanas de otras apps, proveedores integrados e información ya mostrada en notificaciones no están protegidas por la ventana Flutter. Se conservan enlaces públicos a redes/música y las salas de llamadas existentes; no se reenvían archivos privados mediante ellas. No se borran documentos ni se reescriben reglas o enlaces históricos. Esto no es DRM ni una garantía de impedir toda extracción.

## Activación y alcance
No se modifican datos de empresa, Firebase Rules, Cloud Functions, permisos de voz, facturación, cuentas ni Spotify. Los pendientes de activación de permisos de versiones anteriores continúan separados. Los nuevos retos y el aprendizaje local no necesitan Firebase ni una clave IA.

APK: prueba interna, no Google Play, firma de desarrollo y sin aceptación física en dispositivos. No desinstalar versiones previas con datos locales pendientes. Las pruebas de CI y navegador se deben registrar con su resultado real, no inferir éxito de este documento.

Fuentes técnicas para los límites: Android Developers, “Detect when users take device screenshots” (FLAG_SECURE); documentación oficial Flutter de selección; API del paquete flutter_tts 4.2.5. El currículo y las adivinanzas se redactaron para esta app; no se copia la marca, mascota ni el contenido de Duolingo.
