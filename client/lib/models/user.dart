/// Пользователь из REST API.
///
/// `created_at` приходит строкой RFC 3339 с offset сервера; для генератора
/// агата важно только UTC-значение в миллисекундах.
class User {
  const User({
    required this.id,
    required this.version,
    required this.login,
    required this.createdAt,
  });

  final int id;
  final int version;
  final String login;
  final DateTime createdAt;

  int get createdAtMs => createdAt.toUtc().millisecondsSinceEpoch;

  factory User.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return User(
      id: (json['id'] as num).toInt(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      login: json['login'] as String? ?? '',
      createdAt: DateTime.parse(createdAt as String),
    );
  }
}

/// Страница списка с keyset-курсором.
class UserPage {
  const UserPage({required this.users, required this.nextCursor});

  final List<User> users;

  /// id последнего элемента страницы, если есть следующая; иначе null.
  /// Бэкенд отдаёт именно id, а не номер страницы.
  final int? nextCursor;

  bool get hasMore => nextCursor != null;
}
