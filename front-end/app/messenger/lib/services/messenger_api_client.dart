import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message_summary.dart';
import '../models/chat_room_summary.dart';
import '../models/profile_summary.dart';
import 'api_base_url.dart';

class MessengerApiClient {
  MessengerApiClient({
    required this.apiBaseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiBaseUrl;
  final String token;

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void dispose() {
    _client.close();
  }

  Future<List<ProfileSummary>> listFriends(int userId) async {
    final response = await _client.get(_buildUri('/social/friends/$userId'), headers: _headers);
    return _decodeProfileList(response, 'friends');
  }

  Future<List<ProfileSummary>> listSuggestions(int userId) async {
    final response = await _client.get(_buildUri('/social/suggestions/$userId'), headers: _headers);
    return _decodeProfileList(response, 'suggestions');
  }

  Future<List<ProfileSummary>> searchProfiles({
    required String query,
    required int excludeUserId,
  }) async {
    final response = await _client.get(
      _buildUri('/social/profiles/search', <String, dynamic>{
        'q': query,
        'excludeUserId': excludeUserId,
      }),
      headers: _headers,
    );
    return _decodeProfileList(response, 'profiles');
  }

  Future<void> sendFriendRequest({
    required int requesterVId,
    required int addresseeVId,
    String? requestMessage,
  }) async {
    final response = await _client.post(
      _buildUri('/social/friend-requests'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'requesterVId': requesterVId,
        'addresseeVId': addresseeVId,
        'requestMessage': requestMessage,
      }),
    );

    _ensureSuccess(response, 'friend request');
  }

  Future<List<ChatRoomSummary>> listRooms(int userId) async {
    final response = await _client.get(
      _buildUri('/chat/rooms', <String, dynamic>{'userId': userId}),
      headers: _headers,
    );
    return _decodeRoomList(response);
  }

  Future<List<ChatMessageSummary>> listMessages(int roomId) async {
    final response = await _client.get(_buildUri('/chat/rooms/$roomId/messages'), headers: _headers);
    return _decodeMessageList(response);
  }

  Future<List<ChatMessageSummary>> listRecentMessages(int roomId) async {
    final response = await _client.get(_buildUri('/chat/rooms/$roomId/recent'), headers: _headers);
    return _decodeMessageList(response);
  }

  Future<ChatRoomSummary> createPrivateRoom({
    required int createdBy,
    required int participantVId,
    String? roomName,
  }) {
    return createRoom(
      createdBy: createdBy,
      roomType: 'private',
      participantIds: <int>[participantVId],
      roomName: roomName,
    );
  }

  Future<ChatRoomSummary> createRoom({
    required int createdBy,
    required String roomType,
    required List<int> participantIds,
    String? roomName,
  }) async {
    final response = await _client.post(
      _buildUri('/chat/rooms'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'createdBy': createdBy,
        'roomName': roomName,
        'roomType': roomType,
        'participantIds': participantIds,
      }),
    );

    final payload = _decodeJsonMap(response, 'chat room');
    return ChatRoomSummary.fromJson(payload);
  }

  Future<ChatMessageSummary> sendMessage({
    required int roomId,
    required int senderVId,
    required String messageText,
    String? mediaUrl,
    String? messageType,
    int? replyToId,
  }) async {
    final response = await _client.post(
      _buildUri('/chat/rooms/$roomId/messages'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'senderVId': senderVId,
        'messageText': messageText,
        'mediaUrl': mediaUrl,
        'messageType': messageType,
        'replyToId': replyToId,
      }),
    );

    final payload = _decodeJsonMap(response, 'chat message');
    return ChatMessageSummary.fromJson(payload);
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedBaseUrl = normalizeApiBaseUrl(apiBaseUrl);

    final uri = Uri.parse('$normalizedBaseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParameters.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  List<ProfileSummary> _decodeProfileList(http.Response response, String payloadName) {
    final decoded = _decodeJsonValue(response, payloadName);
    if (decoded is! List) {
      throw MessengerApiException('Unexpected $payloadName payload from backend.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProfileSummary.fromJson)
        .toList(growable: false);
  }

  List<ChatRoomSummary> _decodeRoomList(http.Response response) {
    final decoded = _decodeJsonValue(response, 'chat rooms');
    if (decoded is! List) {
      throw const MessengerApiException('Unexpected chat rooms payload from backend.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatRoomSummary.fromJson)
        .toList(growable: false);
  }

  List<ChatMessageSummary> _decodeMessageList(http.Response response) {
    final decoded = _decodeJsonValue(response, 'chat messages');
    if (decoded is! List) {
      throw const MessengerApiException('Unexpected chat messages payload from backend.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatMessageSummary.fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response, String payloadName) {
    final decoded = _decodeJsonValue(response, payloadName);
    if (decoded is! Map<String, dynamic>) {
      throw MessengerApiException('Unexpected $payloadName payload from backend.');
    }

    return decoded;
  }

  dynamic _decodeJsonValue(http.Response response, String payloadName) {
    _ensureSuccess(response, 'Unable to load $payloadName');
    return jsonDecode(response.body);
  }

  void _ensureSuccess(http.Response response, String label) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw MessengerApiException('$label failed (${response.statusCode}): ${_extractErrorMessage(response.body)}');
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to raw text.
    }

    final trimmed = body.trim();
    return trimmed.isEmpty ? 'unknown backend error' : trimmed;
  }
}

class MessengerApiException implements Exception {
  const MessengerApiException(this.message);

  final String message;

  @override
  String toString() => 'MessengerApiException: $message';
}