class ProfileSummary {
  const ProfileSummary({
    required this.vId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.firebaseUid,
    required this.avatarUrl,
    required this.bio,
    required this.phoneVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int vId;
  final String? username;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? firebaseUid;
  final String? avatarUrl;
  final String? bio;
  final DateTime? phoneVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      vId: (json['vId'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString(),
      displayName: json['displayName']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      firebaseUid: json['firebaseUid']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      phoneVerifiedAt: _parseDateTime(json['phoneVerifiedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vId': vId,
      'username': username,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'firebaseUid': firebaseUid,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'phoneVerifiedAt': phoneVerifiedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  String get displayLabel {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }

    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle;
    }

    return 'Nirdist user';
  }

  String get initials {
    final parts = displayLabel
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'N';
    }

    if (parts.length == 1) {
      final value = parts.first;
      return value.length >= 2 ? value.substring(0, 2).toUpperCase() : value.substring(0, 1).toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}