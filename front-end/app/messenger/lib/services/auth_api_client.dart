import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

class AuthApiClient {
  AuthApiClient({http.Client? client, String? apiBaseUrl})
      : _client = client ?? http.Client(),
        apiBaseUrl = apiBaseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String apiBaseUrl;

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('NIRDIST_API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8080/api',
      _ => 'http://localhost:8080/api',
    };
  }

  Future<AuthSession> exchangeFirebaseToken({
    required String idToken,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    final response = await _client.post(
      _buildUri('/auth/firebase/exchange'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'idToken': idToken,
        'username': username,
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        'Backend rejected the Firebase token exchange (${response.statusCode}).',
      );
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const AuthApiException('Unexpected auth response from backend.');
    }

    return AuthSession.fromJson(decodedBody);
  }

  Uri _buildUri(String path) {
    final normalizedBaseUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return Uri.parse('$normalizedBaseUrl$path');
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => 'AuthApiException: $message';
}