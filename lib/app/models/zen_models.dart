import 'package:zenverse/app/utils/user_code_util.dart';

class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required String userCode,
    this.level = 1,
    this.xpSession = 0,
    this.xpGames = 0,
    this.streakDays = 7,
  }) : userCode = normalizeUserCode(userCode);

  final String id;
  final String name;
  final String email;
  final String userCode;
  int level;
  int xpSession;
  int xpGames;
  int streakDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': name,
        'user_code': userCode,
        'email': email,
        'level': level,
        'xp_session': xpSession,
        'xp_games': xpGames,
        'streak_count': streakDays,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['display_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        userCode: json['user_code'] as String? ?? '',
        level: json['level'] as int? ?? 1,
        xpSession: json['xp_session'] as int? ?? 0,
        xpGames: json['xp_games'] as int? ?? 0,
        streakDays: json['streak_count'] as int? ?? 0,
      );
}

class FocusSession {
  FocusSession({
    required this.id,
    required this.userId,
    required this.planetId,
    required this.targetDurationSeconds,
    required this.mode,
    required this.status,
    required this.pointsEarned,
    required this.startTime,
    this.endTime,
    this.gaveUpAt,
    this.freezeHours,
  });

  final String id;
  final String userId;
  final String planetId;
  final int targetDurationSeconds;
  final String mode;
  final String status;
  final int pointsEarned;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? gaveUpAt;
  final int? freezeHours;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'planet_id': planetId,
        'target_duration_seconds': targetDurationSeconds,
        'mode': mode,
        'status': status,
        'points_earned': pointsEarned,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'gave_up_at': gaveUpAt?.toIso8601String(),
        'freeze_hours': freezeHours,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planetId: json['planet_id'] as String? ?? '',
        targetDurationSeconds: json['target_duration_seconds'] as int? ?? 0,
        mode: json['mode'] as String? ?? 'easy',
        status: json['status'] as String? ?? 'complete',
        pointsEarned: json['points_earned'] as int? ?? 0,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: json['end_time'] == null ? null : DateTime.parse(json['end_time'] as String),
        gaveUpAt: json['gave_up_at'] == null ? null : DateTime.parse(json['gave_up_at'] as String),
        freezeHours: json['freeze_hours'] as int?,
      );
}

class SessionParticipant {
  SessionParticipant({
    required this.sessionId,
    required this.userId,
    required this.joinedAt,
  });

  final String sessionId;
  final String userId;
  final DateTime joinedAt;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'user_id': userId,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory SessionParticipant.fromJson(Map<String, dynamic> json) => SessionParticipant(
        sessionId: json['session_id'] as String,
        userId: json['user_id'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

class DirectMessage {
  DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    this.sessionId,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime sentAt;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'session_id': sessionId,
        'content': content,
        'sent_at': sentAt.toIso8601String(),
      };

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        receiverId: json['receiver_id'] as String,
        content: json['content'] as String,
        sentAt: DateTime.parse(json['sent_at'] as String),
        sessionId: json['session_id'] as String?,
      );
}

class FriendProfile {
  FriendProfile({
    required this.id,
    required this.displayName,
    required String userCode,
    this.avatarUrl,
  }) : userCode = normalizeUserCode(userCode);

  final String id;
  final String displayName;
  final String userCode;
  final String? avatarUrl;

  factory FriendProfile.fromJson(Map<String, dynamic> json) => FriendProfile(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? 'Unknown',
        userCode: json['user_code'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class FriendshipRequest {
  FriendshipRequest({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.requesterProfile,
    this.addresseeProfile,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;
  final DateTime createdAt;
  final FriendProfile? requesterProfile;
  final FriendProfile? addresseeProfile;

  factory FriendshipRequest.fromJson(Map<String, dynamic> json) => FriendshipRequest(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(
          (json['requested_at'] ?? json['created_at']) as String,
        ),
      );
}
