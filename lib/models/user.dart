enum UserRole { user, admin, doctor, pg }

class User {
  final int id;
  final String username;
  final String password;
  final UserRole role;
  final String name;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role.name,
      'name': name,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.parse(json['id'].toString()),
      // API may return 'username' or 'email' as the identifying field.
      username: (json['username'] ?? json['email'] ?? '').toString(),
      password: '', // Do not store password from API
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.user,
      ),
      name: (json['name'] ?? '').toString(),
    );
  }
}
