class ChatRoomSummary {
  const ChatRoomSummary({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participantIds,
  });

  final int roomId;
  final String? roomName;
  final String roomType;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<int> participantIds;

  factory ChatRoomSummary.fromJson(Map<String, dynamic> json) {
    return ChatRoomSummary(
      roomId: (json['roomId'] as num?)?.toInt() ?? 0,
      roomName: json['roomName']?.toString(),
      roomType: json['roomType']?.toString() ?? 'private',
      createdBy: (json['createdBy'] as num?)?.toInt(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      participantIds: _parseIntList(json['participantIds']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'roomId': roomId,
      'roomName': roomName,
      'roomType': roomType,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'participantIds': participantIds,
    };
  }

  bool get isPrivate => roomType.toLowerCase() == 'private';

  bool get isGroup => roomType.toLowerCase() == 'group';

  static List<int> _parseIntList(dynamic value) {
    if (value is! List) {
      return const <int>[];
    }

    return value
        .map((item) {
          if (item is num) {
            return item.toInt();
          }

          return int.tryParse(item?.toString() ?? '');
        })
        .whereType<int>()
        .toList(growable: false);
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}