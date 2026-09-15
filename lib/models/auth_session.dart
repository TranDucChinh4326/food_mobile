class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.role,
    this.avatar,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: int.tryParse('${json['id']}') ?? 0,
      username: '${json['username'] ?? ''}',
      fullname: '${json['fullname'] ?? json['username'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? 'USER'}',
      avatar: json['avatar']?.toString(),
    );
  }

  final int id;
  final String username;
  final String fullname;
  final String email;
  final String role;
  final String? avatar;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
