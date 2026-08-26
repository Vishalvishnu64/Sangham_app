import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class AttendanceManager extends StatefulWidget {
  const AttendanceManager({super.key});

  @override
  State<AttendanceManager> createState() => _AttendanceManagerState();
}

class _AttendanceManagerState extends State<AttendanceManager> {
  List<UserModel> _members = [];
  // userId -> 'present' | 'absent'. Missing key = not yet marked explicitly.
  final Map<String, String> _attendanceMap = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final membersData = await ApiService.getMembers();
      final members = (membersData['members'] as List)
          .map((m) => UserModel.fromJson(m))
          .toList();

      // Start with nobody marked – every member must be set explicitly
      // (or via the bulk buttons) before submitting.
      final Map<String, String> prefilled = {};

      // For today, prefill from what was already recorded so edits are easy.
      if (_isToday) {
        try {
          final todayData = await ApiService.getTodayAttendance();
          final records = todayData['records'] as List? ?? [];
          for (var r in records) {
            final id = (r['userId']?['_id'] ?? r['userId'])?.toString();
            final status = r['status']?.toString();
            if (id != null &&
                status != null &&
                (status == 'present' || status == 'absent')) {
              prefilled[id] = status;
            }
          }
        } catch (_) {
          // Prefill is best-effort only.
        }
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _attendanceMap.clear();
        _attendanceMap.addAll(prefilled);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  int get _presentCount =>
      _attendanceMap.values.where((v) => v == 'present').length;

  int get _absentCount =>
      _attendanceMap.values.where((v) => v == 'absent').length;

  int get _unmarkedCount {
    final marked = _attendanceMap.keys.toSet();
    return _members.where((m) => !marked.contains(m.id)).length;
  }

  void _markAll(String status) {
    setState(() {
      for (var m in _members) {
        _attendanceMap[m.id] = status;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select attendance date',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _attendanceMap.clear(); // Fresh sheet for the chosen day.
      });
      _loadData(); // Reloads members; prefill applies only for today.
    }
  }

  Future<void> _submitAttendance() async {
    final messenger = ScaffoldMessenger.of(context);
    final unmarked = _unmarkedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Text(
          'Save attendance for ${DateFormat('dd MMM yyyy').format(_selectedDate)}?\n\n'
          '$_presentCount present · $_absentCount absent'
          '${unmarked > 0 ? '\n$unmarked unmarked (will be skipped)' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5C3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      // Only send explicitly marked members.
      final records = _members
          .where((m) => _attendanceMap.containsKey(m.id))
          .map((m) => {'userId': m.id, 'status': _attendanceMap[m.id]})
          .toList();

      if (records.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Nothing to save – mark at least one member')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      await ApiService.markBulkAttendance(
        records,
        _selectedDate.toIso8601String(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved for ${records.length} members!'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
            label: Text(
              DateFormat('dd MMM').format(_selectedDate),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Couldn\'t load members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3C34),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _members.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.group_off,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No members yet',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A3C34)),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Add members first to track attendance',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Date banner
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1A5C3A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event,
                                  size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isToday
                                      ? 'Today, ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                                      : DateFormat('EEEE, dd MMM yyyy')
                                          .format(_selectedDate),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _pickDate,
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Color(0xFF1A5C3A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

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
                                  onPressed: () => _markAll('present'),
                                  icon: const Icon(Icons.check_circle,
                                      color: Color(0xFF4CAF50), size: 18),
                                  label: const Text('All Present',
                                      style: TextStyle(color: Color(0xFF4CAF50))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFF4CAF50)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _markAll('absent'),
                                  icon: const Icon(Icons.cancel,
                                      color: Color(0xFFE53935), size: 18),
                                  label: const Text('All Absent',
                                      style: TextStyle(color: Color(0xFFE53935))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFFE53935)),
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
                          child: RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _members.length,
                              itemBuilder: (_, i) {
                                final member = _members[i];
                                final hasMark =
                                    _attendanceMap.containsKey(member.id);
                                final isPresent =
                                    _attendanceMap[member.id] == 'present';
                                final color = !hasMark
                                    ? Colors.grey
                                    : (isPresent
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFE53935));
                                final statusLabel = !hasMark
                                    ? 'Not Marked'
                                    : (isPresent ? 'Present' : 'Absent');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          color.withValues(alpha: 0.1),
                                      child: Icon(
                                        !hasMark
                                            ? Icons.help_outline
                                            : (isPresent
                                                ? Icons.check
                                                : Icons.close),
                                        color: color,
                                      ),
                                    ),
                                    title: Text(
                                      member.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      '$statusLabel · ${member.phone}',
                                      style: TextStyle(fontSize: 12, color: color),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Absent toggle
                                        IconButton(
                                          tooltip: 'Mark absent',
                                          icon: Icon(
                                            Icons.cancel,
                                            color: hasMark && !isPresent
                                                ? const Color(0xFFE53935)
                                                : Colors.grey.shade300,
                                            size: 30,
                                          ),
                                          onPressed: () {
                                            setState(() =>
                                                _attendanceMap[member.id] =
                                                    'absent');
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        // Present toggle
                                        IconButton(
                                          tooltip: 'Mark present',
                                          icon: Icon(
                                            Icons.check_circle,
                                            color: hasMark && isPresent
                                                ? const Color(0xFF4CAF50)
                                                : Colors.grey.shade300,
                                            size: 30,
                                          ),
                                          onPressed: () {
                                            setState(() =>
                                                _attendanceMap[member.id] =
                                                    'present');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Submit button
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_unmarkedCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '$_unmarkedCount member(s) not yet marked '
                                      '(they will be skipped)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade800),
                                    ),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSubmitting ||
                                            _unmarkedCount == _members.length
                                        ? null
                                        : _submitAttendance,
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
                                      _isSubmitting
                                          ? 'Saving...'
                                          : 'Save Attendance',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                              ],
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
