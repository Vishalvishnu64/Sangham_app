import 'package:flutter/material.dart';
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
  bool _isSubmitting = false;
  final _amountCtrl = TextEditingController(text: '100');
  final _noteCtrl = TextEditingController(text: 'Weekly contribution');

  // Weekly status
  List<dynamic> _paidMembers = [];
  List<dynamic> _notPaidMembers = [];

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

      // Try loading weekly status
      try {
        final weeklyData = await ApiService.getWeeklyStatus();
        _paidMembers = weeklyData['paid'] ?? [];
        _notPaidMembers = weeklyData['notPaid'] ?? [];
      } catch (_) {}

      setState(() {
        _members = members;
        _selectedIds.addAll(members.map((m) => m.id));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitContribution() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.addBulkContribution(
        amount,
        _selectAll ? null : _selectedIds.toList(),
        _noteCtrl.text,
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
        const SnackBar(content: Text('Failed to add contribution')),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly Status Card
                  if (_paidMembers.isNotEmpty || _notPaidMembers.isNotEmpty)
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                              borderRadius: BorderRadius.circular(14),
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
                              borderRadius: BorderRadius.circular(14),
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                _selectAll ? 'Deselect All' : 'Select All',
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
                                _selectAll =
                                    _selectedIds.length == _members.length;
                              });
                            },
                            title: Text(member.name),
                            subtitle: Text('₹${member.balance.toInt()}',
                                style:
                                    const TextStyle(color: Color(0xFF1A5C3A))),
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
                      onPressed: _isSubmitting ? null : _submitContribution,
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
                            : 'Add ₹${_amountCtrl.text} for ${_selectedIds.length} members',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
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
