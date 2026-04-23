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
      _session = await _secureSessionStore.readSession();
      _errorMessage = null;
    } catch (_) {
      _session = null;
      _errorMessage = 'Unable to load your saved session.';
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String idToken,
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
      final session = await _authApiClient.exchangeFirebaseToken(
        idToken: idToken,
        username: username,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
      );
      _session = session;
      await _secureSessionStore.saveSession(session);
      return true;
    } catch (error) {
      _errorMessage = error is AuthApiException
          ? error.message
          : 'Unable to sign in. Check the backend URL and token details.';
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
}