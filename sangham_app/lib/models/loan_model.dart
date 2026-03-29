class LoanModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final double amount;
  final double outstandingBalance;
  final String status;
  final String note;
  final DateTime issuedDate;
  final DateTime? repaidDate;
  final String createdByName;

  LoanModel({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userPhone = '',
    required this.amount,
    required this.outstandingBalance,
    required this.status,
    this.note = '',
    required this.issuedDate,
    this.repaidDate,
    this.createdByName = '',
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['_id'] ?? '')
          : (json['userId'] ?? ''),
      userName: json['userId'] is Map ? (json['userId']['name'] ?? '') : '',
      userPhone: json['userId'] is Map ? (json['userId']['phone'] ?? '') : '',
      amount: (json['amount'] ?? 0).toDouble(),
      outstandingBalance: (json['outstandingBalance'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      note: json['note'] ?? '',
      issuedDate: DateTime.tryParse(json['issuedDate'] ?? '') ?? DateTime.now(),
      repaidDate: json['repaidDate'] != null
          ? DateTime.tryParse(json['repaidDate'])
          : null,
      createdByName:
          json['createdBy'] is Map ? (json['createdBy']['name'] ?? '') : '',
    );
  }
}
