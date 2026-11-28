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

/// Тонкий клиент REST API. Все запросы идут через [_request], где живёт
/// единственное место перевода HTTP-кодов в понятные сообщения.
///
/// Бэкенд отдаёт ошибки простым текстом:
/// 400 — `invalid request body`, `validate error`, `invalid password`,
/// `invalid user id`, `negative or zero user id`, `invalid query params`;
/// 404 — `not found`; 409 — `already exists`.
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
    );
    return User.fromJson(json);
  }

  Future<User> getUser(int id) async {
    final json = await _request('GET', '/users/$id');
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
    final json = await _request('PATCH', '/users/$id', body: body);
    return User.fromJson(json);
  }

  Future<void> deleteUser(int id) async {
    await _request('DELETE', '/users/$id');
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

    throw _mapFailure(response.statusCode, text);
  }

  ApiException _mapFailure(int status, String detail) {
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
          message: 'Пользователь не найден: возможно, его уже удалили.',
        );
      case 409:
        return const ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: 409,
          message: 'Логин уже занят другим пользователем.',
        );
      case 405:
        return const ApiException(
          kind: ApiErrorKind.server,
          statusCode: 405,
          message: 'Сервер не поддерживает этот метод.',
        );
      default:
        return ApiException(
          kind: ApiErrorKind.server,
          statusCode: status,
          detail: code,
          message: 'Сервер ответил ошибкой $status. Попробуйте позже.',
        );
    }
  }

  static String _describeBadRequest(String? detail) {
    switch (detail) {
      case 'invalid request body':
        return 'Некорректное тело запроса: проверьте JSON и типы полей.';
      case 'validate error':
        return 'Проверьте поля: логин 3–32 символа, пароль 8–64 символа.';
      case 'invalid password':
        return 'Пароль длиннее 72 байт. Для кириллицы это около 36 символов.';
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
