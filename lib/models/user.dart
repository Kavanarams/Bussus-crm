class User {
  final String username;
  final String email;
  final String? avatarUrl;
  
  User({
    required this.username,
    required this.email,
    this.avatarUrl,
  });
  
  // Empty constructor for unauthenticated state
  factory User.empty() {
    return User(
      username: '',
      email: '',
      avatarUrl: null,
    );
  }
  
  // Create a User from JSON data
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
    );
  }
  
  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
    };
  }
}