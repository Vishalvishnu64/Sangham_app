class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type;
  final String note;
  final DateTime date;
  final double? runningBalance;
  final String? userName;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
    this.runningBalance,
    this.userName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? '',
      userId: json['userId'] is Map ? json['userId']['_id'] ?? '' : json['userId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] ?? 'contribution',
      note: json['note'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      runningBalance: json['runningBalance']?.toDouble(),
      userName: json['userId'] is Map ? json['userId']['name'] : null,
    );
  }
}
