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

  void _reload() {
    setState(() {
      _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
    });
  }

  void _showRepaymentDialog(Map<String, dynamic> loanData) {
    if (_currentLoan == null) return;

    final controller = TextEditingController();
    final remainingPrincipal = (loanData['remainingPrincipal'] as num?)?.toDouble() ?? 0;
    final currentMonthInterest = (loanData['currentMonthInterest'] as num?)?.toDouble() ?? 0;

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            title: const Text('Make Repayment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interest Section
                  if (currentMonthInterest > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5C3A).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
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
                                Text(_currencyFormat.format(currentMonthInterest), style: const TextStyle(color: Color(0xFF1A5C3A), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    final messenger = ScaffoldMessenger.of(dialogContext);
                                    final ok = await _processPayment(
                                        widget.loanId, currentMonthInterest, 'interest',
                                        messenger: messenger);
                                    if (!dialogContext.mounted) return;
                                    if (ok) Navigator.pop(dialogContext);
                                    setDialogState(() => isSubmitting = false);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A5C3A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Pay Interest'),
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
                  Text('Remaining: ${_currencyFormat.format(remainingPrincipal)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'Enter principal amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount = double.tryParse(controller.text.trim());
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('Enter valid principal amount')),
                                );
                                return;
                              }
                              if (amount > remainingPrincipal) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Amount exceeds principal (${_currencyFormat.format(remainingPrincipal)})')),
                                );
                                return;
                              }
                              setDialogState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(dialogContext);
                              final ok = await _processPayment(widget.loanId, amount, 'principal',
                                  messenger: messenger);
                              if (!dialogContext.mounted) return;
                              if (ok) Navigator.pop(dialogContext);
                              setDialogState(() => isSubmitting = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Pay Principal'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => controller.dispose());
  }

  /// Returns true when the repayment was recorded successfully.
  Future<bool> _processPayment(String loanId, double amount, String paymentType,
      {required ScaffoldMessengerState messenger}) async {
    try {
      final result = await ApiService.repayLoan(
        loanId,
        amount,
        paymentType: paymentType,
      );

      if (!mounted) return false;

      if (result['repaymentSummary'] != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Payment recorded successfully'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        _reload();
        return true;
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Payment failed')),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return false;
    }
  }

  String _formatDate(dynamic isoString) {
    final date = DateTime.tryParse(isoString?.toString() ?? '');
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Couldn\'t load loan details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final loan = snapshot.data!;
          // Keep a reference for the repayment dialog (assigned post-load only).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isSameLoan(_currentLoan, loan)) {
              setState(() => _currentLoan = loan);
            }
          });

          final remainingPrincipal = (loan['remainingPrincipal'] as num?)?.toDouble() ?? 0;
          final currentMonthInterest = (loan['currentMonthInterest'] as num?)?.toDouble() ?? 0;
          final repayments = (loan['repayments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final status = (loan['status'] as String?)?.toUpperCase() ?? 'ACTIVE';
          final interestRate = (loan['interestRate'] as num?) ?? 0.01;

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
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1A5C3A),
                          Color(0xFF2D7F52),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan Principal Outstanding',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _currencyFormat.format(remainingPrincipal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
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
                                  'Original Loan',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  _currencyFormat.format(loan['principalAmount'] ?? 0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
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
                _buildInfoRow('Interest Rate',
                    '${_formatRate(interestRate)}% per month'),
                _buildInfoRow('Issued Date', _formatDate(loan['createdAt'])),
                const SizedBox(height: 24),

                // Interest Tracking
                const Text(
                  'Interest Tracking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Total Interest Paid', _currencyFormat.format(loan['totalInterestPaid'] ?? 0)),
                _buildInfoRow('Last Calculated', _formatDate(loan['interestCalculatedDate'])),
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
                              Expanded(
                                child: Text(
                                  _formatDate(payment['date']),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
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
                  }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _canRepay()
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1A5C3A),
              foregroundColor: Colors.white,
              onPressed: () => _showRepaymentDialog(_currentLoan!),
              icon: const Icon(Icons.payments),
              label: const Text('Make Payment'),
            )
          : null,
    );
  }

  bool _isSameLoan(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return false;
    return identical(a, b);
  }

  /// The FAB must only exist once real loan data has loaded – otherwise a tap
  /// would hit a null assertion. Hidden entirely while loading/errored/repaid.
  bool _canRepay() {
    if (_currentLoan == null) return false;
    final status = (_currentLoan!['status'] as String?)?.toLowerCase();
    return status != 'repaid';
  }

  String _formatRate(num rate) {
    final percent = rate * 100;
    return percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
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
              : Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
        ],
      ),
    );
  }
}
