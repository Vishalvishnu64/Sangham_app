import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;

  const LoanDetailsScreen({Key? key, required this.loanId}) : super(key: key);

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  late Future<Map<String, dynamic>> _loanDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
  }

  void _showRepaymentDialog() {
    final repaymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Repayment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter repayment amount (₹):'),
            const SizedBox(height: 12),
            TextField(
              controller: repaymentController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Amount in Rupees',
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
              if (repaymentController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter amount')),
                );
                return;
              }

              final amount = double.parse(repaymentController.text);
              Navigator.pop(context);

              try {
                await ApiService.repayLoan(widget.loanId, amount);
                setState(() {
                  _loanDetailsFuture = ApiService.getLoanDetails(widget.loanId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Repayment recorded successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Repay'),
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
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final loan = snapshot.data!;
          final principalRemaining = (loan['remainingPrincipal'] as num?)?.toDouble() ?? 0;
          final interestDue = (loan['currentMonthInterest'] as num?)?.toDouble() ?? 0;
          final totalDue = principalRemaining + interestDue;
          final totalInterestPaid = (loan['totalInterestPaid'] as num?)?.toDouble() ?? 0;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5C3A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount Due',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Principal',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${principalRemaining.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interest (This Month)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${interestDue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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

                // Loan Information Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loan Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Original Loan Amount', '₹${(loan['principalAmount'] as num?)?.toStringAsFixed(0) ?? 0}'),
                      _buildInfoRow('Interest Rate', '1% per month'),
                      _buildInfoRow('Status', (loan['status'] as String?)?.toUpperCase() ?? 'N/A'),
                      _buildInfoRow(
                        'Issued Date',
                        loan['issuedDate'] != null
                            ? DateTime.parse(loan['issuedDate'].toString()).toString().split(' ')[0]
                            : 'N/A',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Interest Tracking Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interest Tracking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Total Interest Paid', '₹${totalInterestPaid.toStringAsFixed(2)}'),
                      _buildInfoRow(
                        'Last Interest Calculated',
                        loan['lastInterestCalculated'] != null
                            ? DateTime.parse(loan['lastInterestCalculated'].toString()).toString().split(' ')[0]
                            : 'N/A',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment History Section
                if (loan['repaymentHistory'] != null && (loan['repaymentHistory'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(loan['repaymentHistory'] as List).map((repayment) {
                          final date = DateTime.parse(repayment['date'].toString()).toString().split(' ')[0];
                          final principal = repayment['principalPaid'] ?? 0;
                          final interest = repayment['interestPaid'] ?? 0;
                          final total = repayment['totalPaid'] ?? 0;
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
                                      'Date: $date',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${total}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A5C3A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Principal: ₹${principal}'),
                                    Text('Interest: ₹${interest}'),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      floatingActionButton: (loan['status'] as String?)?.toLowerCase() != 'repaid'
          ? FloatingActionButton.extended(
              onPressed: _showRepaymentDialog,
              backgroundColor: const Color(0xFF1A5C3A),
              label: const Text('Make Repayment'),
              icon: const Icon(Icons.payment),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        backgroundColor: const Color(0xFF1A5C3A),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loanDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final loan = snapshot.data!;
          final principalRemaining = loan['remainingPrincipal'] ?? 0;
          final interestDue = loan['currentMonthInterest'] ?? 0;
          final totalDue = principalRemaining + interestDue;
          final totalInterestPaid = loan['totalInterestPaid'] ?? 0;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5C3A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount Due',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Principal',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${principalRemaining.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interest (This Month)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${interestDue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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

                // Loan Information Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loan Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Original Loan Amount', '₹${loan['principalAmount'] ?? 0}'),
                      _buildInfoRow('Interest Rate', '${(loan['interestRate'] as double?)?.toStringAsFixed(1) ?? 0}% per month'),
                      _buildInfoRow('Status', loan['status']?.toUpperCase() ?? 'N/A'),
                      _buildInfoRow(
                        'Issued Date',
                        loan['issuedDate'] != null
                            ? DateTime.parse(loan['issuedDate']).toString().split(' ')[0]
                            : 'N/A',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Interest Tracking Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interest Tracking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Total Interest Paid', '₹${totalInterestPaid.toStringAsFixed(2)}'),
                      _buildInfoRow(
                        'Last Interest Calculated',
                        loan['lastInterestCalculated'] != null
                            ? DateTime.parse(loan['lastInterestCalculated']).toString().split(' ')[0]
                            : 'N/A',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment History Section
                if (loan['repaymentHistory'] != null && (loan['repaymentHistory'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(loan['repaymentHistory'] as List).map((repayment) {
                          final date = DateTime.parse(repayment['date']).toString().split(' ')[0];
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
                                      'Date: $date',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${repayment['totalPaid']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A5C3A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Principal: ₹${repayment['principalPaid']}'),
                                    Text('Interest: ₹${repayment['interestPaid']}'),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      floatingActionButton: loan['status'] != 'repaid'
          ? FloatingActionButton.extended(
              onPressed: _showRepaymentDialog,
              backgroundColor: const Color(0xFF1A5C3A),
              label: const Text('Make Repayment'),
              icon: const Icon(Icons.payment),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
