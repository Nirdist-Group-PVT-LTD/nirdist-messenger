import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const String _sessionKey = 'nirdist.auth.session';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> readSession() async {
    final storedValue = await _storage.read(key: _sessionKey);
    if (storedValue == null || storedValue.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(storedValue);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession.fromJson(decoded);
  }

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}