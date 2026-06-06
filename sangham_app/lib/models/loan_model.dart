class LoanModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final double amount;
  final double outstandingBalance; // Principal only
  final double currentMonthInterest; // Separate monthly interest
  final double remainingPrincipal;
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
    this.currentMonthInterest = 0,
    this.remainingPrincipal = 0,
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
      outstandingBalance: (json['outstandingBalance'] ?? json['remainingPrincipal'] ?? 0).toDouble(),
      currentMonthInterest: (json['currentMonthInterest'] ?? 0).toDouble(),
      remainingPrincipal: (json['remainingPrincipal'] ?? json['outstandingBalance'] ?? 0).toDouble(),
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
