// user.dart
class User {
  final String? id;
  final String phone;
  final String? name;
  final List<String> roles;
  final String? token;
  final String? refreshToken;
  final bool? isEnabled;

  User({
    this.id,
    required this.phone,
    this.name,
    required this.roles,
    this.token,
    this.refreshToken,
    this.isEnabled
  });

  // For API responses with nested 'user' object
  factory User.fromApiResponse(Map<String, dynamic> json) {
    final userData = json['user'] ?? {};
    return User(
      id: userData['id']?.toString() ?? '',
      phone: userData['phone']?.toString() ?? '',
      name: userData['name']?.toString(),
      isEnabled: userData['isEnabled'],
      roles: userData['roles'] != null
          ? List<String>.from(userData['roles'].map((r) => r.toString()))
          : [],
      token: json['token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
    );
  }

  // For direct JSON parsing (e.g., from local storage)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isEnabled: json['isEnabled'] ?? false,
      name: json['name']?.toString(),
      roles: json['roles'] != null
          ? List<String>.from(json['roles'].map((r) => r.toString()))
          : [],
      token: json['token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'isEnabled': isEnabled,
      'roles': roles,
      'token': token,
      'refresh_token': refreshToken,
    };
  }
}

class UserWrite {
  final String phone;
  final String password;
  final String? name;
  final bool isEnabled;
  final List<String> roles;


  UserWrite({
    required this.phone,
    required this.password,
    required this.isEnabled,
    required this.roles,
    this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
      'name': name,
      'isEnabled': isEnabled,
      'roles': roles
    };
  }
}

class UserCollection {
  final List<User> member;
  final int totalItems;
  final Map<String, dynamic> view;
  final Map<String, dynamic> search;

  UserCollection({
    required this.member,
    required this.totalItems,
    required this.view,
    required this.search,
  });

  factory UserCollection.fromJson(List<dynamic> json) {
    return UserCollection(
      member: json.map((item) => User.fromJson(item)) // Use fromJson instead of fromApiResponse
          .toList() ?? [],
      totalItems: json.length,
      view: {},
      search: {},
    );
  }
}