class ChatMessageSummary {
  const ChatMessageSummary({
    required this.messageId,
    required this.roomId,
    required this.senderVId,
    required this.messageText,
    required this.mediaUrl,
    required this.messageType,
    required this.replyToId,
    required this.isDeleted,
    required this.createdAt,
  });

  final int messageId;
  final int roomId;
  final int senderVId;
  final String messageText;
  final String? mediaUrl;
  final String messageType;
  final int? replyToId;
  final bool isDeleted;
  final DateTime? createdAt;

  factory ChatMessageSummary.fromJson(Map<String, dynamic> json) {
    return ChatMessageSummary(
      messageId: (json['messageId'] as num?)?.toInt() ?? 0,
      roomId: (json['roomId'] as num?)?.toInt() ?? 0,
      senderVId: (json['senderVId'] as num?)?.toInt() ?? 0,
      messageText: json['messageText']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'TEXT',
      replyToId: (json['replyToId'] as num?)?.toInt(),
      isDeleted: json['isDeleted'] == true,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'messageId': messageId,
      'roomId': roomId,
      'senderVId': senderVId,
      'messageText': messageText,
      'mediaUrl': mediaUrl,
      'messageType': messageType,
      'replyToId': replyToId,
      'isDeleted': isDeleted,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  String get previewText {
    if (isDeleted) {
      return 'Message removed';
    }

    final trimmedText = messageText.trim();
    if (trimmedText.isNotEmpty) {
      return trimmedText;
    }

    final normalizedType = messageType.toUpperCase();
    if (mediaUrl != null && mediaUrl!.trim().isNotEmpty) {
      return switch (normalizedType) {
        'IMAGE' => 'Photo',
        'VIDEO' => 'Video',
        'AUDIO' => 'Voice note',
        'FILE' => 'File',
        _ => 'Attachment',
      };
    }

    return switch (normalizedType) {
      'SYSTEM' => 'System message',
      'IMAGE' => 'Photo',
      'VIDEO' => 'Video',
      'AUDIO' => 'Voice note',
      'FILE' => 'File',
      _ => 'New message',
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}