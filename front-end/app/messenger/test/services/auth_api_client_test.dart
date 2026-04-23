import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:messenger/services/auth_api_client.dart';

void main() {
  test('normalizes a bare host base url to the /api prefix', () async {
    late Uri requestedUri;

    final client = MockClient((request) async {
      requestedUri = request.url;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://nirdist-backend.onrender.com/api/auth/phone/exchange');

      return http.Response(
        jsonEncode(<String, dynamic>{
          'token': 'token-123',
          'message': 'Login successful',
          'created': false,
          'profile': <String, dynamic>{
            'vId': 1,
            'username': 'abhi',
            'displayName': 'Abhishek',
            'email': null,
            'phoneNumber': '+977921663633',
            'firebaseUid': 'direct-phone:+977921663633',
            'avatarUrl': null,
            'bio': null,
            'phoneVerifiedAt': null,
            'createdAt': null,
            'updatedAt': null,
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final apiClient = AuthApiClient(
      client: client,
      apiBaseUrl: 'https://nirdist-backend.onrender.com/',
    );

    final session = await apiClient.exchangePhoneNumber(phoneNumber: '+977921663633');

    expect(requestedUri.toString(), 'https://nirdist-backend.onrender.com/api/auth/phone/exchange');
    expect(session.token, 'token-123');
    expect(session.profile.phoneNumber, '+977921663633');
  });
}