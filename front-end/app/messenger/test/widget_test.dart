import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:messenger/app/nirdist_app.dart';
import 'package:messenger/models/auth_session.dart';
import 'package:messenger/models/chat_message_summary.dart';
import 'package:messenger/models/chat_room_summary.dart';
import 'package:messenger/models/profile_summary.dart';
import 'package:messenger/screens/messenger_shell.dart';
import 'package:messenger/screens/login_screen.dart';
import 'package:messenger/services/auth_api_client.dart';
import 'package:messenger/services/messenger_api_client.dart';
import 'package:messenger/services/secure_session_store.dart';
import 'package:messenger/state/session_controller.dart';

class _FakeAuthApiClient extends AuthApiClient {
  _FakeAuthApiClient() : super(apiBaseUrl: 'http://localhost:8080/api');

  @override
  Future<AuthSession> exchangePhoneNumber({
    required String phoneNumber,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    return AuthSession(
      token: 'token-1234567890',
      message: 'Login successful',
      created: false,
      profile: const ProfileSummary(
        vId: 1,
        username: 'test.user',
        displayName: 'Test User',
        email: 'test@example.com',
        phoneNumber: '+15550000000',
        firebaseUid: 'firebase-test-user',
        avatarUrl: null,
        bio: null,
        phoneVerifiedAt: null,
        createdAt: null,
        updatedAt: null,
      ),
    );
  }
}

class _FakeSecureSessionStore extends SecureSessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

class _FakeMessengerApiClient extends MessengerApiClient {
  _FakeMessengerApiClient()
      : super(
          apiBaseUrl: 'http://localhost:8080/api',
          token: 'token-1234567890',
        );

  @override
  Future<List<ProfileSummary>> listFriends(int userId) async {
    return <ProfileSummary>[
      const ProfileSummary(
        vId: 2,
        username: 'test.friend',
        displayName: 'Test Friend',
        email: 'friend@example.com',
        phoneNumber: '+15550000001',
        firebaseUid: 'firebase-test-friend',
        avatarUrl: null,
        bio: null,
        phoneVerifiedAt: null,
        createdAt: null,
        updatedAt: null,
      ),
    ];
  }

  @override
  Future<List<ProfileSummary>> listSuggestions(int userId) async {
    return <ProfileSummary>[
      const ProfileSummary(
        vId: 3,
        username: 'request.buddy',
        displayName: 'Request Buddy',
        email: 'buddy@example.com',
        phoneNumber: '+15550000002',
        firebaseUid: 'firebase-request-buddy',
        avatarUrl: null,
        bio: null,
        phoneVerifiedAt: null,
        createdAt: null,
        updatedAt: null,
      ),
    ];
  }

  @override
  Future<List<ChatRoomSummary>> listRooms(int userId) async {
    return <ChatRoomSummary>[
      ChatRoomSummary(
        roomId: 99,
        roomName: null,
        roomType: 'private',
        createdBy: userId,
        createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T10:05:00Z'),
        participantIds: <int>[userId, 2],
      ),
    ];
  }

  @override
  Future<List<ChatMessageSummary>> listRecentMessages(int roomId) async {
    return <ChatMessageSummary>[
      ChatMessageSummary(
        messageId: 1,
        roomId: roomId,
        senderVId: 2,
        messageText: 'Hello from backend',
        mediaUrl: null,
        messageType: 'TEXT',
        replyToId: null,
        isDeleted: false,
        createdAt: DateTime.parse('2026-01-01T10:05:00Z'),
      ),
    ];
  }

  @override
  Future<List<ChatMessageSummary>> listMessages(int roomId) async {
    return await listRecentMessages(roomId);
  }
}

void main() {
  testWidgets('shows the login shell when no session is stored', (WidgetTester tester) async {
    final sessionController = SessionController(
      authApiClient: _FakeAuthApiClient(),
      secureSessionStore: _FakeSecureSessionStore(),
    );

    await sessionController.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: sessionController,
        child: const NirdistApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('renders the backend-backed messenger shell', (WidgetTester tester) async {
    const profile = ProfileSummary(
      vId: 1,
      username: 'test.user',
      displayName: 'Test User',
      email: 'test@example.com',
      phoneNumber: '+15550000000',
      firebaseUid: 'firebase-test-user',
      avatarUrl: null,
      bio: null,
      phoneVerifiedAt: null,
      createdAt: null,
      updatedAt: null,
    );

    const session = AuthSession(
      token: 'token-1234567890',
      profile: profile,
      message: 'Login successful',
      created: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerShell(
          session: session,
          apiBaseUrl: 'http://localhost:8080/api',
          onSignOut: () async {},
          apiClient: _FakeMessengerApiClient(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Test User'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('filters people in the people tab', (WidgetTester tester) async {
    const profile = ProfileSummary(
      vId: 1,
      username: 'test.user',
      displayName: 'Test User',
      email: 'test@example.com',
      phoneNumber: '+15550000000',
      firebaseUid: 'firebase-test-user',
      avatarUrl: null,
      bio: null,
      phoneVerifiedAt: null,
      createdAt: null,
      updatedAt: null,
    );

    const session = AuthSession(
      token: 'token-1234567890',
      profile: profile,
      message: 'Login successful',
      created: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerShell(
          session: session,
          apiBaseUrl: 'http://localhost:8080/api',
          onSignOut: () async {},
          apiClient: _FakeMessengerApiClient(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('People'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'buddy');
    await tester.pumpAndSettle();

    expect(find.text('Request Buddy'), findsOneWidget);
    expect(find.text('Test Friend'), findsNothing);
  });
}
