import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class AttendanceManager extends StatefulWidget {
  const AttendanceManager({super.key});

  @override
  State<AttendanceManager> createState() => _AttendanceManagerState();
}

class _AttendanceManagerState extends State<AttendanceManager> {
  List<UserModel> _members = [];
  final Map<String, String> _attendanceMap = {}; // userId -> present/absent
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final membersData = await ApiService.getMembers();
      final members = (membersData['members'] as List)
          .map((m) => UserModel.fromJson(m))
          .toList();

      // Default all to present
      for (var m in members) {
        _attendanceMap[m.id] = 'present';
      }

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);
    try {
      final records = _attendanceMap.entries
          .map((e) => {'userId': e.key, 'status': e.value})
          .toList();

      await ApiService.markBulkAttendance(
        records,
        _selectedDate.toIso8601String(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Attendance marked for ${records.length} members!'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark attendance')),
      );
    }
    setState(() => _isSubmitting = false);
  }

  int get _presentCount =>
      _attendanceMap.values.where((v) => v == 'present').length;

  int get _absentCount =>
      _attendanceMap.values.where((v) => v == 'absent').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Total',
                        value: '${_members.length}',
                        color: const Color(0xFF1A3C34),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[200],
                      ),
                      _StatColumn(
                        label: 'Present',
                        value: '$_presentCount',
                        color: const Color(0xFF4CAF50),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[200],
                      ),
                      _StatColumn(
                        label: 'Absent',
                        value: '$_absentCount',
                        color: const Color(0xFFE53935),
                      ),
                    ],
                  ),
                ),

                // Mark all buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              for (var m in _members) {
                                _attendanceMap[m.id] = 'present';
                              }
                            });
                          },
                          icon: const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50), size: 18),
                          label: const Text('All Present',
                              style: TextStyle(color: Color(0xFF4CAF50))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF4CAF50)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              for (var m in _members) {
                                _attendanceMap[m.id] = 'absent';
                              }
                            });
                          },
                          icon: const Icon(Icons.cancel,
                              color: Color(0xFFE53935), size: 18),
                          label: const Text('All Absent',
                              style: TextStyle(color: Color(0xFFE53935))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE53935)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Member list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _members.length,
                    itemBuilder: (_, i) {
                      final member = _members[i];
                      final status = _attendanceMap[member.id] ?? 'present';
                      final isPresent = status == 'present';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPresent
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                : const Color(0xFFE53935).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresent
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                : const Color(0xFFE53935).withValues(alpha: 0.1),
                            child: Icon(
                              isPresent ? Icons.check : Icons.close,
                              color: isPresent
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                            ),
                          ),
                          title: Text(
                            member.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(member.phone,
                              style: const TextStyle(fontSize: 12)),
                          trailing: Switch(
                            value: isPresent,
                            onChanged: (v) {
                              setState(() {
                                _attendanceMap[member.id] =
                                    v ? 'present' : 'absent';
                              });
                            },
                            activeColor: const Color(0xFF4CAF50),
                            inactiveThumbColor: const Color(0xFFE53935),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Submit button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Save Attendance',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
