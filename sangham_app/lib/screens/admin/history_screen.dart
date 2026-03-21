import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await ApiService.getAllTransactions();
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load history: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color(0xFF1A5C3A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _transactions.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No transactions found.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        final amount = (t['amount'] ?? 0).toDouble();
                        final date = DateTime.tryParse(t['date'] ?? '');
                        final type = t['type'] ?? 'contribution';
                        final note = t['note'] ?? '';
                        
                        final userMap = t['userId'] as Map<String, dynamic>?;
                        final memberName = userMap?['name'] ?? 'Unknown Member';

                        IconData icon;
                        Color iconColor;
                        switch (type) {
                          case 'loan':
                            icon = Icons.account_balance;
                            iconColor = Colors.orange;
                            break;
                          case 'penalty':
                            icon = Icons.warning;
                            iconColor = Colors.red;
                            break;
                          default:
                            icon = Icons.payments;
                            iconColor = const Color(0xFF4CAF50);
                        }

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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: iconColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      memberName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A3C34),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      note.isNotEmpty ? note : type.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (date != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _dateFormat.format(date.toLocal()),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              Text(
                                '+${_currencyFormat.format(amount)}',
                                style: TextStyle(
                                  color: iconColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
