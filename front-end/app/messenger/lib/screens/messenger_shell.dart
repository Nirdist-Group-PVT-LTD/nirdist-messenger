import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/chat_message_summary.dart';
import '../models/chat_room_summary.dart';
import '../models/profile_summary.dart';
import '../services/messenger_api_client.dart';
import 'conversation_screen.dart';

class MessengerShell extends StatefulWidget {
  const MessengerShell({
    super.key,
    required this.session,
    required this.apiBaseUrl,
    required this.onSignOut,
    this.apiClient,
  });

  final AuthSession session;
  final String apiBaseUrl;
  final Future<void> Function() onSignOut;
  final MessengerApiClient? apiClient;

  @override
  State<MessengerShell> createState() => _MessengerShellState();
}

class _MessengerShellState extends State<MessengerShell> {
  late final MessengerApiClient _apiClient;
  late final bool _ownsApiClient;

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<ProfileSummary> _friends = <ProfileSummary>[];
  List<ProfileSummary> _suggestions = <ProfileSummary>[];
  List<_RoomPreview> _rooms = <_RoomPreview>[];

  @override
  void initState() {
    super.initState();
    _ownsApiClient = widget.apiClient == null;
    _apiClient = widget.apiClient ?? MessengerApiClient(
      apiBaseUrl: widget.apiBaseUrl,
      token: widget.session.token,
    );
    _loadDashboard();
  }

  @override
  void dispose() {
    if (_ownsApiClient) {
      _apiClient.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        session: widget.session,
        friends: _friends,
        suggestions: _suggestions,
        rooms: _rooms,
        isLoading: _isLoading || _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onOpenChats: () => setState(() => _selectedIndex = 1),
        onOpenPeople: () => setState(() => _selectedIndex = 2),
        onOpenRoom: _openRoom,
        onStartConversation: _startConversation,
      ),
      _ChatsTab(
        session: widget.session,
        rooms: _rooms,
        isLoading: _isLoading || _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onOpenRoom: _openRoom,
        onOpenPeople: () => setState(() => _selectedIndex = 2),
      ),
      _PeopleTab(
        session: widget.session,
        friends: _friends,
        suggestions: _suggestions,
        isLoading: _isLoading || _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onStartConversation: _startConversation,
        onSendFriendRequest: _sendFriendRequest,
      ),
      _ProfileTab(
        session: widget.session,
        apiBaseUrl: widget.apiBaseUrl,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'People'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = widget.session.profile.vId;
      final friendsFuture = _apiClient.listFriends(userId);
      final suggestionsFuture = _apiClient.listSuggestions(userId);
      final roomsFuture = _apiClient.listRooms(userId);

      final friends = await friendsFuture;
      final suggestions = await suggestionsFuture;
      final rooms = await roomsFuture;

      final profilesById = <int, ProfileSummary>{
        for (final profile in <ProfileSummary>[widget.session.profile, ...friends, ...suggestions]) profile.vId: profile,
      };

      final roomPreviews = await Future.wait(
        rooms.map((room) => _buildRoomPreview(room, profilesById)),
      );

      roomPreviews.sort((left, right) {
        final leftDate = left.lastMessage?.createdAt ?? left.room.updatedAt ?? left.room.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate = right.lastMessage?.createdAt ?? right.room.updatedAt ?? right.room.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightDate.compareTo(leftDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = friends;
        _suggestions = suggestions;
        _rooms = roomPreviews;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is MessengerApiException ? error.message : 'Unable to load your messenger data.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
    });

    await _loadDashboard();
  }

  Future<_RoomPreview> _buildRoomPreview(ChatRoomSummary room, Map<int, ProfileSummary> profilesById) async {
    final peerId = room.participantIds.firstWhere(
      (participantId) => participantId != widget.session.profile.vId,
      orElse: () => widget.session.profile.vId,
    );
    final peerProfile = peerId == widget.session.profile.vId ? null : profilesById[peerId];
    final recentMessages = await _apiClient.listRecentMessages(room.roomId);
    final lastMessage = recentMessages.isEmpty ? null : recentMessages.last;

    return _RoomPreview(
      room: room,
      peerProfile: peerProfile,
      lastMessage: lastMessage,
    );
  }

  _RoomPreview? _findPrivateRoom(int peerVId) {
    for (final preview in _rooms) {
      final room = preview.room;
      if (!room.isPrivate) {
        continue;
      }

      if (room.participantIds.contains(widget.session.profile.vId) && room.participantIds.contains(peerVId)) {
        return preview;
      }
    }

    return null;
  }

  Future<void> _openRoom(_RoomPreview preview) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          session: widget.session,
          apiClient: _apiClient,
          room: preview.room,
          peerProfile: preview.peerProfile,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _startConversation(ProfileSummary profile) async {
    final existingRoom = _findPrivateRoom(profile.vId);
    final room = existingRoom?.room ?? await _apiClient.createPrivateRoom(
      createdBy: widget.session.profile.vId,
      participantVId: profile.vId,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          session: widget.session,
          apiClient: _apiClient,
          room: room,
          peerProfile: profile,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _sendFriendRequest(ProfileSummary profile) async {
    try {
      await _apiClient.sendFriendRequest(
        requesterVId: widget.session.profile.vId,
        addresseeVId: profile.vId,
        requestMessage: 'Sent from Nirdist Messenger',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${profile.displayLabel}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is MessengerApiException ? error.message : 'Unable to send the friend request.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.session,
    required this.friends,
    required this.suggestions,
    required this.rooms,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onOpenChats,
    required this.onOpenPeople,
    required this.onOpenRoom,
    required this.onStartConversation,
  });

  final AuthSession session;
  final List<ProfileSummary> friends;
  final List<ProfileSummary> suggestions;
  final List<_RoomPreview> rooms;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenPeople;
  final Future<void> Function(_RoomPreview preview) onOpenRoom;
  final Future<void> Function(ProfileSummary profile) onStartConversation;

  @override
  Widget build(BuildContext context) {
    final people = <ProfileSummary>[...friends, ...suggestions].take(8).toList(growable: false);

    return _ShellScaffold(
      title: 'Home',
      subtitle: 'Messenger-style home for your social graph.',
      session: session,
      onRefresh: onRefresh,
      isLoading: isLoading,
      errorMessage: errorMessage,
      children: <Widget>[
        _HeroCard(
          profile: session.profile,
          friendsCount: friends.length,
          chatsCount: rooms.length,
          suggestionsCount: suggestions.length,
            onOpenChats: onOpenChats,
          onOpenPeople: onOpenPeople,
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Stories',
          subtitle: 'A quick look at friends and suggestions from the backend.',
        ),
        const SizedBox(height: 12),
        _StoriesStrip(
          profiles: people,
          onTapPerson: onStartConversation,
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Recent rooms',
          subtitle: 'Recent message previews loaded from the chat service.',
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          _EmptyStateCard(
            icon: Icons.forum_outlined,
            title: 'No rooms yet',
            subtitle: 'Start a conversation from People and it will appear here.',
            actionLabel: 'Find people',
            onAction: onOpenPeople,
          )
        else
          ...rooms.take(5).map(
            (preview) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoomTile(
                preview: preview,
                onTap: () => onOpenRoom(preview),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.session,
    required this.rooms,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onOpenRoom,
    required this.onOpenPeople,
  });

  final AuthSession session;
  final List<_RoomPreview> rooms;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(_RoomPreview preview) onOpenRoom;
  final VoidCallback onOpenPeople;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      title: 'Chats',
      subtitle: 'Private rooms and groups powered by the backend.',
      session: session,
      onRefresh: onRefresh,
      isLoading: isLoading,
      errorMessage: errorMessage,
      children: <Widget>[
        if (rooms.isEmpty)
          _EmptyStateCard(
            icon: Icons.chat_bubble_outline,
            title: 'No rooms yet',
            subtitle: 'Start a chat from People to see the room list populate here.',
            actionLabel: 'Open people',
            onAction: onOpenPeople,
          )
        else
          ...rooms.map(
            (preview) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoomTile(
                preview: preview,
                onTap: () => onOpenRoom(preview),
              ),
            ),
          ),
      ],
    );
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab({
    required this.session,
    required this.friends,
    required this.suggestions,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onStartConversation,
    required this.onSendFriendRequest,
  });

  final AuthSession session;
  final List<ProfileSummary> friends;
  final List<ProfileSummary> suggestions;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(ProfileSummary profile) onStartConversation;
  final Future<void> Function(ProfileSummary profile) onSendFriendRequest;

  @override
  Widget build(BuildContext context) {
    return _ShellScaffold(
      title: 'People',
      subtitle: 'Friends first, suggestions second.',
      session: session,
      onRefresh: onRefresh,
      isLoading: isLoading,
      errorMessage: errorMessage,
      children: <Widget>[
        const _SectionHeader(
          title: 'Friends',
          subtitle: 'Accepted connections are ready for private chats.',
        ),
        const SizedBox(height: 12),
        if (friends.isEmpty)
          const _EmptyStateCard(
            icon: Icons.group_outlined,
            title: 'No friends loaded yet',
            subtitle: 'The backend will fill this list when accepted connections are available.',
            actionLabel: 'Refresh',
            onAction: null,
          )
        else
          ...friends.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PersonTile(
                profile: profile,
                primaryLabel: 'Chat',
                primaryIcon: Icons.message_outlined,
                onPrimary: () => onStartConversation(profile),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Suggestions',
          subtitle: 'Potential connections from the backend social graph.',
        ),
        const SizedBox(height: 12),
        if (suggestions.isEmpty)
          const _EmptyStateCard(
            icon: Icons.person_search_outlined,
            title: 'No suggestions yet',
            subtitle: 'Contact sync or social graph signals will populate this list later.',
            actionLabel: 'Refresh',
            onAction: null,
          )
        else
          ...suggestions.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PersonTile(
                profile: profile,
                primaryLabel: 'Request',
                primaryIcon: Icons.person_add_alt_1,
                onPrimary: () => onSendFriendRequest(profile),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.session,
    required this.apiBaseUrl,
    required this.onSignOut,
  });

  final AuthSession session;
  final String apiBaseUrl;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;

    return _ShellScaffold(
      title: 'Profile',
      subtitle: 'Your secure session and account details.',
      session: session,
      onRefresh: () async {},
      isLoading: false,
      errorMessage: null,
      children: <Widget>[
        _ProfileHero(profile: profile),
        const SizedBox(height: 18),
        _DetailCard(
          title: 'Account',
          rows: <_DetailRow>[
            _DetailRow(label: 'Display name', value: profile.displayLabel),
            _DetailRow(label: 'Username', value: profile.username ?? '—'),
            _DetailRow(label: 'Email', value: profile.email ?? '—'),
            _DetailRow(label: 'Phone', value: profile.phoneNumber ?? '—'),
            _DetailRow(label: 'Firebase UID', value: profile.firebaseUid ?? '—'),
            _DetailRow(label: 'User ID', value: '${profile.vId}'),
          ],
        ),
        const SizedBox(height: 18),
        _DetailCard(
          title: 'Session',
          rows: <_DetailRow>[
            _DetailRow(label: 'Backend URL', value: apiBaseUrl),
            _DetailRow(label: 'JWT', value: _maskedToken(session.token)),
            _DetailRow(label: 'Phone verified', value: profile.phoneVerifiedAt == null ? 'No' : 'Yes'),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('This clears the saved JWT and returns to the login screen.'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true && context.mounted) {
              await onSignOut();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({
    required this.title,
    required this.subtitle,
    required this.session,
    required this.onRefresh,
    required this.isLoading,
    required this.errorMessage,
    required this.children,
  });

  final String title;
  final String subtitle;
  final AuthSession session;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF071018), Color(0xFF08131C), Color(0xFF061016)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              _TopHeader(session: session, title: title, subtitle: subtitle, onRefresh: onRefresh, isRefreshing: isLoading),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                _AlertCard(message: errorMessage!, onRetry: onRefresh),
              ],
              if (isLoading) const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final AuthSession session;
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AvatarBadge(profile: profile, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: isRefreshing ? null : () => onRefresh(),
          icon: isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.friendsCount,
    required this.chatsCount,
    required this.suggestionsCount,
    required this.onOpenChats,
    required this.onOpenPeople,
  });

  final ProfileSummary profile;
  final int friendsCount;
  final int chatsCount;
  final int suggestionsCount;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenPeople;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF10262F), Color(0xFF0D1720), Color(0xFF09131B)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AvatarBadge(profile: profile, size: 62),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onOpenChats,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Chats'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(profile.displayLabel, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('@${profile.username ?? 'unknown'} · vId ${profile.vId}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(label: '$friendsCount friends'),
              _StatusChip(label: '$chatsCount rooms'),
              _StatusChip(label: '$suggestionsCount suggestions'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionCard(
                  icon: Icons.group_outlined,
                  title: 'People',
                  subtitle: 'Friends and suggestions',
                  onTap: onOpenPeople,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.message_outlined,
                  title: 'Rooms',
                  subtitle: 'Open a conversation',
                  onTap: onOpenChats,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({
    required this.profiles,
    required this.onTapPerson,
  });

  final List<ProfileSummary> profiles;
  final Future<void> Function(ProfileSummary profile) onTapPerson;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.auto_awesome_outlined,
        title: 'No people to show yet',
        subtitle: 'Friends and suggestions will appear here once the backend returns data.',
        actionLabel: null,
        onAction: null,
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return InkWell(
            onTap: () => onTapPerson(profile),
            borderRadius: BorderRadius.circular(40),
            child: Column(
              children: <Widget>[
                _AvatarBadge(profile: profile, size: 68),
                const SizedBox(height: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    profile.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.preview, required this.onTap});

  final _RoomPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastMessage = preview.lastMessage;
    final previewText = lastMessage == null ? 'No messages yet' : lastMessage.previewText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1720),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: <Widget>[
              _AvatarBadge(profile: preview.peerProfile, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(preview.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(preview.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_formatTime(lastMessage?.createdAt ?? preview.room.updatedAt), style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.profile,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
  });

  final ProfileSummary profile;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _AvatarBadge(profile: profile, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onPrimary,
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF10262F), Color(0xFF0D1720), Color(0xFF09131B)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _AvatarBadge(profile: profile, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayLabel, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('vId ${profile.vId}', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.profile, required this.size});

  final ProfileSummary? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();
    final initials = _initials(profile?.displayLabel ?? profile?.username ?? 'Nirdist');

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundImage: NetworkImage(avatarUrl),
        child: Text(initials),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'N';
    }

    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word.substring(0, 1).toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1720),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1720),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
            ),
            child: Icon(icon, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.errorContainer.withValues(alpha: 0.9),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Column(
            children: List<Widget>.generate(rows.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(height: 20, color: Colors.white.withValues(alpha: 0.08));
              }

              return rows[index ~/ 2];
            }),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _RoomPreview {
  const _RoomPreview({
    required this.room,
    required this.peerProfile,
    required this.lastMessage,
  });

  final ChatRoomSummary room;
  final ProfileSummary? peerProfile;
  final ChatMessageSummary? lastMessage;

  String get title {
    final roomName = room.roomName?.trim();
    if (roomName != null && roomName.isNotEmpty) {
      return roomName;
    }

    if (room.isPrivate) {
      return peerProfile?.displayLabel ?? 'Private chat';
    }

    return 'Group chat ${room.roomId}';
  }

  String get subtitle {
    if (room.isPrivate) {
      final username = peerProfile?.username?.trim();
      if (username != null && username.isNotEmpty) {
        return '@$username';
      }

      return 'Private room';
    }

    return '${room.participantIds.length} people';
  }

}

String _maskedToken(String token) {
  if (token.isEmpty) {
    return '—';
  }

  if (token.length <= 10) {
    return '••••••••';
  }

  return '••••••••${token.substring(token.length - 10)}';
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '—';
  }

  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
/*
import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/chat_message_summary.dart';
import '../models/chat_room_summary.dart';
import '../models/profile_summary.dart';
import '../services/messenger_api_client.dart';
import 'conversation_screen.dart';

class MessengerShell extends StatefulWidget {
  const MessengerShell({
    super.key,
    required this.session,
    required this.apiBaseUrl,
    required this.onSignOut,
    this.apiClient,
  });

  final AuthSession session;
  final String apiBaseUrl;
  final Future<void> Function() onSignOut;
  final MessengerApiClient? apiClient;

  @override
  State<MessengerShell> createState() => _MessengerShellState();
}

class _MessengerShellState extends State<MessengerShell> {
  late final MessengerApiClient _apiClient = widget.apiClient ?? MessengerApiClient(
    apiBaseUrl: widget.apiBaseUrl,
    token: widget.session.token,
  );

  final List<ProfileSummary> _friends = <ProfileSummary>[];
  final List<ProfileSummary> _suggestions = <ProfileSummary>[];
  final List<_RoomPreview> _rooms = <_RoomPreview>[];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        session: widget.session,
        friends: List<ProfileSummary>.unmodifiable(_friends),
        suggestions: List<ProfileSummary>.unmodifiable(_suggestions),
        rooms: List<_RoomPreview>.unmodifiable(_rooms),
        isRefreshing: _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onOpenChats: () => setState(() => _selectedIndex = 1),
        onOpenPeople: () => setState(() => _selectedIndex = 2),
        onOpenRoom: _openRoom,
      ),
      _ChatsTab(
        session: widget.session,
        rooms: List<_RoomPreview>.unmodifiable(_rooms),
        isRefreshing: _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onOpenPeople: () => setState(() => _selectedIndex = 2),
        onOpenRoom: _openRoom,
      ),
      _PeopleTab(
        session: widget.session,
        friends: List<ProfileSummary>.unmodifiable(_friends),
        suggestions: List<ProfileSummary>.unmodifiable(_suggestions),
        isRefreshing: _isRefreshing,
        errorMessage: _errorMessage,
        onRefresh: _refresh,
        onOpenConversation: _openConversationWithProfile,
        onSendFriendRequest: _sendFriendRequest,
      ),
      _ProfileTab(
        session: widget.session,
        apiBaseUrl: widget.apiBaseUrl,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'People'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Future<void> _loadDashboard({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = widget.session.profile.vId;
      final friendsFuture = _apiClient.listFriends(userId);
      final suggestionsFuture = _apiClient.listSuggestions(userId);
      final roomsFuture = _apiClient.listRooms(userId);

      final friends = await friendsFuture;
      final suggestions = await suggestionsFuture;
      final rooms = await roomsFuture;

      final profilesById = <int, ProfileSummary>{
        for (final profile in <ProfileSummary>[widget.session.profile, ...friends, ...suggestions])
          profile.vId: profile,
      };

      final roomPreviews = await Future.wait(
        rooms.map((room) => _buildRoomPreview(room, profilesById)),
      );

      roomPreviews.sort((left, right) => right.sortKey.compareTo(left.sortKey));

      if (!mounted) {
        return;
      }

      setState(() {
        _friends
          ..clear()
          ..addAll(friends);
        _suggestions
          ..clear()
          ..addAll(suggestions);
        _rooms
          ..clear()
          ..addAll(roomPreviews);
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is MessengerApiException ? error.message : 'Unable to load messenger data.';
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refresh() => _loadDashboard(isRefresh: true);

  Future<void> _openRoom(_RoomPreview preview) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          session: widget.session,
          apiClient: _apiClient,
          room: preview.room,
          peerProfile: preview.peerProfile,
        ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openConversationWithProfile(ProfileSummary profile) async {
    final preview = _findRoomByPeer(profile.vId);
    if (preview != null) {
      await _openRoom(preview);
      return;
    }

    try {
      final room = await _apiClient.createPrivateRoom(
        createdBy: widget.session.profile.vId,
        participantVId: profile.vId,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            session: widget.session,
            apiClient: _apiClient,
            room: room,
            peerProfile: profile,
          ),
        ),
      );

      if (mounted) {
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        _showSnack(error is MessengerApiException ? error.message : 'Unable to open conversation.');
      }
    }
  }

  Future<void> _sendFriendRequest(ProfileSummary profile) async {
    try {
      await _apiClient.sendFriendRequest(
        requesterVId: widget.session.profile.vId,
        addresseeVId: profile.vId,
        requestMessage: 'Sent from Nirdist Messenger',
      );

      if (!mounted) {
        return;
      }

      _showSnack('Friend request sent to ${profile.displayLabel}.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showSnack(error is MessengerApiException ? error.message : 'Unable to send friend request.');
      }
    }
  }

  Future<_RoomPreview> _buildRoomPreview(ChatRoomSummary room, Map<int, ProfileSummary> profilesById) async {
    final peerProfile = _findPeerProfile(room, profilesById);
    final recentMessages = await _apiClient.listRecentMessages(room.roomId);
    final lastMessage = recentMessages.isEmpty ? null : recentMessages.last;

    return _RoomPreview(
      room: room,
      peerProfile: peerProfile,
      title: _roomTitle(room, peerProfile),
      subtitle: _roomSubtitle(room, peerProfile, lastMessage),
      lastMessage: lastMessage,
    );
  }

  ProfileSummary? _findPeerProfile(ChatRoomSummary room, Map<int, ProfileSummary> profilesById) {
    if (!room.isPrivate) {
      return null;
    }

    for (final participantId in room.participantIds) {
      if (participantId != widget.session.profile.vId) {
        return profilesById[participantId];
      }
    }

    return null;
  }

  _RoomPreview? _findRoomByPeer(int peerVId) {
    for (final preview in _rooms) {
      final participantIds = preview.room.participantIds;
      if (preview.room.isPrivate && participantIds.contains(widget.session.profile.vId) && participantIds.contains(peerVId)) {
        return preview;
      }
    }

    return null;
  }

  String _roomTitle(ChatRoomSummary room, ProfileSummary? peerProfile) {
    final roomName = room.roomName?.trim();
    if (roomName != null && roomName.isNotEmpty) {
      return roomName;
    }

    if (room.isPrivate) {
      return peerProfile?.displayLabel ?? 'Private chat';
    }

    return 'Group chat ${room.roomId}';
  }

  String _roomSubtitle(ChatRoomSummary room, ProfileSummary? peerProfile, ChatMessageSummary? lastMessage) {
    if (lastMessage == null) {
      return room.isPrivate ? 'Tap to send the first message' : '${room.participantIds.length} people';
    }

    final previewText = lastMessage.previewText;
    if (peerProfile != null) {
      return lastMessage.senderVId == widget.session.profile.vId ? 'You: $previewText' : previewText;
    }

    return previewText;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.session,
    required this.friends,
    required this.suggestions,
    required this.rooms,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onRefresh,
    required this.onOpenChats,
    required this.onOpenPeople,
    required this.onOpenRoom,
  });

  final AuthSession session;
  final List<ProfileSummary> friends;
  final List<ProfileSummary> suggestions;
  final List<_RoomPreview> rooms;
  final bool isRefreshing;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenPeople;
  final ValueChanged<_RoomPreview> onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final highlightProfiles = <ProfileSummary>[...friends, ...suggestions].take(8).toList(growable: false);

    return _DashboardScaffold(
      session: session,
      title: 'Home',
      subtitle: 'Messenger-style rooms backed by the existing Spring APIs.',
      onRefresh: onRefresh,
      isRefreshing: isRefreshing,
      errorMessage: errorMessage,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          _HeroCard(
            profile: session.profile,
            friendsCount: friends.length,
            roomsCount: rooms.length,
            suggestionsCount: suggestions.length,
            onOpenChats: onOpenChats,
            onOpenPeople: onOpenPeople,
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Stories',
            subtitle: 'A quick view of your network like Instagram, but data-driven.',
          ),
          const SizedBox(height: 12),
          _StoriesStrip(profiles: highlightProfiles, onTapProfile: onOpenPeople),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Recent rooms',
            subtitle: 'Tap a room to open the conversation screen.',
          ),
          const SizedBox(height: 12),
          if (rooms.isEmpty)
            _EmptyCard(
              icon: Icons.forum_outlined,
              title: 'No rooms yet',
              subtitle: 'Open People and start a private chat to populate this list.',
              actionLabel: 'Find people',
              onAction: onOpenPeople,
            )
          else
            ...rooms.take(3).map(
              (preview) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoomPreviewCard(
                  preview: preview,
                  onTap: () => onOpenRoom(preview),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({
    required this.session,
    required this.rooms,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onRefresh,
    required this.onOpenPeople,
    required this.onOpenRoom,
  });

  final AuthSession session;
  final List<_RoomPreview> rooms;
  final bool isRefreshing;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenPeople;
  final ValueChanged<_RoomPreview> onOpenRoom;

  @override
  Widget build(BuildContext context) {
    return _DashboardScaffold(
      session: session,
      title: 'Chats',
      subtitle: 'A simple room list with real backend previews.',
      onRefresh: onRefresh,
      isRefreshing: isRefreshing,
      errorMessage: errorMessage,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          if (rooms.isEmpty)
            _EmptyCard(
              icon: Icons.chat_bubble_outline,
              title: 'No active chats',
              subtitle: 'Create one from People and it will appear here.',
              actionLabel: 'Open people',
              onAction: onOpenPeople,
            )
          else
            ...rooms.map(
              (preview) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoomPreviewCard(
                  preview: preview,
                  onTap: () => onOpenRoom(preview),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab({
    required this.session,
    required this.friends,
    required this.suggestions,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onRefresh,
    required this.onOpenConversation,
    required this.onSendFriendRequest,
  });

  final AuthSession session;
  final List<ProfileSummary> friends;
  final List<ProfileSummary> suggestions;
  final bool isRefreshing;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final ValueChanged<ProfileSummary> onOpenConversation;
  final ValueChanged<ProfileSummary> onSendFriendRequest;

  @override
  Widget build(BuildContext context) {
    return _DashboardScaffold(
      session: session,
      title: 'People',
      subtitle: 'Friends can be messaged. Suggestions can be requested.',
      onRefresh: onRefresh,
      isRefreshing: isRefreshing,
      errorMessage: errorMessage,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          _SectionHeader(
            title: 'Friends',
            subtitle: 'Accepted connections can be opened instantly.',
          ),
          const SizedBox(height: 12),
          if (friends.isEmpty)
            _EmptyCard(
              icon: Icons.group_outlined,
              title: 'No friends yet',
              subtitle: 'Send a request to one of the suggested profiles below.',
              actionLabel: 'Refresh',
              onAction: onRefresh,
            )
          else
            ...friends.map(
              (friend) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PersonCard(
                  profile: friend,
                  tag: 'Friend',
                  primaryLabel: 'Chat',
                  secondaryLabel: 'Call',
                  onPrimary: () => onOpenConversation(friend),
                  onSecondary: () => _showSoonSnack(context, 'Call flow is coming in the next iteration.'),
                ),
              ),
            ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Suggestions',
            subtitle: 'Potential connections from the social graph.',
          ),
          const SizedBox(height: 12),
          if (suggestions.isEmpty)
            _EmptyCard(
              icon: Icons.person_search_outlined,
              title: 'No suggestions yet',
              subtitle: 'The social graph can surface more users once contacts sync is connected.',
              actionLabel: 'Refresh',
              onAction: onRefresh,
            )
          else
            ...suggestions.map(
              (profile) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PersonCard(
                  profile: profile,
                  tag: 'Suggested',
                  primaryLabel: 'Request',
                  secondaryLabel: 'Preview',
                  onPrimary: () => onSendFriendRequest(profile),
                  onSecondary: () => onOpenConversation(profile),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.session,
    required this.apiBaseUrl,
    required this.onSignOut,
  });

  final AuthSession session;
  final String apiBaseUrl;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return _DashboardScaffold(
      session: session,
      title: 'Profile',
      subtitle: 'Session details and secure storage status.',
      onRefresh: () async {},
      isRefreshing: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          _ProfileCard(profile: session.profile),
          const SizedBox(height: 18),
          _DetailCard(
            title: 'Session',
            rows: <_DetailRow>[
              _DetailRow(label: 'Backend URL', value: apiBaseUrl),
              _DetailRow(label: 'JWT', value: _maskedToken(session.token)),
              _DetailRow(label: 'Created', value: _formatDate(session.profile.createdAt)),
              _DetailRow(label: 'Updated', value: _formatDate(session.profile.updatedAt)),
            ],
          ),
          const SizedBox(height: 18),
          _DetailCard(
            title: 'Account',
            rows: <_DetailRow>[
              _DetailRow(label: 'Display name', value: session.profile.displayName ?? '—'),
              _DetailRow(label: 'Username', value: session.profile.username ?? '—'),
              _DetailRow(label: 'Email', value: session.profile.email ?? '—'),
              _DetailRow(label: 'Phone', value: session.profile.phoneNumber ?? '—'),
              _DetailRow(label: 'Firebase UID', value: session.profile.firebaseUid ?? '—'),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('This clears the stored JWT and returns to the login screen.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true && context.mounted) {
                await onSignOut();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.isRefreshing,
    required this.child,
    this.errorMessage,
  });

  final AuthSession session;
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF071018), Color(0xFF08131C), Color(0xFF061016)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: child is ListView
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _HeaderBar(session: session, title: title, subtitle: subtitle, isRefreshing: isRefreshing, onRefresh: onRefresh),
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: _AlertCard(message: errorMessage!, onRetry: onRefresh),
                      ),
                    ],
                    child,
                  ],
                )
              : Column(
                  children: <Widget>[
                    _HeaderBar(session: session, title: title, subtitle: subtitle, isRefreshing: isRefreshing, onRefresh: onRefresh),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _AlertCard(message: errorMessage!, onRetry: onRefresh),
                      ),
                    Expanded(child: child),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final AuthSession session;
  final String title;
  final String subtitle;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AvatarBadge(profile: session.profile, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: isRefreshing ? null : () => onRefresh(),
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.friendsCount,
    required this.roomsCount,
    required this.suggestionsCount,
    required this.onOpenChats,
    required this.onOpenPeople,
  });

  final ProfileSummary profile;
  final int friendsCount;
  final int roomsCount;
  final int suggestionsCount;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenPeople;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF10262F), Color(0xFF0D1720), Color(0xFF09131B)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AvatarBadge(profile: profile, size: 62),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onOpenChats,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Chats'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(profile.displayLabel, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('@${profile.username ?? 'unknown'} · vId ${profile.vId}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(label: 'Friends $friendsCount'),
              _StatusChip(label: 'Rooms $roomsCount'),
              _StatusChip(label: 'Suggestions $suggestionsCount'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_comment_outlined,
                  title: 'Open chats',
                  subtitle: 'Jump into existing rooms',
                  onTap: onOpenChats,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.group_outlined,
                  title: 'Find people',
                  subtitle: 'Browse friends and suggestions',
                  onTap: onOpenPeople,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({required this.profiles, required this.onTapProfile});

  final List<ProfileSummary> profiles;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return _EmptyCard(
        icon: Icons.auto_awesome_outlined,
        title: 'No people to show yet',
        subtitle: 'Friends and suggestions will appear here after the backend returns them.',
        actionLabel: 'Refresh',
        onAction: onTapProfile,
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return GestureDetector(
            onTap: onTapProfile,
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
                  ),
                  child: _AvatarBadge(profile: profile, size: 68),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    profile.displayLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoomPreviewCard extends StatelessWidget {
  const _RoomPreviewCard({required this.preview, required this.onTap});

  final _RoomPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1720),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: <Widget>[
              _AvatarBadge(profile: preview.peerProfile, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(preview.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(preview.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      preview.lastMessage?.previewText ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(_formatTime(preview.lastMessage?.createdAt ?? preview.room.updatedAt), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.profile,
    required this.tag,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final ProfileSummary profile;
  final String tag;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _AvatarBadge(profile: profile, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(profile.displayLabel, style: Theme.of(context).textTheme.titleMedium)),
                    _Tag(label: tag),
                  ],
                ),
                const SizedBox(height: 4),
                Text('@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(profile.phoneNumber ?? 'Phone not shared', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonal(onPressed: onPrimary, child: Text(primaryLabel)),
                    OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _AvatarBadge(profile: profile, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayLabel, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Text(profile.bio?.isNotEmpty == true ? profile.bio! : 'Signed in through the secure backend exchange.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1720),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
            ),
            child: Icon(icon, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.errorContainer.withValues(alpha: 0.9),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(message, style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.profile, required this.size});

  final ProfileSummary? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final display = profile?.displayLabel ?? 'Nirdist';
    final avatarUrl = profile?.avatarUrl?.trim();
    final initials = _initials(display);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallbackAvatar(initials),
          ),
        ),
      );
    }

    return _fallbackAvatar(initials);
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'N';
    }

    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word.substring(0, 1).toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Column(
            children: List<Widget>.generate(rows.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(height: 20, color: Colors.white.withValues(alpha: 0.08));
              }

              return rows[index ~/ 2];
            }),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _RoomPreview {
  const _RoomPreview({
    required this.room,
    required this.peerProfile,
    required this.title,
    required this.subtitle,
    required this.lastMessage,
  });

  final ChatRoomSummary room;
  final ProfileSummary? peerProfile;
  final String title;
  final String subtitle;
  final ChatMessageSummary? lastMessage;

  DateTime get sortKey => lastMessage?.createdAt ?? room.updatedAt ?? room.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String _maskedToken(String token) {
  if (token.isEmpty) {
    return '—';
  }

  if (token.length <= 10) {
    return '••••••••';
  }

  return '••••••••${token.substring(token.length - 10)}';
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return '—';
  }

  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '—';
  }

  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

void _showSoonSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
*/