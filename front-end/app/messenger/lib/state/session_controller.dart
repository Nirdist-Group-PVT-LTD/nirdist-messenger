import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/auth_api_client.dart';
import '../services/secure_session_store.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthApiClient authApiClient,
    required SecureSessionStore secureSessionStore,
  })  : _authApiClient = authApiClient,
        _secureSessionStore = secureSessionStore;

  final AuthApiClient _authApiClient;
  final SecureSessionStore _secureSessionStore;

  AuthSession? _session;
  bool _isBootstrapping = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthSession? get session => _session;
  bool get isBootstrapping => _isBootstrapping;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _session != null;
  String get apiBaseUrl => _authApiClient.apiBaseUrl;

  Future<void> bootstrap() async {
    try {
      final storedSession = await _secureSessionStore.readSession();
      if (_isValidSession(storedSession)) {
        _session = storedSession;
        _errorMessage = null;
      } else {
        _session = null;
        await _secureSessionStore.clear();
        _errorMessage = null;
      }
    } catch (_) {
      _session = null;
      _errorMessage = 'Unable to load your saved session.';
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String phoneNumber,
  }) async {
    return _authenticateWithPhone(phoneNumber: phoneNumber);
  }

  Future<bool> signUp({
    required String phoneNumber,
    required String username,
    required String displayName,
    String? email,
    String? avatarUrl,
  }) async {
    return _authenticateWithPhone(
      phoneNumber: phoneNumber,
      username: username,
      displayName: displayName,
      email: email,
      avatarUrl: avatarUrl,
    );
  }

  Future<bool> _authenticateWithPhone({
    required String phoneNumber,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _authApiClient.exchangePhoneNumber(
        phoneNumber: phoneNumber,
        username: username,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
      );
      if (!_isValidSession(session)) {
        _errorMessage = 'Received an invalid session from backend. Please try again.';
        return false;
      }
      _session = session;
      await _secureSessionStore.saveSession(session);
      return true;
    } catch (error) {
      _errorMessage = error is AuthApiException
          ? error.message
          : 'Unable to complete authentication. Check the backend URL and try again.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _session = null;
    _errorMessage = null;
    await _secureSessionStore.clear();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  bool _isValidSession(AuthSession? session) {
    if (session == null) {
      return false;
    }

    if (session.token.trim().isEmpty) {
      return false;
    }

    return session.profile.vId > 0;
  }
}
