import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String userId;
  const AttendanceCalendarScreen({super.key, required this.userId});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, String> _attendanceMap = {};
  int _totalPresent = 0;
  int _totalAbsent = 0;
  int _consistency = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserAttendance(
        widget.userId,
        month: _focusedDay.month,
        year: _focusedDay.year,
      );

      final records = data['records'] as List? ?? [];
      final map = <DateTime, String>{};
      for (var record in records) {
        final date = DateTime.tryParse(record['date'] ?? '');
        if (date != null) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          map[normalizedDate] = record['status'] ?? 'absent';
        }
      }

      setState(() {
        _attendanceMap = map;
        _totalPresent = data['stats']?['totalPresent'] ?? 0;
        _totalAbsent = data['stats']?['totalAbsent'] ?? 0;
        _consistency = data['stats']?['consistency'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Attendance'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Consistency Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A5C3A), Color(0xFF0D3B25)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'CONSISTENCY',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_consistency%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Calendar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime(2024, 1, 1),
                      lastDay: DateTime(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        _loadAttendance();
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFF1A5C3A).withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF1A5C3A),
                          shape: BoxShape.circle,
                        ),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3C34),
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final normalizedDay =
                              DateTime(day.year, day.month, day.day);
                          final status = _attendanceMap[normalizedDay];
                          if (status != null) {
                            return Positioned(
                              bottom: 4,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: status == 'present'
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFE53935),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Monthly Summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3C34),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SummaryItem(
                          icon: Icons.check_circle,
                          label: 'Present',
                          value: '$_totalPresent Days',
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 10),
                        _SummaryItem(
                          icon: Icons.cancel,
                          label: 'Absent',
                          value: '$_totalAbsent Days',
                          color: const Color(0xFFE53935),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
