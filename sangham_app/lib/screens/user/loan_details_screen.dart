import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  late Future<Map<String, dynamic>> _loanDetailsFuture;
  Map<String, dynamic>? _currentLoan;
  final _currencyFormat = NumberFormat('₹#,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
  }

  void _showRepaymentDialog() {
    if (_currentLoan == null) return;

    final controller = TextEditingController();
    final totalDue = ((_currentLoan!['remainingPrincipal'] as num?)?.toDouble() ?? 0) +
        ((_currentLoan!['currentMonthInterest'] as num?)?.toDouble() ?? 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Repayment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Due: ${_currencyFormat.format(totalDue)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount to pay',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid amount')),
                );
                return;
              }

              if (amount > totalDue) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Amount exceeds total due (${_currencyFormat.format(totalDue)})')),
                );
                return;
              }

              try {
                final result = await ApiService.repayLoan(
                  widget.loanId,
                  amount,
                );

                if (!mounted) return;

                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded successfully')),
                  );
                  Navigator.pop(context);
                  setState(() {
                    _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Payment failed')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        backgroundColor: const Color(0xFF1A5C3A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final loan = snapshot.data!;
          _currentLoan = loan;

          final remainingPrincipal = (loan['remainingPrincipal'] as num?)?.toDouble() ?? 0;
          final currentMonthInterest = (loan['currentMonthInterest'] as num?)?.toDouble() ?? 0;
          final totalDue = remainingPrincipal + currentMonthInterest;
          final repayments = (loan['repayments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final status = (loan['status'] as String?)?.toUpperCase() ?? 'ACTIVE';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Due Card
                Card(
                  elevation: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A5C3A),
                          const Color(0xFF2D7F52),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount Due',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(totalDue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Principal',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  _currencyFormat.format(remainingPrincipal),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interest (This Month)',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  _currencyFormat.format(currentMonthInterest),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Loan Information
                const Text(
                  'Loan Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Original Amount', _currencyFormat.format(loan['principalAmount'] ?? 0)),
                _buildInfoRow('Status', status, statusColor: status == 'REPAID' ? Colors.green : Colors.orange),
                _buildInfoRow('Interest Rate', '1% per month'),
                _buildInfoRow(
                  'Issued Date',
                  DateFormat('dd MMM yyyy').format(
                    DateTime.parse(loan['createdAt'] as String? ?? DateTime.now().toString()),
                  ),
                ),
                const SizedBox(height: 24),

                // Interest Tracking
                const Text(
                  'Interest Tracking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Total Interest Paid', _currencyFormat.format(loan['totalInterestPaid'] ?? 0)),
                _buildInfoRow(
                  'Last Calculated',
                  DateFormat('dd MMM yyyy').format(
                    DateTime.parse(loan['interestCalculatedDate'] as String? ?? DateTime.now().toString()),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment History
                const Text(
                  'Payment History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (repayments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No payments made yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...repayments.map((payment) {
                    final date = DateTime.parse(payment['date'] as String? ?? DateTime.now().toString());
                    final principal = (payment['principalPaid'] as num?)?.toDouble() ?? 0;
                    final interest = (payment['interestPaid'] as num?)?.toDouble() ?? 0;
                    final total = (payment['totalPaid'] as num?)?.toDouble() ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(date),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _currencyFormat.format(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Principal: ${_currencyFormat.format(principal)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Interest: ${_currencyFormat.format(interest)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: (_currentLoan?['status'] as String?)?.toLowerCase() != 'repaid'
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1A5C3A),
              foregroundColor: Colors.white,
              onPressed: _showRepaymentDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          statusColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ],
      ),
    );
  }
}
