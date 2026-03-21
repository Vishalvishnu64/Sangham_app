import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<UserModel> _members = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getMembers();
      final list = (data['members'] as List)
          .map((m) => UserModel.fromJson(m))
          .toList();
      setState(() {
        _members = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<UserModel> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.phone.contains(_searchQuery))
        .toList();
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add New Member',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3C34),
                ),
              ),
              const SizedBox(height: 20),
              _buildField(nameCtrl, 'Full Name', Icons.person),
              const SizedBox(height: 14),
              _buildField(phoneCtrl, 'Phone Number', Icons.phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _buildField(passwordCtrl, 'Password (optional)', Icons.lock),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name and phone required')),
                      );
                      return;
                    }
                    await ApiService.addMember(
                      nameCtrl.text,
                      phoneCtrl.text,
                      passwordCtrl.text.isEmpty
                          ? phoneCtrl.text.substring(phoneCtrl.text.length - 4)
                          : passwordCtrl.text,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadMembers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Member added successfully!'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  },
                  child: const Text('Add Member'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(UserModel member) {
    final nameCtrl = TextEditingController(text: member.name);
    final phoneCtrl = TextEditingController(text: member.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Member',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3C34),
                ),
              ),
              const SizedBox(height: 20),
              _buildField(nameCtrl, 'Full Name', Icons.person),
              const SizedBox(height: 14),
              _buildField(phoneCtrl, 'Phone Number', Icons.phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Remove Member?'),
                              content: Text(
                                  'Are you sure you want to remove ${member.name}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ApiService.deleteMember(member.id);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadMembers();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          await ApiService.updateMember(
                            member.id,
                            nameCtrl.text,
                            phoneCtrl.text,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadMembers();
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMoneyDialog(UserModel member) {
    final amountCtrl = TextEditingController(text: '100');
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Money to ${member.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3C34),
                  ),
                ),
                const SizedBox(height: 20),
                _buildField(
                  amountCtrl,
                  'Amount',
                  Icons.payments,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _buildField(noteCtrl, 'Note (optional)', Icons.note),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amount = double.tryParse(amountCtrl.text);
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enter a valid amount')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.addSingleTransaction(
                                  member.id, amount, 'contribution', noteCtrl.text);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadMembers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Money added successfully!'),
                                  backgroundColor: Color(0xFF4CAF50),
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to add money')),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add Money'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5C3A)),
        filled: true,
        fillColor: const Color(0xFFF5F5F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A5C3A), width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Members'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        backgroundColor: const Color(0xFF1A5C3A),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // Member count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredMembers.length} Members',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Member list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadMembers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (_, i) {
                        final member = _filteredMembers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF1A5C3A).withValues(alpha: 0.1),
                              child: Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFF1A5C3A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              member.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              member.phone,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${member.balance.toInt()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A5C3A),
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Text(
                                      'Balance',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.add_circle, color: Color(0xFF1A5C3A), size: 32),
                                  onPressed: () => _showAddMoneyDialog(member),
                                ),
                              ],
                            ),
                            onTap: () => _showEditDialog(member),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
