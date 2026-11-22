import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';

/// Причина отказа, чтобы экраны выбирали реакцию без разбора текста.
enum ApiErrorKind { validation, notFound, conflict, server, network }

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.detail,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// Сырой текст ответа — полезен в логах, пользователю не показываем.
  final String? detail;

  @override
  String toString() => message;
}

enum _Operation { read, create, update, delete }

/// Тонкий клиент REST API. Все запросы идут через [_request], где живёт
/// единственное место адаптации под текущий бэкенд.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : _base = _stripSlash(
          baseUrl ??
              const String.fromEnvironment(
                'API_BASE',
                defaultValue: 'http://localhost:8080',
              ),
        ),
        _http = httpClient ?? http.Client();

  static const String apiBaseFromEnvironment = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8080',
  );

  static String _stripSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  final String _base;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 12);

  Future<UserPage> listUsers({int limit = 20, int cursor = 0}) async {
    final json = await _request(
      'GET',
      '/users',
      query: <String, String>{'limit': '$limit', 'cursor': '$cursor'},
      operation: _Operation.read,
    );
    final raw = json['users'];
    final users = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList(growable: false)
        : const <User>[];
    final next = json['next_cursor'];
    return UserPage(users: users, nextCursor: next is num ? next.toInt() : null);
  }

  Future<User> createUser({
    required String login,
    required String password,
  }) async {
    final json = await _request(
      'POST',
      '/users',
      body: <String, Object?>{'login': login, 'password': password},
      operation: _Operation.create,
    );
    return User.fromJson(json);
  }

  Future<User> getUser(int id) async {
    final json = await _request(
      'GET',
      '/users/$id',
      operation: _Operation.read,
    );
    return User.fromJson(json);
  }

  /// Пустой [password] означает «не менять пароль»: бэкенд отвергает пустую
  /// строку, поэтому поле не отправляется вовсе.
  Future<User> updateUser(
    int id, {
    String? login,
    String? password,
  }) async {
    final body = <String, Object?>{};
    if (login != null) body['login'] = login;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (body.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Нечего сохранять: заполните хотя бы одно поле.',
      );
    }
    final json = await _request(
      'PATCH',
      '/users/$id',
      body: body,
      operation: _Operation.update,
    );
    return User.fromJson(json);
  }

  Future<void> deleteUser(int id) async {
    await _request('DELETE', '/users/$id', operation: _Operation.delete);
  }

  void close() => _http.close();

  Uri _uri(String path, Map<String, String>? query) {
    // Пустой baseUrl — запросы на origin страницы (вариант за nginx).
    final root = _base.isEmpty ? Uri.base.origin : _base;
    final uri = Uri.parse('$root$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    required _Operation operation,
  }) async {
    final request = http.Request(method, _uri(path, query));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Сервер не ответил вовремя. Попробуйте ещё раз.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        kind: ApiErrorKind.network,
        message: 'Не удалось связаться с сервером.',
        detail: error.message,
      );
    }

    final text = response.body.trim();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return const <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException(
        kind: ApiErrorKind.server,
        statusCode: response.statusCode,
        message: 'Сервер вернул неожиданный ответ.',
        detail: text,
      );
    }

    throw _mapFailure(response.statusCode, text, operation);
  }

  ApiException _mapFailure(
    int status,
    String detail,
    _Operation operation,
  ) {
    final code = detail.isEmpty ? null : detail;
    switch (status) {
      case 400:
        return ApiException(
          kind: ApiErrorKind.validation,
          statusCode: status,
          detail: code,
          message: _describeBadRequest(code),
        );
      case 404:
        return const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: 'Пользователь не найден.',
        );
      case 409:
        return const ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: 409,
          message: 'Логин уже занят.',
        );
      case 500:
        return _mapServerError(operation, code);
      default:
        return ApiException(
          kind: ApiErrorKind.server,
          statusCode: status,
          detail: code,
          message: 'Сервер ответил кодом $status.',
        );
    }
  }

  /// Бэкенд пока отдаёт `500 internal error` вместо 404/409/400.
  /// Различить причины по телу нельзя, поэтому опираемся на операцию:
  /// отсутствующий ресурс возможен только у чтения, изменения и удаления;
  /// конфликт логина — только у создания и переименования.
  ApiException _mapServerError(_Operation operation, String? detail) {
    const serverStatus = 500;
    switch (operation) {
      case _Operation.read:
      case _Operation.delete:
        return const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: serverStatus,
          message: 'Пользователя нет: возможно, запись уже удалили.',
        );
      case _Operation.create:
        return const ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: serverStatus,
          message: 'Логин уже занят или пароль длиннее 72 байт.',
        );
      case _Operation.update:
        return const ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: serverStatus,
          message:
              'Изменить не удалось: логин занят, пользователя нет или пароль '
              'длиннее 72 байт.',
        );
    }
  }

  static String _describeBadRequest(String? detail) {
    switch (detail) {
      case 'invalid request body':
        return 'Некорректное тело запроса: проверьте JSON и типы полей.';
      case 'validate error':
        return 'Проверьте поля: логин 3–32 символа, пароль 8–64 символа.';
      case 'invalid query params':
        return 'Некорректные параметры пагинации.';
      case 'invalid user id':
        return 'В адресе не число: ожидается /users/{id}.';
      case 'negative or zero user id':
        return 'Идентификатор должен быть положительным.';
      default:
        return 'Сервер отклонил запрос.';
    }
  }
}

/// Клиентская проверка до отправки: экономит запрос и даёт точный текст.
String? validateLogin(String? value) {
  final login = (value ?? '').trim();
  if (login.isEmpty) return 'Введите логин';
  if (login.length < 3) return 'Минимум 3 символа';
  if (login.length > 32) return 'Максимум 32 символа';
  return null;
}

String? validatePassword(String? value, {bool required = true}) {
  final password = value ?? '';
  if (password.isEmpty) return required ? 'Введите пароль' : null;
  if (password.length < 8) return 'Минимум 8 символов';
  if (password.length > 64) return 'Максимум 64 символа';
  if (utf8.encode(password).length > 72) {
    return 'Пароль длиннее 72 байт: кириллица занимает 2 байта на символ';
  }
  return null;
}
