import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final String userId;
  const UserDashboardScreen({super.key, required this.userId});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getUserDashboard(widget.userId);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: const Color(0xFF1A5C3A),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A5C3A), Color(0xFF0D3B25)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'The Digital Ledger',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            'YOUR BALANCE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isLoading
                                ? '...'
                                : _currencyFormat
                                    .format(_data?['balance'] ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Activity Summary
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
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
                      'Activity Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(
                      icon: Icons.payments,
                      label: 'Total Contributions',
                      value: _isLoading
                          ? '...'
                          : _currencyFormat
                              .format(_data?['totalContributions'] ?? 0),
                      color: const Color(0xFF1A5C3A),
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: Icons.calendar_today,
                      label: 'Meetings Attended',
                      value: _isLoading
                          ? '...'
                          : '${_data?['attendance']?['totalPresent'] ?? 0} / ${_data?['attendance']?['total'] ?? 0}',
                      color: const Color(0xFF3F51B5),
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: Icons.trending_up,
                      label: 'Consistency',
                      value: _isLoading
                          ? '...'
                          : '${_data?['attendance']?['consistency'] ?? 0}%',
                      color: const Color(0xFFF5A623),
                    ),
                    if (!_isLoading && (_data?['loanBalance'] ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      _SummaryRow(
                        icon: Icons.account_balance,
                        label: 'Loan Balance',
                        value: _currencyFormat
                            .format(_data?['loanBalance'] ?? 0),
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Recent Transactions
            SliverToBoxAdapter(
              child: _buildRecentTransactions(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final transactions =
        (_data?['recentTransactions'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3C34),
                ),
              ),
              Text(
                'View All →',
                style: TextStyle(
                  color: Color(0xFF1A5C3A),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No transactions yet'),
              ),
            )
          else
            ...transactions.take(5).map((t) {
              final amount = (t['amount'] ?? 0).toDouble();
              final date = DateTime.tryParse(t['date'] ?? '');
              final type = t['type'] ?? 'contribution';
              final note = t['note'] ?? '';

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
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.isNotEmpty ? note : type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          if (date != null)
                            Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '+${_currencyFormat.format(amount)}',
                      style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
