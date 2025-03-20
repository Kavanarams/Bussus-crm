class Lead {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String leadStatus;

  Lead({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.leadStatus,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json["id"] ?? '',
      name: json["name"] ?? '',
      email: json["email"] ?? '',
      phone: json["phone"] ?? '',
      leadStatus: json["lead_status"] ?? '',
    );
  }
}
