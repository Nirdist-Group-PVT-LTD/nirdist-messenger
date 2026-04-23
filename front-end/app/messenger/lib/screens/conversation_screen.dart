import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/chat_message_summary.dart';
import '../models/chat_room_summary.dart';
import '../models/profile_summary.dart';
import '../services/messenger_api_client.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.session,
    required this.apiClient,
    required this.room,
    this.peerProfile,
  });

  final AuthSession session;
  final MessengerApiClient apiClient;
  final ChatRoomSummary room;
  final ProfileSummary? peerProfile;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageSummary> _messages = <ChatMessageSummary>[];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.peerProfile?.displayLabel ?? widget.room.roomName?.trim() ?? 'Chat ${widget.room.roomId}';
    final subtitle = widget.room.isPrivate
        ? 'Private room · ${widget.room.participantIds.length} people'
        : 'Group room · ${widget.room.participantIds.length} people';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            _Avatar(profile: widget.peerProfile, label: title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Call soon',
            onPressed: () => _showSnack('Call flow will hook into the backend in the next slice.'),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Room info',
            onPressed: () => _showSnack('Room ${widget.room.roomId} · ${widget.room.participantIds.length} participants'),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF071018), Color(0xFF08131C), Color(0xFF061016)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: colorScheme.errorContainer.withValues(alpha: 0.9),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(_errorMessage!, style: TextStyle(color: colorScheme.onErrorContainer))),
                      TextButton(
                        onPressed: _loadMessages,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? _EmptyConversationState(onStartChat: _focusComposer)
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _messages.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMine = message.senderVId == widget.session.profile.vId;
                              return _MessageBubble(
                                message: message,
                                isMine: isMine,
                                peerProfile: widget.peerProfile,
                              );
                            },
                          ),
              ),
              _Composer(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
                onCameraTap: () => _showSnack('Media sharing can be added after the first text chat slice.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await widget.apiClient.listMessages(widget.room.roomId);
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is MessengerApiException ? error.message : 'Unable to load messages.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final message = await widget.apiClient.sendMessage(
        roomId: widget.room.roomId,
        senderVId: widget.session.profile.vId,
        messageText: messageText,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = <ChatMessageSummary>[..._messages, message];
        _messageController.clear();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnack(error is MessengerApiException ? error.message : 'Unable to send the message.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _focusComposer() {
    FocusScope.of(context).requestFocus(FocusNode());
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
  }

  void _scrollToBottom({required bool animate}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final targetOffset = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.label});

  final ProfileSummary? profile;
  final String label;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();
    final fallbackText = label.isNotEmpty ? label[0].toUpperCase() : '?';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 21,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundImage: NetworkImage(avatarUrl),
        child: Text(fallbackText),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)]),
      ),
      child: Center(
        child: Text(
          fallbackText,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine, required this.peerProfile});

  final ChatMessageSummary message;
  final bool isMine;
  final ProfileSummary? peerProfile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? colorScheme.primary.withValues(alpha: 0.18) : const Color(0xFF0D1720);
    final borderColor = isMine ? colorScheme.primary.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.08);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 20),
            ),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMine && peerProfile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    peerProfile!.displayLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              Text(
                message.previewText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMine ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: (isMine ? colorScheme.onPrimary : colorScheme.onSurfaceVariant).withValues(alpha: 0.75),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
                ),
              ),
              child: const Icon(Icons.forum_outlined, color: Colors.black, size: 36),
            ),
            const SizedBox(height: 18),
            Text('No messages yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Send the first message to turn this room into a live Messenger-style thread.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: onStartChat,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Write message'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onCameraTap,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF09131B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onCameraTap,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Send a message',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isSending ? null : onSend,
            style: FilledButton.styleFrom(
              minimumSize: const Size(52, 52),
              shape: const CircleBorder(),
              backgroundColor: colorScheme.primary,
            ),
            child: isSending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                    ),
                  )
                : Icon(Icons.send_rounded, color: colorScheme.onPrimary, size: 20),
          ),
        ],
      ),
    );
  }
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