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
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await ApiService.getMembers();
      final list = (data['members'] as List)
          .map((m) => UserModel.fromJson(m))
          .toList();
      if (!mounted) return;
      setState(() {
        _members = list;
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
              _buildField(passwordCtrl, 'Password (optional)', Icons.lock,
                  obscureText: true),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Use a passphrase of at least 15 characters.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (name.isEmpty || phone.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Name and phone are required')),
                            );
                            return;
                          }
                          setModalState(() => isSubmitting = true);
                          try {
                            await ApiService.addMember(
                              name,
                              phone,
                              passwordCtrl.text,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadMembers();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Member added successfully!'),
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                            );
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (!ctx.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Member'),
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
                          final messenger = ScaffoldMessenger.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Remove Member?'),
                              content: Text(
                                  'Are you sure you want to remove ${member.name}? This cannot be undone.'),
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
                            try {
                              await ApiService.deleteMember(member.id);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadMembers();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('${member.name} removed'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                ),
                              );
                            } catch (e) {
                              if (!ctx.mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
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
                          final messenger = ScaffoldMessenger.of(context);
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (name.isEmpty || phone.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Name and phone are required')),
                            );
                            return;
                          }
                          try {
                            await ApiService.updateMember(
                              member.id,
                              name,
                              phone,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _loadMembers();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Changes saved'),
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                            );
                          } catch (e) {
                            if (!ctx.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
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
    final amountCtrl = TextEditingController();
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
                            final messenger = ScaffoldMessenger.of(context);
                            final amount = double.tryParse(amountCtrl.text);
                            if (amount == null || amount <= 0) {
                              messenger.showSnackBar(
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
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Money added successfully!'),
                                  backgroundColor: Color(0xFF4CAF50),
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (!ctx.mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
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
      {TextInputType? keyboardType, bool obscureText = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
        heroTag: 'admin_members_fab',
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredMembers.length} Members',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Member list
          Expanded(
            child: _isLoading
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
                                onPressed: _loadMembers,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredMembers.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadMembers,
                            child: ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.group_off,
                                            size: 64,
                                            color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'No members yet'
                                              : 'No members match your search',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A3C34),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'Tap + to add your first member'
                                              : 'Try a different name or phone',
                                          style:
                                              TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
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
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Add money',
                                  icon: const Icon(Icons.add_circle,
                                      color: Color(0xFF1A5C3A), size: 28),
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
