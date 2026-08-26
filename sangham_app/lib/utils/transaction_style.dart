import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppFormat {
  static final NumberFormat money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  /// "+₹500" for positive, "-₹500" for negative — never "+₹-500".
  static String signed(num amount) =>
      '${amount >= 0 ? '+' : '-'}${money.format(amount.abs())}';
}

class TxStyle {
  final IconData icon;
  final Color color;
  final String label;
  const TxStyle(this.icon, this.color, this.label);

  static const _green = Color(0xFF4CAF50);
  static const _orange = Color(0xFFF5A623);

  static TxStyle of(String? type) {
    switch (type) {
      case 'loan':
        return const TxStyle(Icons.account_balance, Colors.orange, 'Loan Issued');
      case 'loan_repayment':
        return const TxStyle(Icons.payments, _green, 'Loan Repayment');
      case 'loan_interest_payment':
        return const TxStyle(Icons.percent, _green, 'Interest Payment');
      case 'penalty':
        return const TxStyle(Icons.warning_amber_rounded, Color(0xFFE53935), 'Penalty');
      case 'withdrawal':
        return const TxStyle(Icons.account_balance_wallet_outlined, _orange, 'Withdrawal');
      default:
        return const TxStyle(Icons.payments, _green, 'Contribution');
    }
  }

  /// Green for money in, red/orange for money out.
  static Color amountColor(num amount) =>
      amount >= 0 ? _green : Colors.orange;
}
