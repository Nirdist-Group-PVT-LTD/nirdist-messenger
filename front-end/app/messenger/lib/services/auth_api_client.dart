import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/profile_summary.dart';
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

    const deployedBaseUrl = 'https://nirdist-backend-uctd.onrender.com';

    if (kDebugMode) {
      if (kIsWeb) {
        return normalizeApiBaseUrl(deployedBaseUrl);
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          // Real-device testing should hit the deployed backend by default.
          return normalizeApiBaseUrl(deployedBaseUrl);
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return normalizeApiBaseUrl(deployedBaseUrl);
      }
    }

    // Default to the deployed backend unless explicitly overridden by dart-define.
    // This avoids desktop/web builds silently targeting localhost.
    return normalizeApiBaseUrl(deployedBaseUrl);
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
      throw AuthApiException(_extractErrorMessage(
        response,
        fallback: 'Backend rejected the direct phone sign-in (${response.statusCode}).',
      ));
    }

    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const AuthApiException('Unexpected auth response from backend.');
    }

    return AuthSession.fromJson(decodedBody);
  }

  Future<ProfileSummary> lookupPhoneNumber(String phoneNumber) async {
    final session = await exchangePhoneNumber(phoneNumber: phoneNumber);
    return session.profile;
  }

  Uri _buildUri(String path) {
    final normalizedBaseUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return Uri.parse('$normalizedBaseUrl$path');
  }

  String _extractErrorMessage(http.Response response, {required String fallback}) {
    try {
      final decodedBody = jsonDecode(response.body);
      if (decodedBody is Map<String, dynamic>) {
        final message = decodedBody['message']?.toString().trim();
        final error = decodedBody['error']?.toString().trim();
        final detail = decodedBody['detail']?.toString().trim();

        for (final candidate in <String?>[message, error, detail]) {
          if (candidate != null && candidate.isNotEmpty) {
            return candidate;
          }
        }
      }
    } catch (_) {
      // Fall back to a generic message when the backend does not return JSON.
    }

    return fallback;
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => 'AuthApiException: $message';
}
