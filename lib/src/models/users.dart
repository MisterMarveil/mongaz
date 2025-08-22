// user.dart
class User {
  final String id;
  final String phone;
  final String? name;
  final List<String> roles;
  final String token;
  final String refreshToken;

  User({
    required this.id,
    required this.phone,
    this.name,
    required this.roles,
    required this.token,
    required this.refreshToken,
  });

  factory User.fromApiResponse(Map<String, dynamic> json) {
    // L'objet global contient 'token', 'refresh_token' et 'user'
    final userData = json['user'] ?? {};

    return User(
      id: userData['id'] ?? '',
      phone: userData['phone'] ?? '',
      name: userData['name'],
      roles: userData['roles'] != null
          ? List<String>.from(userData['roles'])
          : [],
      token: json['token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
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

  UserWrite({
    required this.phone,
    required this.password,
    this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
      'name': name,
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

  factory UserCollection.fromJson(Map<String, dynamic> json) {
    return UserCollection(
      member: (json['member'] as List<dynamic>?)
          ?.map((item) => User.fromApiResponse(item))
          .toList() ?? [],
      totalItems: json['totalItems'] ?? 0,
      view: json['view'] ?? {},
      search: json['search'] ?? {},
    );
  }
}