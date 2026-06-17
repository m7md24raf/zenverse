import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/utils/user_code_util.dart';

class RemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> upsertUser(UserProfile user) async {
    final payload = user.toJson()..remove('email');
    payload['user_code'] = normalizeUserCode(payload['user_code'] as String? ?? '');
    await _client.from('profiles').upsert(payload);
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  /// Updates onboarding fields saved to [profiles].
  Future<void> updateProfileOnboardingPrefs({
    required String userId,
    required String displayName,
    required String avatarUrl,
    required int dailyGoalSessions,
    required String timezone,
  }) async {
    await _client.from('profiles').update({
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'daily_goal_sessions': dailyGoalSessions,
      'timezone': timezone,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> updateProfileDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> patchProfileUserCode({
    required String userId,
    required String userCode,
  }) async {
    await _client.from('profiles').update({
      'user_code': normalizeUserCode(userCode),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Persists unlocked ambient music track IDs (requires `music_unlocks` text[] on profiles).
  Future<void> syncMusicUnlocks({
    required String userId,
    required List<String> trackIds,
  }) async {
    await _client.from('profiles').update({
      'music_unlocks': trackIds,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> incrementGameXp({
    required String userId,
    required int amount,
  }) async {
    final profile = await getProfileById(userId);
    if (profile == null) return;
    final current = profile['xp_games'] as int? ?? 0;
    await _client
        .from('profiles')
        .update({'xp_games': current + amount, 'updated_at': DateTime.now().toIso8601String()}).eq('id', userId);
  }

  Future<void> incrementSessionXp({
    required String userId,
    required int amount,
  }) async {
    final profile = await getProfileById(userId);
    if (profile == null) return;
    final current = profile['xp_session'] as int? ?? 0;
    await _client.from('profiles').update({
      'xp_session': current + amount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<bool> consumeFreezeCredit({
    required String userId,
    required DateTime day,
    required String reason,
  }) async {
    final profile = await getProfileById(userId);
    if (profile == null) return false;
    final credits = profile['freeze_credits'] as int? ?? 0;
    if (credits <= 0) return false;
    final next = credits - 1;
    await _client.from('profiles').update({
      'freeze_credits': next,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    await _client.from('streak_freeze_logs').insert({
      'user_id': userId,
      'day': day.toIso8601String().split('T').first,
      'reason': reason,
      'credits_before': credits,
      'credits_after': next,
    });
    return true;
  }

  Future<void> upsertStreakDaily({
    required String userId,
    required DateTime day,
    required int completedSessions,
    required int streakAfterDay,
    required bool protectedByFreeze,
  }) async {
    await _client.from('streak_daily').upsert({
      'user_id': userId,
      'day': day.toIso8601String().split('T').first,
      'completed_sessions': completedSessions,
      'goal_sessions': 1,
      'streak_after_day': streakAfterDay,
      'was_protected_by_freeze': protectedByFreeze,
    });
  }

  Future<List<FocusSession>> listSessionsForUser(String userId, {int limit = 1000}) async {
    final rows = await _client.from('sessions').select().eq('user_id', userId).order('start_time', ascending: false).limit(limit);
    return rows.map((e) => FocusSession.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> upsertRemoteSyncQueue({
    required String userId,
    required String clientActionId,
    required String actionType,
    required Map<String, dynamic> payload,
    required String conflictStatus,
    String? conflictReason,
    int retries = 0,
  }) async {
    await _client.from('sync_queue').upsert({
      'user_id': userId,
      'client_action_id': clientActionId,
      'action_type': actionType,
      'entity_table': payload['entity_table'] ?? actionType,
      'entity_id': payload['entity_id'],
      'payload': payload,
      'client_created_at': payload['client_created_at'] ?? DateTime.now().toIso8601String(),
      'conflict_status': conflictStatus,
      'conflict_reason': conflictReason,
      'retries': retries,
      if (conflictStatus == 'applied') 'resolved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<FocusSession?> getSessionById(String sessionId) async {
    final row = await _client.from('sessions').select().eq('id', sessionId).maybeSingle();
    if (row == null) return null;
    return FocusSession.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> insertSession(FocusSession session) async {
    await _client.from('sessions').insert(session.toJson()..removeWhere((_, value) => value == null));
  }

  Future<void> updateSessionStatus({
    required String sessionId,
    required String status,
    required DateTime endTime,
    DateTime? gaveUpAt,
    int? freezeHours,
    int? pointsEarned,
  }) async {
    await _client.from('sessions').update({
      'status': status,
      'end_time': endTime.toIso8601String(),
      'gave_up_at': gaveUpAt?.toIso8601String(),
      'freeze_hours': freezeHours,
      if (pointsEarned != null) 'points_earned': pointsEarned,
    }).eq('id', sessionId);
  }

  Future<void> sendFriendRequest({
    required String requesterId,
    required String addresseeId,
  }) async {
    await _client.from('friendships').insert({
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  Future<List<FriendProfile>> listAcceptedFriends(String currentUserId) async {
    final friendshipRows = await _client
        .from('friendships')
        .select('requester_id, addressee_id')
        .eq('status', 'accepted')
        .or('requester_id.eq.$currentUserId,addressee_id.eq.$currentUserId');

    final friendIds = <String>{};
    for (final row in friendshipRows) {
      final map = Map<String, dynamic>.from(row);
      final requesterId = map['requester_id'] as String;
      final addresseeId = map['addressee_id'] as String;
      if (requesterId == currentUserId) {
        friendIds.add(addresseeId);
      } else {
        friendIds.add(requesterId);
      }
    }
    if (friendIds.isEmpty) return [];

    final profileRows = await _client
        .from('profiles')
        .select('id, display_name, user_code, avatar_url')
        .inFilter('id', friendIds.toList())
        .order('display_name');
    return profileRows.map((e) => FriendProfile.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<FriendProfile?> findProfileByUserCode(String userCode) async {
    final queryCode = normalizeUserCode(userCode);
    if (queryCode.isEmpty) return null;

    try {
      final rpcResult = await _client.rpc(
        'find_profile_by_user_code',
        params: {'p_code': queryCode},
      );
      if (rpcResult != null) {
        final map = Map<String, dynamic>.from(rpcResult as Map);
        if (map['id'] != null) {
          return FriendProfile.fromJson(map);
        }
      }
    } catch (_) {
      // RPC may not exist until migration is applied; fall back to direct select.
    }

    final row = await _client
        .from('profiles')
        .select('id, display_name, user_code, avatar_url')
        .eq('user_code', queryCode)
        .maybeSingle();
    if (row == null) return null;
    return FriendProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<FriendshipRequest>> listPendingIncomingRequests(String currentUserId) async {
    final rows = await _client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, requested_at')
        .eq('addressee_id', currentUserId)
        .eq('status', 'pending')
        .order('requested_at', ascending: false);
    if (rows.isEmpty) return [];

    final requesterIds = rows.map((e) => e['requester_id'] as String).toSet().toList();
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name, user_code, avatar_url')
        .inFilter('id', requesterIds);
    final profileMap = {
      for (final row in profileRows)
        (row['id'] as String): FriendProfile.fromJson(Map<String, dynamic>.from(row)),
    };

    return rows.map((e) {
      final req = FriendshipRequest.fromJson(Map<String, dynamic>.from(e));
      return FriendshipRequest(
        id: req.id,
        requesterId: req.requesterId,
        addresseeId: req.addresseeId,
        status: req.status,
        createdAt: req.createdAt,
        requesterProfile: profileMap[req.requesterId],
      );
    }).toList();
  }

  Future<void> updateFriendRequestStatus({
    required String friendshipId,
    required String status,
  }) async {
    await _client.from('friendships').update({
      'status': status,
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id', friendshipId);
  }

  Future<void> addSessionParticipant({
    required String sessionId,
    required String userId,
  }) async {
    await _client.from('session_participants').upsert({
      'session_id': sessionId,
      'user_id': userId,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SessionParticipant>> listSessionParticipants(String sessionId) async {
    final rows = await _client.from('session_participants').select().eq('session_id', sessionId).order('joined_at');
    return rows.map((e) => SessionParticipant.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  RealtimeChannel subscribeSessionParticipants({
    required String channelName,
    required String sessionId,
    required void Function() onChange,
  }) {
    final channel = _client.channel(channelName);
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'session_participants',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'session_id',
          value: sessionId,
        ),
        callback: (_) => onChange(),
      )
      ..subscribe();
    return channel;
  }

  Future<List<DirectMessage>> listDirectMessages({
    required String userA,
    required String userB,
    int limit = 100,
  }) async {
    final filter = 'and(sender_id.eq.$userA,receiver_id.eq.$userB),and(sender_id.eq.$userB,receiver_id.eq.$userA)';
    final rows = await _client.from('messages').select().or(filter).order('sent_at', ascending: true).limit(limit);
    return rows.map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? sessionId,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'session_id': sessionId,
      'content': content,
    });
  }

  Future<void> markMessageRead({
    required String messageId,
    required String userId,
  }) async {
    await _client.from('message_receipts').upsert({
      'message_id': messageId,
      'user_id': userId,
      'read_at': DateTime.now().toIso8601String(),
    });
  }

  RealtimeChannel subscribeDirectMessages({
    required String channelName,
    required String userA,
    required String userB,
    required void Function() onChange,
  }) {
    final channel = _client.channel(channelName);
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final row = payload.newRecord;
          final sender = row['sender_id'] as String?;
          final receiver = row['receiver_id'] as String?;
          final matches = (sender == userA && receiver == userB) || (sender == userB && receiver == userA);
          if (matches) onChange();
        },
      )
      ..subscribe();
    return channel;
  }

  RealtimeChannel subscribeFriendships({
    required String channelName,
    required String currentUserId,
    required void Function() onChange,
  }) {
    final channel = _client.channel(channelName);
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friendships',
        callback: (payload) {
          final row = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
          final requesterId = row['requester_id'] as String?;
          final addresseeId = row['addressee_id'] as String?;
          if (requesterId == currentUserId || addresseeId == currentUserId) {
            onChange();
          }
        },
      )
      ..subscribe();
    return channel;
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
