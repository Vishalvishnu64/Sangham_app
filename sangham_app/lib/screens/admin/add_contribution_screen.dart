import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class AddContributionScreen extends StatefulWidget {
  const AddContributionScreen({super.key});

  @override
  State<AddContributionScreen> createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  List<UserModel> _members = [];
  final Set<String> _selectedIds = {};
  bool _selectAll = true;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSubmitting = false;
  final _amountCtrl = TextEditingController(text: '100');
  final _noteCtrl = TextEditingController(text: 'Weekly contribution');
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // Weekly status
  List<dynamic> _paidMembers = [];
  List<dynamic> _notPaidMembers = [];

  @override
  void initState() {
    super.initState();
    // Keep the submit-button label in sync while typing.
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
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

      // Try loading weekly status (best-effort).
      try {
        final weeklyData = await ApiService.getWeeklyStatus();
        _paidMembers = weeklyData['paid'] ?? [];
        _notPaidMembers = weeklyData['notPaid'] ?? [];
      } catch (_) {
        _paidMembers = [];
        _notPaidMembers = [];
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _selectedIds.clear();
        _selectedIds.addAll(members.map((m) => m.id));
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

  Future<void> _submitContribution() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedIds.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    // Confirm before writing money records for many members at once.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Contribution'),
        content: Text(
          'Record $_currencyFormat.format(amount) for '
          '${_selectAll ? "ALL ${_members.length} members" : "${_selectedIds.length} selected member(s)"}?\n\n'
          'Total: $_currencyFormat.format(amount * (_selectAll ? _members.length : _selectedIds.length))',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.addBulkContribution(
        amount,
        _selectAll ? null : _selectedIds.toList(),
        _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Contribution added!'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      _loadData(); // Refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Add Contribution'),
        automaticallyImplyLeading: false,
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
                          'Couldn\'t load data',
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
                                    'Add members first to record contributions',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Weekly Status Card
                            if (_paidMembers.isNotEmpty ||
                                _notPaidMembers.isNotEmpty)
                              _buildWeeklyStatusCard(),

                            const SizedBox(height: 16),

                            // Amount & Note Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Contribution Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A3C34),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _amountCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A5C3A),
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '₹  ',
                                      prefixStyle: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A5C3A),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5F0),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _noteCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Note',
                                      prefixIcon: const Icon(Icons.note,
                                          color: Color(0xFF1A5C3A)),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5F0),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Member Selection
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Select Members (${_selectedIds.length}/${_members.length})',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A3C34),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectAll = !_selectAll;
                                            if (_selectAll) {
                                              _selectedIds.addAll(
                                                  _members.map((m) => m.id));
                                            } else {
                                              _selectedIds.clear();
                                            }
                                          });
                                        },
                                        child: Text(
                                          _selectAll
                                              ? 'Deselect All'
                                              : 'Select All',
                                          style: const TextStyle(
                                              color: Color(0xFF1A5C3A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ..._members.map((member) {
                                    final isSelected =
                                        _selectedIds.contains(member.id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedIds.add(member.id);
                                          } else {
                                            _selectedIds.remove(member.id);
                                          }
                                          _selectAll = _selectedIds.length ==
                                              _members.length;
                                        });
                                      },
                                      title: Text(member.name),
                                      subtitle: Text(
                                          _currencyFormat.format(member.balance),
                                          style: const TextStyle(
                                              color: Color(0xFF1A5C3A))),
                                      activeColor: const Color(0xFF1A5C3A),
                                      contentPadding: EdgeInsets.zero,
                                    );
                                  }),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitContribution,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_circle),
                                label: Text(
                                  _isSubmitting
                                      ? 'Adding...'
                                      : 'Add ₹${_amountCtrl.text} for ${_selectAll ? _members.length : _selectedIds.length} members',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),

                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildWeeklyStatusCard() {
    return Container(
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
            'This Week\'s Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3C34),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF4CAF50), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_paidMembers.length} Paid',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel,
                        color: Color(0xFFE53935), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_notPaidMembers.length} Not Paid',
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_notPaidMembers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Who hasn\'t paid:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _notPaidMembers
                  .map((m) => Chip(
                        label: Text(m['name'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
