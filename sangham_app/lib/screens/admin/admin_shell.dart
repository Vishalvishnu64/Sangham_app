import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'admin_dashboard.dart';
import 'members_screen.dart';
import 'attendance_manager.dart';
import 'history_screen.dart';
import '../auth/login_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final _pages = const [
    AdminDashboard(),
    MembersScreen(),
    AttendanceManager(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF1A3C34),
            selectedItemColor: const Color(0xFFF5A623),
            unselectedItemColor: Colors.white54,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_rounded),
                label: 'Members',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_rounded),
                label: 'Attendance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
