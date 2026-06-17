import 'dart:async';
import 'dart:math';

import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/repositories/local/local_data_source.dart';
import 'package:zenverse/app/repositories/remote/remote_data_source.dart';
import 'package:zenverse/app/utils/user_code_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ZenRepository {
  ZenRepository({
    required this.local,
    required this.remote,
  });

  final LocalDataSource local;
  final RemoteDataSource remote;
  final Map<String, RealtimeChannel> _participantChannels = {};
  final Map<String, RealtimeChannel> _chatChannels = {};
  final Map<String, RealtimeChannel> _friendshipChannels = {};

  /// After email/password sign-up: profile row must match schema (display_name, user_code, etc.).
  Future<UserProfile> createProfileAfterEmailSignUp({
    required String userId,
    required String email,
  }) async {
    final displayName = _displayNameFromEmailLocalPart(email);
    final userCode = _randomZenUserCodeFour();
    final user = UserProfile(
      id: userId,
      name: displayName,
      email: email.trim(),
      userCode: userCode,
      level: 1,
      xpSession: 0,
      xpGames: 0,
      streakDays: 7,
    );
    await local.saveProfile(user);
    await local.setUserId(user.id);
    await local.setLoggedIn(true);
    await _enqueue('upsert_user', {...user.toJson(), 'updated_at': DateTime.now().toIso8601String()});
    await flushSyncQueue();
    return user;
  }

  String _displayNameFromEmailLocalPart(String email) {
    final trimmed = email.trim();
    final local = trimmed.contains('@') ? trimmed.split('@').first.trim() : trimmed;
    if (local.length >= 2) {
      return local.length > 60 ? local.substring(0, 60) : local;
    }
    if (local.length == 1) return '$local$local';
    return 'ZenUser';
  }

  /// `ZEN-` + 4 random uppercase alphanumeric (matches ^ZEN-[A-Z0-9]{4,8}$).
  String _randomZenUserCodeFour() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    final suffix = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'ZEN-$suffix';
  }

  /// Ensures the signed-in user's profile row exists in Supabase with a searchable [user_code].
  Future<UserProfile> syncCurrentUserProfileToRemote({
    required String userId,
    required String fallbackEmail,
  }) async {
    final cached = local.getProfileJson();
    final remoteRow = await remote.getProfileById(userId);

    var displayName =
        (cached?['display_name'] as String?)?.trim() ??
        (remoteRow?['display_name'] as String?)?.trim() ??
        _displayNameFromEmailLocalPart(fallbackEmail);
    if (displayName.isEmpty) {
      displayName = _displayNameFromEmailLocalPart(fallbackEmail);
    }

    final localCode = normalizeUserCode(cached?['user_code'] as String? ?? '');
    final remoteCode = normalizeUserCode(remoteRow?['user_code'] as String? ?? '');
    var userCode = localCode.isNotEmpty ? localCode : remoteCode;
    if (userCode.isEmpty) {
      userCode = _randomZenUserCodeFour();
    }

    final synced = UserProfile(
      id: userId,
      name: displayName,
      email: fallbackEmail.trim(),
      userCode: userCode,
      level: remoteRow?['level'] as int? ?? cached?['level'] as int? ?? 1,
      xpSession: remoteRow?['xp_session'] as int? ?? cached?['xp_session'] as int? ?? 0,
      xpGames: remoteRow?['xp_games'] as int? ?? cached?['xp_games'] as int? ?? 0,
      streakDays: remoteRow?['streak_count'] as int? ?? cached?['streak_count'] as int? ?? 0,
    );

    await remote.upsertUser(synced);
    await local.saveProfile(synced);
    await local.setUserId(userId);
    await local.setLoggedIn(true);
    return synced;
  }

  static String onboardingHiveKeyForUser(String userId) => 'onboarding_complete_$userId';

  /// Persists onboarding choices to Supabase `profiles`, then refreshes local cache from remote.
  Future<void> saveProfileOnboarding({
    required String userId,
    required String email,
    required String displayName,
    required String avatarPresetId,
    required int dailyGoalSessions,
    required String timezone,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError.value(displayName, 'displayName', 'Display name too short.');
    }
    await remote.updateProfileOnboardingPrefs(
      userId: userId,
      displayName: trimmed,
      avatarUrl: 'preset:$avatarPresetId',
      dailyGoalSessions: dailyGoalSessions,
      timezone: timezone,
    );
    await refreshLocalProfileFromRemote(userId: userId, fallbackEmail: email);
  }

  Future<void> refreshLocalProfileFromRemote({
    required String userId,
    required String fallbackEmail,
  }) async {
    final row = await remote.getProfileById(userId);
    if (row == null) return;
    final user = UserProfile(
      id: userId,
      name: row['display_name'] as String? ?? _displayNameFromEmailLocalPart(fallbackEmail),
      email: fallbackEmail.trim(),
      userCode: normalizeUserCode(row['user_code'] as String? ?? ''),
      level: row['level'] as int? ?? 1,
      xpSession: row['xp_session'] as int? ?? 0,
      xpGames: row['xp_games'] as int? ?? 0,
      streakDays: row['streak_count'] as int? ?? 0,
    );
    await local.saveProfile(user);
    await local.setUserId(user.id);
    await local.setLoggedIn(true);
  }

  Future<UserProfile> createUser({
    required String userId,
    required String name,
    required String email,
  }) async {
    final userCode = _randomZenUserCodeFour();
    final user = UserProfile(
      id: userId,
      name: name,
      email: email,
      userCode: userCode,
      streakDays: 7,
    );
    await local.saveProfile(user);
    await local.setUserId(user.id);
    await local.setLoggedIn(true);
    await _enqueue('upsert_user', {...user.toJson(), 'updated_at': DateTime.now().toIso8601String()});
    await flushSyncQueue();
    return user;
  }

  Future<void> createOrUpdateProfileOnLogin({
    required String userId,
    required String displayName,
    required String email,
  }) async {
    final existing = await remote.getProfileById(userId);
    if (existing == null) {
      final user = UserProfile(
        id: userId,
        name: displayName,
        email: email,
        userCode: _randomZenUserCodeFour(),
        streakDays: 7,
      );
      await local.saveProfile(user);
      await local.setUserId(userId);
      await local.setLoggedIn(true);
      await _enqueue('upsert_user', user.toJson());
      await flushSyncQueue();
      await syncCurrentUserProfileToRemote(userId: userId, fallbackEmail: email);
      return;
    }

    var userCode = normalizeUserCode(existing['user_code'] as String? ?? '');
    if (userCode.isEmpty) {
      userCode = _randomZenUserCodeFour();
    }
    await remote.patchProfileUserCode(userId: userId, userCode: userCode);

    final user = UserProfile(
      id: userId,
      name: (existing['display_name'] as String?)?.trim().isNotEmpty == true
          ? existing['display_name'] as String
          : displayName,
      email: email,
      userCode: userCode,
      level: existing['level'] as int? ?? 1,
      xpSession: existing['xp_session'] as int? ?? 0,
      xpGames: existing['xp_games'] as int? ?? 0,
      streakDays: existing['streak_count'] as int? ?? 0,
    );
    await local.saveProfile(user);
    await local.setUserId(userId);
    await local.setLoggedIn(true);
    await syncCurrentUserProfileToRemote(userId: userId, fallbackEmail: email);
  }

  Future<void> updateEditableProfile({
    required String userId,
    required String displayName,
    required String email,
  }) async {
    await remote.updateProfileDisplayName(userId: userId, displayName: displayName);
    final cached = local.getProfileJson();
    final user = UserProfile(
      id: userId,
      name: displayName.trim(),
      email: email.trim(),
      userCode: cached?['user_code'] as String? ?? '',
      level: cached?['level'] as int? ?? 1,
      xpSession: cached?['xp_session'] as int? ?? 0,
      xpGames: cached?['xp_games'] as int? ?? 0,
      streakDays: cached?['streak_count'] as int? ?? 0,
    );
    await local.saveProfile(user);
    await _enqueue('upsert_user', {...user.toJson(), 'updated_at': DateTime.now().toIso8601String()});
    await flushSyncQueue();
  }

  Future<void> sendSessionInvites({
    required String hostId,
    required String sessionId,
    required List<String> friendIds,
    required String message,
  }) async {
    for (final friendId in friendIds) {
      await remote.sendMessage(
        senderId: hostId,
        receiverId: friendId,
        content: message,
        sessionId: sessionId,
      );
    }
  }

  Future<void> awardGameXp({
    required String? userId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    await _adjustLocalXp(gameDelta: amount);
    if (userId != null && userId.isNotEmpty) {
      await _enqueue('profile_increment_game_xp', {
        'user_id': userId,
        'amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await flushSyncQueue();
    }
  }

  Future<void> awardSessionXp({
    required String? userId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    await _adjustLocalXp(sessionDelta: amount);
    if (userId != null && userId.isNotEmpty) {
      await _enqueue('profile_increment_session_xp', {
        'user_id': userId,
        'amount': amount,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await flushSyncQueue();
    }
  }

  Future<bool> spendSessionXp({
    required String? userId,
    required int amount,
  }) async {
    if (amount <= 0) return true;
    final current = _localSessionXp();
    if (current < amount) return false;
    await _adjustLocalXp(sessionDelta: -amount);
    if (userId != null && userId.isNotEmpty) {
      await remote.incrementSessionXp(userId: userId, amount: -amount);
    }
    return true;
  }

  Future<bool> spendGameXp({
    required String? userId,
    required int amount,
  }) async {
    if (amount <= 0) return true;
    final current = _localGameXp();
    if (current < amount) return false;
    await _adjustLocalXp(gameDelta: -amount);
    if (userId != null && userId.isNotEmpty) {
      await remote.incrementGameXp(userId: userId, amount: -amount);
    }
    return true;
  }

  int _localSessionXp() => local.getProfileJson()?['xp_session'] as int? ?? 0;

  int _localGameXp() => local.getProfileJson()?['xp_games'] as int? ?? 0;

  Future<void> _adjustLocalXp({int sessionDelta = 0, int gameDelta = 0}) async {
    final raw = local.getProfileJson();
    final userId = local.userId ?? 'guest';
    final profile = UserProfile(
      id: raw?['id'] as String? ?? userId,
      name: raw?['display_name'] as String? ?? 'Guest',
      email: raw?['email'] as String? ?? '',
      userCode: raw?['user_code'] as String? ?? '',
      level: raw?['level'] as int? ?? 1,
      xpSession: (raw?['xp_session'] as int? ?? 0) + sessionDelta,
      xpGames: (raw?['xp_games'] as int? ?? 0) + gameDelta,
      streakDays: raw?['streak_count'] as int? ?? 0,
    );
    await local.saveProfile(profile);
  }

  Future<void> syncMusicUnlocks({
    required String userId,
    required List<String> trackIds,
  }) async {
    try {
      await remote.syncMusicUnlocks(userId: userId, trackIds: trackIds);
    } catch (_) {
      // Column may not exist until migration is applied; local Hive/prefs still work.
    }
  }

  Future<List<FocusSession>> listSessionsForUser(String userId, {int limit = 1000}) {
    return remote.listSessionsForUser(userId, limit: limit);
  }

  Future<bool> consumeFreezeCredit({
    required String userId,
    required DateTime day,
    required String reason,
  }) async {
    return remote.consumeFreezeCredit(userId: userId, day: day, reason: reason);
  }

  Future<void> upsertStreakDaily({
    required String userId,
    required DateTime day,
    required int completedSessions,
    required int streakAfterDay,
    required bool protectedByFreeze,
  }) async {
    await _enqueue('streak_daily_upsert', {
      'user_id': userId,
      'day': day.toIso8601String(),
      'completed_sessions': completedSessions,
      'streak_after_day': streakAfterDay,
      'protected_by_freeze': protectedByFreeze,
    });
    await flushSyncQueue();
  }

  Future<void> addSession(FocusSession session) async {
    await _enqueue('session_insert', session.toJson());
    await flushSyncQueue();
  }

  Future<void> updateSessionStatus({
    required String sessionId,
    required String status,
    required DateTime endTime,
    DateTime? gaveUpAt,
    int? freezeHours,
    int? pointsEarned,
  }) async {
    await _enqueue('session_update_status', {
      'session_id': sessionId,
      'status': status,
      'end_time': endTime.toIso8601String(),
      'gave_up_at': gaveUpAt?.toIso8601String(),
      'freeze_hours': freezeHours,
      'points_earned': pointsEarned,
    });
    await flushSyncQueue();
  }

  Future<void> addSessionParticipant({
    required String sessionId,
    required String userId,
  }) async {
    await _enqueue('session_participant_upsert', {
      'session_id': sessionId,
      'user_id': userId,
      'joined_at': DateTime.now().toIso8601String(),
    });
    await flushSyncQueue();
  }

  Future<void> enqueueFriendRequest({
    required String requesterId,
    required String addresseeId,
  }) async {
    await _enqueue('friendship_insert', {
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
    await flushSyncQueue();
  }

  Future<FriendProfile?> findProfileByUserCode(String userCode) {
    return remote.findProfileByUserCode(normalizeUserCode(userCode));
  }

  Future<List<FriendshipRequest>> listPendingIncomingRequests(String currentUserId) {
    return remote.listPendingIncomingRequests(currentUserId);
  }

  Future<void> updateFriendRequestStatus({
    required String friendshipId,
    required String status,
  }) async {
    await _enqueue('friendship_update_status', {
      'friendship_id': friendshipId,
      'status': status,
    });
    await flushSyncQueue();
  }

  Future<void> sendDirectMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? sessionId,
  }) async {
    await _enqueue('message_insert', {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'session_id': sessionId,
    });
    await flushSyncQueue();
  }

  Future<List<DirectMessage>> fetchDirectMessages({
    required String userA,
    required String userB,
  }) {
    return remote.listDirectMessages(userA: userA, userB: userB);
  }

  Future<void> markDirectMessageRead({
    required String messageId,
    required String userId,
  }) {
    return remote.markMessageRead(messageId: messageId, userId: userId);
  }

  Future<List<FriendProfile>> listAcceptedFriends(String currentUserId) {
    return remote.listAcceptedFriends(currentUserId);
  }

  Stream<List<SessionParticipant>> watchSessionParticipants(String sessionId) {
    final controller = StreamController<List<SessionParticipant>>.broadcast();
    final channelName = 'session-participants-$sessionId';

    Future<void> load() async {
      final rows = await remote.listSessionParticipants(sessionId);
      if (!controller.isClosed) controller.add(rows);
    }

    load();
    _participantChannels[channelName]?.let(remote.removeChannel);
    _participantChannels[channelName] = remote.subscribeSessionParticipants(
      channelName: channelName,
      sessionId: sessionId,
      onChange: load,
    );

    controller.onCancel = () async {
      final c = _participantChannels.remove(channelName);
      if (c != null) await remote.removeChannel(c);
    };
    return controller.stream;
  }

  Stream<List<DirectMessage>> watchDirectMessages({
    required String userA,
    required String userB,
  }) {
    final controller = StreamController<List<DirectMessage>>.broadcast();
    final channelName = 'messages-$userA-$userB';

    Future<void> load() async {
      final rows = await remote.listDirectMessages(userA: userA, userB: userB);
      if (!controller.isClosed) controller.add(rows);
    }

    load();
    _chatChannels[channelName]?.let(remote.removeChannel);
    _chatChannels[channelName] = remote.subscribeDirectMessages(
      channelName: channelName,
      userA: userA,
      userB: userB,
      onChange: load,
    );

    controller.onCancel = () async {
      final c = _chatChannels.remove(channelName);
      if (c != null) await remote.removeChannel(c);
    };
    return controller.stream;
  }

  Stream<void> watchFriendships(String currentUserId) {
    final controller = StreamController<void>.broadcast();
    final channelName = 'friendships-$currentUserId';

    _friendshipChannels[channelName]?.let(remote.removeChannel);
    _friendshipChannels[channelName] = remote.subscribeFriendships(
      channelName: channelName,
      currentUserId: currentUserId,
      onChange: () {
        if (!controller.isClosed) controller.add(null);
      },
    );

    controller.onCancel = () async {
      final c = _friendshipChannels.remove(channelName);
      if (c != null) await remote.removeChannel(c);
    };
    return controller.stream;
  }

  Future<void> flushSyncQueue() async {
    final queue = local.getSyncQueue();
    if (queue.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final entry in queue) {
      final nextRetryAtRaw = entry['next_retry_at'] as String?;
      if (nextRetryAtRaw != null && DateTime.tryParse(nextRetryAtRaw)?.isAfter(now) == true) {
        remaining.add(entry);
        continue;
      }

      final clientActionId = (entry['client_action_id'] as String?) ?? _newActionId();
      final retries = entry['retries'] as int? ?? 0;
      entry['client_action_id'] = clientActionId;

      try {
        final type = entry['type'] as String;
        final payload = Map<String, dynamic>.from(entry['payload'] as Map);
        if (type == 'upsert_user') {
          final userId = payload['id'] as String;
          final remoteProfile = await remote.getProfileById(userId);
          final localUpdatedAt = DateTime.tryParse(payload['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final remoteUpdatedAt = DateTime.tryParse(remoteProfile?['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (remoteProfile != null && remoteUpdatedAt.isAfter(localUpdatedAt)) {
            await _logSyncApplied(
              userId: userId,
              clientActionId: clientActionId,
              actionType: type,
              payload: payload,
              conflictStatus: 'conflict',
              conflictReason: 'Skipped by LWW (remote newer updated_at)',
              retries: retries,
            );
            continue;
          }
          await remote.upsertUser(
            UserProfile(
              id: userId,
              name: payload['display_name'] as String,
              email: '',
              userCode: payload['user_code'] as String,
              level: payload['level'] as int? ?? 1,
              xpSession: payload['xp_session'] as int? ?? 0,
              xpGames: payload['xp_games'] as int? ?? 0,
              streakDays: payload['streak_count'] as int? ?? 7,
            ),
          );
          await _logSyncApplied(
            userId: userId,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'session_insert') {
          await remote.insertSession(
            FocusSession(
              id: payload['id'] as String,
              userId: payload['user_id'] as String,
              planetId: payload['planet_id'] as String? ?? '',
              targetDurationSeconds: payload['target_duration_seconds'] as int,
              mode: payload['mode'] as String,
              status: payload['status'] as String,
              pointsEarned: payload['points_earned'] as int,
              startTime: DateTime.parse(payload['start_time'] as String),
              endTime: payload['end_time'] == null ? null : DateTime.parse(payload['end_time'] as String),
              gaveUpAt: payload['gave_up_at'] == null ? null : DateTime.parse(payload['gave_up_at'] as String),
              freezeHours: payload['freeze_hours'] as int?,
            ),
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'session_update_status') {
          await remote.updateSessionStatus(
            sessionId: payload['session_id'] as String,
            status: payload['status'] as String,
            endTime: DateTime.parse(payload['end_time'] as String),
            gaveUpAt: payload['gave_up_at'] == null ? null : DateTime.parse(payload['gave_up_at'] as String),
            freezeHours: payload['freeze_hours'] as int?,
            pointsEarned: payload['points_earned'] as int?,
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String? ?? local.userId ?? '',
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'session_participant_upsert') {
          await remote.addSessionParticipant(
            sessionId: payload['session_id'] as String,
            userId: payload['user_id'] as String,
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'friendship_insert') {
          await remote.sendFriendRequest(
            requesterId: payload['requester_id'] as String,
            addresseeId: payload['addressee_id'] as String,
          );
          await _logSyncApplied(
            userId: payload['requester_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'friendship_update_status') {
          await remote.updateFriendRequestStatus(
            friendshipId: payload['friendship_id'] as String,
            status: payload['status'] as String,
          );
          await _logSyncApplied(
            userId: local.userId ?? '',
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'message_insert') {
          await remote.sendMessage(
            senderId: payload['sender_id'] as String,
            receiverId: payload['receiver_id'] as String,
            content: payload['content'] as String,
            sessionId: payload['session_id'] as String?,
          );
          await _logSyncApplied(
            userId: payload['sender_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'profile_increment_game_xp') {
          await remote.incrementGameXp(
            userId: payload['user_id'] as String,
            amount: payload['amount'] as int,
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'profile_increment_session_xp') {
          await remote.incrementSessionXp(
            userId: payload['user_id'] as String,
            amount: payload['amount'] as int,
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        } else if (type == 'streak_daily_upsert') {
          await remote.upsertStreakDaily(
            userId: payload['user_id'] as String,
            day: DateTime.parse(payload['day'] as String),
            completedSessions: payload['completed_sessions'] as int,
            streakAfterDay: payload['streak_after_day'] as int,
            protectedByFreeze: payload['protected_by_freeze'] as bool,
          );
          await _logSyncApplied(
            userId: payload['user_id'] as String,
            clientActionId: clientActionId,
            actionType: type,
            payload: payload,
            conflictStatus: 'applied',
            retries: retries,
          );
        }
      } catch (_) {
        final nextRetries = retries + 1;
        final seconds = min(300, pow(2, nextRetries).toInt());
        entry['retries'] = nextRetries;
        entry['last_error_at'] = DateTime.now().toIso8601String();
        entry['next_retry_at'] = DateTime.now().add(Duration(seconds: seconds)).toIso8601String();
        remaining.add(entry);
        final userId = (entry['payload'] as Map)['user_id'] as String? ?? local.userId ?? '';
        if (userId.isNotEmpty) {
          await _logSyncApplied(
            userId: userId,
            clientActionId: clientActionId,
            actionType: entry['type'] as String,
            payload: Map<String, dynamic>.from(entry['payload'] as Map),
            conflictStatus: 'failed',
            conflictReason: 'Retry scheduled in ${seconds}s',
            retries: nextRetries,
          );
        }
      }
    }
    await local.saveSyncQueue(remaining);
  }

  Future<void> _enqueue(String type, Map<String, dynamic> payload) {
    final queue = local.getSyncQueue();
    queue.add({
      'type': type,
      'payload': payload,
      'client_action_id': _newActionId(),
      'retries': 0,
      'next_retry_at': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    return local.saveSyncQueue(queue);
  }

  Future<void> _logSyncApplied({
    required String userId,
    required String clientActionId,
    required String actionType,
    required Map<String, dynamic> payload,
    required String conflictStatus,
    String? conflictReason,
    required int retries,
  }) async {
    if (userId.isEmpty) return;
    await remote.upsertRemoteSyncQueue(
      userId: userId,
      clientActionId: clientActionId,
      actionType: _syncActionEnum(actionType),
      payload: {
        ...payload,
        'entity_table': _entityTableFromAction(actionType),
        'client_created_at': DateTime.now().toIso8601String(),
      },
      conflictStatus: conflictStatus,
      conflictReason: conflictReason,
      retries: retries,
    );
  }

  String _newActionId() {
    final random = Random.secure();
    final bytes = List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'act_$bytes';
  }

  String _entityTableFromAction(String action) {
    if (action.contains('message')) return 'messages';
    if (action.contains('friendship')) return 'friendships';
    if (action.contains('session_participant')) return 'session_participants';
    if (action.contains('session')) return 'sessions';
    if (action.contains('streak')) return 'streak_daily';
    return 'profiles';
  }

  String _syncActionEnum(String action) {
    return switch (action) {
      'upsert_user' => 'upsert_profile',
      'session_insert' => 'create_session',
      'session_update_status' => 'update_session_status',
      'friendship_insert' => 'send_friend_request',
      'friendship_update_status' => 'update_friendship_status',
      'message_insert' => 'send_message',
      'streak_daily_upsert' => 'use_streak_freeze',
      _ => 'upsert_profile',
    };
  }
}

extension _NullableRealtimeChannelOps on RealtimeChannel? {
  void let(Future<void> Function(RealtimeChannel channel) callback) {
    final channel = this;
    if (channel != null) {
      callback(channel);
    }
  }
}
