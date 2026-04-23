import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'api_base_url.dart';

class AuthApiClient {
  AuthApiClient({http.Client? client, String? apiBaseUrl})
      : _client = client ?? http.Client(),
        apiBaseUrl = normalizeApiBaseUrl(apiBaseUrl ?? _resolveBaseUrl());

  final http.Client _client;
  final String apiBaseUrl;

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('NIRDIST_API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return normalizeApiBaseUrl(configuredBaseUrl);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return normalizeApiBaseUrl('https://nirdist-backend-uctd.onrender.com');
    }

    return switch (defaultTargetPlatform) {
      _ => normalizeApiBaseUrl('http://localhost:8080'),
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
        'Backend rejected the verified phone sign-in (${response.statusCode}).',
      );
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const AuthApiException('Unexpected auth response from backend.');
    }

    return AuthSession.fromJson(decodedBody);
  }

  Future<AuthSession> exchangePhoneNumber({
    required String phoneNumber,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    final response = await _client.post(
      _buildUri('/auth/phone/exchange'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'phoneNumber': phoneNumber,
        'username': username,
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        'Backend rejected the direct phone sign-in (${response.statusCode}).',
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