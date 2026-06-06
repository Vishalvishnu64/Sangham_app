import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/loan_model.dart';
import '../../models/user_model.dart';

class LoanManagementScreen extends StatefulWidget {
  const LoanManagementScreen({super.key});

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen>
    with SingleTickerProviderStateMixin {
  List<LoanModel> _loans = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  late TabController _tabController;
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllLoans();
      final loans =
          (data['loans'] as List).map((l) => LoanModel.fromJson(l)).toList();
      setState(() {
        _loans = loans;
        _summary = data['summary'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<LoanModel> get _activeLoans =>
      _loans.where((l) => l.status == 'active').toList();
  List<LoanModel> get _repaidLoans =>
      _loans.where((l) => l.status == 'repaid').toList();

  Future<void> _showIssueLoanDialog() async {
    List<UserModel> members = [];
    try {
      final data = await ApiService.getMembers();
      members =
          (data['members'] as List).map((m) => UserModel.fromJson(m)).toList();
    } catch (_) {
      return;
    }

    if (!mounted) return;

    UserModel? selectedMember;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF1A5C3A)),
              SizedBox(width: 10),
              Text('Issue Loan',
                  style: TextStyle(
                      color: Color(0xFF1A3C34), fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Member Dropdown
                DropdownButtonFormField<UserModel>(
                  value: selectedMember,
                  decoration: InputDecoration(
                    labelText: 'Select Member',
                    prefixIcon: const Icon(Icons.person,
                        color: Color(0xFF1A5C3A)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: members
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedMember = v),
                ),
                const SizedBox(height: 14),
                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Loan Amount',
                    prefixText: '₹  ',
                    prefixStyle: const TextStyle(
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
                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon:
                        const Icon(Icons.note, color: Color(0xFF1A5C3A)),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMember == null || amountCtrl.text.isEmpty) {
                  return;
                }
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;

                Navigator.pop(ctx);
                try {
                  await ApiService.issueLoan(
                    selectedMember!.id,
                    amount,
                    noteCtrl.text,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Loan of ${_currencyFormat.format(amount)} issued to ${selectedMember!.name}'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                  _loadLoans();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to issue loan')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5C3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Issue Loan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRepayDialog(LoanModel loan) async {
    final amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payments, color: Color(0xFF4CAF50)),
            SizedBox(width: 10),
            Text('Record Payment',
                style: TextStyle(
                    color: Color(0xFF1A3C34), fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interest Section
              if (loan.currentMonthInterest > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5C3A).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A5C3A).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.percent, color: Color(0xFF1A5C3A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Monthly Interest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(_currencyFormat.format(loan.currentMonthInterest), style: const TextStyle(color: Color(0xFF1A5C3A), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          _processPayment(loan.id, loan.currentMonthInterest, 'interest');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5C3A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Pay Interest'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
              ],
              
              // Principal Section
              const Text('Pay Loan Principal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Remaining: ${_currencyFormat.format(loan.remainingPrincipal)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter principal amount',
                  prefixText: '₹  ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter valid principal amount')),
                      );
                      return;
                    }
                    if (amount > loan.remainingPrincipal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Amount exceeds principal (${_currencyFormat.format(loan.remainingPrincipal)})')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _processPayment(loan.id, amount, 'principal');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Pay Principal'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(String loanId, double amount, String paymentType) async {
    try {
      final result = await ApiService.repayLoan(
        loanId,
        amount,
        paymentType: paymentType,
      );

      if (!mounted) return;

      if (result['success'] == true || result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Payment recorded successfully'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        _loadLoans();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Payment failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record payment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Loan Management'),
        backgroundColor: const Color(0xFF1A5C3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF5A623),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Active (${_activeLoans.length})'),
            Tab(text: 'Repaid (${_repaidLoans.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_loan_management_fab',
        onPressed: _showIssueLoanDialog,
        backgroundColor: const Color(0xFF1A5C3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Issue Loan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLoans,
              child: Column(
                children: [
                  // Summary Card
                  if (_summary != null) _buildSummaryCard(),
                  // Loan lists
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoanList(_activeLoans, isActive: true),
                        _buildLoanList(_repaidLoans, isActive: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5C3A), Color(0xFF0D3B25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5C3A).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL LOAN OUTSTANDING',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_summary?['totalOutstanding'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_summary?['activeCount'] ?? 0} Active',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Interest due row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.percent, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Monthly Interest Due: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _currencyFormat.format(_summary?['totalInterestDue'] ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanList(List<LoanModel> loans, {required bool isActive}) {
    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.check_circle_outline : Icons.history,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isActive ? 'No active loans' : 'No repaid loans yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final progress = loan.amount > 0
            ? (loan.amount - loan.remainingPrincipal) / loan.amount
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFF1A5C3A).withValues(alpha: 0.1),
                    child: Text(
                      loan.userName.isNotEmpty
                          ? loan.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF1A5C3A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(loan.issuedDate),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.orange.withValues(alpha: 0.1)
                          : const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Repaid',
                      style: TextStyle(
                        color: isActive
                            ? Colors.orange
                            : const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Amount details - Loan and Interest SEPARATE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan Amount',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        _currencyFormat.format(loan.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A3C34),
                        ),
                      ),
                    ],
                  ),
                  if (isActive)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Remaining',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          _currencyFormat.format(loan.remainingPrincipal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Monthly interest (separate row)
              if (isActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5C3A).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.percent, size: 14, color: Color(0xFF1A5C3A)),
                      const SizedBox(width: 6),
                      const Text('Monthly Interest: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _currencyFormat.format(loan.currentMonthInterest),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1A5C3A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '(1% of ${_currencyFormat.format(loan.remainingPrincipal)})',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
              if (loan.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  loan.note,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
              // Progress bar
              if (isActive) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toInt()}% repaid',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRepayDialog(loan),
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('Record Payment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (!isActive && loan.repaidDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Repaid on ${DateFormat('dd MMM yyyy').format(loan.repaidDate!)}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
