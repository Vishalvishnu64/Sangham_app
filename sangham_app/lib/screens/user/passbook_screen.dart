import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/transaction_model.dart';

class PassbookScreen extends StatefulWidget {
  final String userId;
  const PassbookScreen({super.key, required this.userId});

  @override
  State<PassbookScreen> createState() => _PassbookScreenState();
}

class _PassbookScreenState extends State<PassbookScreen> {
  List<TransactionModel> _passbook = [];
  double _currentBalance = 0;
  bool _isLoading = true;
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadPassbook();
  }

  Future<void> _loadPassbook() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserTransactions(widget.userId);
      final passbook = (data['passbook'] as List)
          .map((t) => TransactionModel.fromJson(t))
          .toList();
      setState(() {
        _passbook = passbook;
        _currentBalance = (data['currentBalance'] ?? 0).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Digital Passbook'),
        automaticallyImplyLeading: false,
        actions: [
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Bal: ${_currencyFormat.format(_currentBalance)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPassbook,
              child: _passbook.isEmpty
                  ? const Center(child: Text('No transactions yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _passbook.length,
                      itemBuilder: (_, i) {
                        final txn = _passbook[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              // Date
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A5C3A)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(txn.date),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A5C3A),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(txn.date),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF1A5C3A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.note.isNotEmpty
                                          ? txn.note
                                          : txn.type,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(txn.date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Amount & Balance
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${_currencyFormat.format(txn.amount)}',
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (txn.runningBalance != null)
                                    Text(
                                      'Bal: ${_currencyFormat.format(txn.runningBalance)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
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
