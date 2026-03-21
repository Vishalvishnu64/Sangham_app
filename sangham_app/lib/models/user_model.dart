class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final double balance;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.balance = 0,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      balance: (json['balance'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
    };
  }
}
