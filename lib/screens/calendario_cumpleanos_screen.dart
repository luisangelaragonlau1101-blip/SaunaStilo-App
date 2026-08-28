import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart'; // <-- Asegúrate de que la ruta sea correcta

class CalendarioCumpleanosScreen extends StatefulWidget {
  const CalendarioCumpleanosScreen({Key? key}) : super(key: key);

  @override
  State<CalendarioCumpleanosScreen> createState() => _CalendarioCumpleanosScreenState();
}

class _CalendarioCumpleanosScreenState extends State<CalendarioCumpleanosScreen> {
  late final ValueNotifier<List<UserModel>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Ahora el mapa guarda directamente objetos UserModel
  Map<DateTime, List<UserModel>> _cumpleanos = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _cargarCumpleanos();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _cargarCumpleanos() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      final Map<DateTime, List<UserModel>> nuevosCumples = {};
      final int anioActual = DateTime.now().year;

      for (var doc in snapshot.docs) {
        // Usamos tu factory para convertir el documento a UserModel
        final usuario = UserModel.fromFirestore(doc);
        
        if (usuario.cumpleanos != null) {
          DateTime fechaNac = usuario.cumpleanos!;
          
          // Proyectamos el cumpleaños al año actual (y al próximo)
          DateTime cumpleEsteAnio = DateTime(anioActual, fechaNac.month, fechaNac.day);
          DateTime cumpleProximoAnio = DateTime(anioActual + 1, fechaNac.month, fechaNac.day);

          // Agregamos el usuario a la fecha de este año
          if (nuevosCumples[cumpleEsteAnio] != null) {
            nuevosCumples[cumpleEsteAnio]!.add(usuario);
          } else {
            nuevosCumples[cumpleEsteAnio] = [usuario];
          }

          // Agregamos el usuario a la fecha del próximo año
          if (nuevosCumples[cumpleProximoAnio] != null) {
            nuevosCumples[cumpleProximoAnio]!.add(usuario);
          } else {
            nuevosCumples[cumpleProximoAnio] = [usuario];
          }
        }
      }

      setState(() {
        _cumpleanos = nuevosCumples;
        _isLoading = false;
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error al cargar cumpleaños: $e");
    }
  }

  List<UserModel> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _cumpleanos[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Text(
          "Cumpleaños del Equipo",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3399)))
          : Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TableCalendar<UserModel>(
                    locale: 'es_ES',
                    availableCalendarFormats: const {
    CalendarFormat.month: 'Mes',
    CalendarFormat.twoWeeks: '2 semanas',
    CalendarFormat.week: 'Semana',
  },
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    eventLoader: _getEventsForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() => _calendarFormat = format);
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    headerStyle: HeaderStyle(
                      titleTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      formatButtonVisible: true,
                      formatButtonTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFF3399)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: GoogleFonts.inter(color: Colors.white70),
                      weekendStyle: GoogleFonts.inter(color: const Color(0xFFFF3399)),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: GoogleFonts.inter(color: Colors.white),
                      weekendTextStyle: GoogleFonts.inter(color: Colors.white70),
                      outsideTextStyle: GoogleFonts.inter(color: Colors.white24),
                      todayDecoration: BoxDecoration(
                        color: const Color(0xFFFF3399).withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFFFF3399),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Color(0xFFFFDE21),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ValueListenableBuilder<List<UserModel>>(
                    valueListenable: _selectedEvents,
                    builder: (context, value, _) {
                      if (value.isEmpty) {
                        return Center(
                          child: Text(
                            "Ningún cumpleaños en esta fecha.",
                            style: GoogleFonts.inter(color: Colors.white38),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final usuario = value[index];
                          // Calculamos la edad usando la fecha real de nacimiento
                          final int edad = DateTime.now().year - usuario.cumpleanos!.year;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFF3399).withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF3399).withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFFFF3399).withOpacity(0.2),
                                  backgroundImage: (usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty)
                                    ? NetworkImage(usuario.fotoUrl!) 
                                    : null,
                                  child: (usuario.fotoUrl == null || usuario.fotoUrl!.isEmpty)
                                    ? const Icon(Icons.cake_rounded, color: Color(0xFFFF3399))
                                    : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        usuario.nombre,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${usuario.rol.toUpperCase()} • Cumple $edad años",
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.celebration_rounded, color: Color(0xFFFFDE21), size: 28),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}