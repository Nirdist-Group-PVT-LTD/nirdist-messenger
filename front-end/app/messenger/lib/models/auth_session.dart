import 'profile_summary.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.profile,
    required this.message,
    required this.created,
  });

  final String token;
  final ProfileSummary profile;
  final String message;
  final bool created;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const FormatException('Auth response missing profile payload.');
    }

    return AuthSession(
      token: json['token']?.toString() ?? '',
      profile: ProfileSummary.fromJson(profileJson),
      message: json['message']?.toString() ?? '',
      created: json['created'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token': token,
      'profile': profile.toJson(),
      'message': message,
      'created': created,
    };
  }
}