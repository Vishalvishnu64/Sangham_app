class AttendanceModel {
  final String id;
  final String userId;
  final DateTime date;
  final String status;
  final String? userName;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    this.userName,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['_id'] ?? '',
      userId: json['userId'] is Map ? json['userId']['_id'] ?? '' : json['userId'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'absent',
      userName: json['userId'] is Map ? json['userId']['name'] : null,
    );
  }
}
