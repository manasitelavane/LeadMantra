// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_endpoints.dart';
import '../core/app_config.dart';
import '../core/navigator_key.dart';

class AuthUser {
  final int    id;
  final String name;
  final String email;
  final String role;
  final int    companyId;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.companyId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id:        j['id']         as int,
    name:      j['name']       as String? ?? '',
    email:     j['email']      as String? ?? '',
    role:      j['role']       as String? ?? '',
    companyId: j['company_id'] as int?    ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'name':       name,
    'email':      email,
    'role':       role,
    'company_id': companyId,
  };
}

class AuthResult {
  final bool    success;
  final String? error;

  const AuthResult.ok()            : success = true,  error = null;
  const AuthResult.fail(this.error): success = false;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _loginUrl = ApiEndpoints.login;
  static const _timeout  = Duration(seconds: 30);

  static const _kToken   = 'auth_token';
  static const _kUser    = 'auth_user';
  static const _kSavedAt = 'auth_token_saved_at';

  String?   _token;
  AuthUser? _user;

  bool      get isLoggedIn => _token != null;
  String?   get token      => _token;
  AuthUser? get user       => _user;

  /// Restores session from disk — call once at app startup.
  /// Clears the session if the stored token is older than [_kMaxAgeDays] days.
  Future<void> loadSession() async {
    final prefs     = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_kToken);
    final savedUser  = prefs.getString(_kUser);

    if (savedToken == null || savedUser == null) return;

    _token = savedToken.trim();
    _user  = AuthUser.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
    print('[AUTH] Session restored — user: ${_user!.email} (id: ${_user!.id})');
  }

  Future<AuthResult> login(String email, String password) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('[AUTH] Login attempt: $email');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final res = await http
          .post(
            Uri.parse(_loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      print('[AUTH] login ← ${res.statusCode} ${res.body}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final loginSuccess = res.statusCode == 200 && json['success'] == true;
      showApiSnackbar('POST /mobile/login', res.statusCode, success: loginSuccess);

      if (loginSuccess) {
        _token = (json['token'] as String?)?.trim();
        _user  = AuthUser.fromJson(json['user'] as Map<String, dynamic>);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kToken,   _token!);
        await prefs.setString(_kUser,    jsonEncode(_user!.toJson()));
        await prefs.setInt   (_kSavedAt, DateTime.now().millisecondsSinceEpoch);

        print('[AUTH] Logged in — name: ${_user!.name}, id: ${_user!.id}, role: ${_user!.role}');
        return const AuthResult.ok();
      }

      final msg = json['message'] as String?
          ?? 'Login failed. Please try again.';
      return AuthResult.fail(msg);
    } catch (e) {
      print('[AUTH] login error: $e');
      return AuthResult.fail('Network error. Please check your connection.');
    }
  }

  Future<void> logout() async {
    _token = null;
    _user  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    await prefs.remove(_kSavedAt);
    print('[AUTH] Logged out — session cleared');
  }

  Future<AuthResult> deleteAccount() async {
    final userId = _user?.id;
    if (userId == null || _token == null) {
      return const AuthResult.fail('Not logged in.');
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('[AUTH] Delete account request — user_id: $userId');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    try {
      final res = await http
          .post(
            Uri.parse(ApiEndpoints.deleteAccount),
            headers: {
              'Content-Type':  'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(_timeout);

      print('[AUTH] deleteAccount ← ${res.statusCode} ${res.body}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final deleteSuccess = res.statusCode == 200 && json['success'] == true;
      showApiSnackbar('POST /mobile/delete-account', res.statusCode, success: deleteSuccess);

      if (deleteSuccess) {
        await logout();
        return const AuthResult.ok();
      }

      final msg = json['message'] as String?
          ?? 'Failed to delete account. Please try again.';
      return AuthResult.fail(msg);
    } catch (e) {
      print('[AUTH] deleteAccount error: $e');
      return AuthResult.fail('Network error. Please check your connection.');
    }
  }

  /// Called when any API returns 401. Clears session and optionally navigates
  /// to Login. Pass [redirect] = false for background calls (sync) so the user
  /// is not forcefully kicked out while using the app.
  Future<void> handleExpiredSession({bool redirect = true}) async {
    print('[AUTH] Token expired — clearing session'
        '${redirect ? " and redirecting to Login" : " (silent, no redirect)"}');
    await logout();
    if (redirect) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(redirect
              ? 'Session expired. Please log in again.'
              : 'Session expired. Tap the menu to log in again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}
