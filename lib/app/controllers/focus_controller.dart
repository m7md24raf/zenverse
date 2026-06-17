import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/models/music_catalog.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/services/music_service.dart';
import 'package:zenverse/app/services/notification_service.dart';
import 'package:zenverse/app/services/permission_service.dart';

class FocusController extends GetxController with WidgetsBindingObserver {
  FocusController(this._repository, this._box);

  final ZenRepository _repository;
  final Box<dynamic> _box;
  final selectedMode = 'Easy Mode'.obs;
  final durationMinutes = 25.obs;
  final remaining = const Duration(minutes: 25).obs;
  final streakDays = 7.obs;
  final activeSessionId = RxnString();
  final activeParticipants = <SessionParticipant>[].obs;
  final appLeaveViolations = 0.obs;
  final protectedByFreeze = false.obs;
  final isGuestSession = false.obs;
  final selectedPlanetId = 'earth'.obs;
  final selectedMusicTrackId = MusicCatalog.defaultTrackId.obs;
  final invitedFriendIds = <String>[].obs;
  final startingSession = false.obs;
  Timer? _timer;
  StreamSubscription<List<SessionParticipant>>? _participantsSub;

  PlanetDefinition get selectedPlanet => PlanetCatalog.byId(selectedPlanetId.value);

  MusicTrack get selectedMusicTrack => MusicCatalog.byId(selectedMusicTrackId.value);

  String get selectedPlanetImagePath => selectedPlanet.imageAssetPath;

  @override
  void onInit() {
    super.onInit();
    final saved = _box.get('selected_music_track_id') as String?;
    if (saved != null && saved.isNotEmpty) {
      selectedMusicTrackId.value = saved;
    }
    WidgetsBinding.instance.addObserver(this);
    ensureValidMusicSelection();
  }

  /// Resets music selection when the chosen track is not unlocked/visible.
  void ensureValidMusicSelection() {
    final available = _availableMusicTrackIds();
    if (available.isEmpty) {
      selectMusicTrack(MusicCatalog.defaultTrackId);
      return;
    }
    if (!available.contains(selectedMusicTrackId.value)) {
      selectMusicTrack(
        available.contains(MusicCatalog.defaultTrackId)
            ? MusicCatalog.defaultTrackId
            : available.first,
      );
    }
  }

  Set<String> _availableMusicTrackIds() {
    if (!Get.isRegistered<StoreController>()) {
      return {MusicCatalog.defaultTrackId};
    }
    final store = Get.find<StoreController>();
    return MusicCatalog.all
        .where((track) => store.isMusicUnlocked(track.id))
        .map((track) => track.id)
        .toSet();
  }

  void selectMusicTrack(String trackId) {
    if (!Get.isRegistered<StoreController>()) {
      selectedMusicTrackId.value = trackId;
      _box.put('selected_music_track_id', trackId);
      return;
    }
    if (!Get.find<StoreController>().isMusicUnlocked(trackId)) return;
    selectedMusicTrackId.value = trackId;
    _box.put('selected_music_track_id', trackId);
  }

  void selectPlanet(String planetId) {
    if (Get.isRegistered<StoreController>() && Get.find<StoreController>().isUnlocked(planetId)) {
      selectedPlanetId.value = planetId;
    }
  }

  void setMode(String mode) => selectedMode.value = mode;

  bool get isRestrictionMode => selectedMode.value == 'Medium Mode' || selectedMode.value == 'Hard Mode';
  bool get hasBlockedAppsConfigured {
    final raw = _box.get('blocked_apps', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.isNotEmpty;
  }

  void setInvitedFriends(List<String> friendIds) {
    invitedFriendIds.assignAll(friendIds);
  }

  void adjustMinutes(int delta) {
    durationMinutes.value = (durationMinutes.value + delta).clamp(5, 180);
    remaining.value = Duration(minutes: durationMinutes.value);
  }

  Future<void> startSession() async {
    if (startingSession.value || activeSessionId.value != null) return;
    startingSession.value = true;
    try {
      ensureValidMusicSelection();

      if (selectedMode.value == 'Medium Mode' && !hasBlockedAppsConfigured) {
        Get.snackbar('Select apps first', 'Pick apps to block before starting a Medium Mode session.');
        await Get.toNamed(AppRoutes.appPermissionPicker);
        if (!hasBlockedAppsConfigured) return;
      }

      if (selectedMode.value == 'Hard Mode') {
        final ok = await Get.find<PermissionService>().requestHardModePermissions();
        if (!ok) {
          setMode('Medium Mode');
          Get.snackbar(
            'Hard Mode disabled',
            'Required permissions were not enabled. Continuing in Medium Mode.',
          );
        }
      }

      final userId = _box.get('user_id') as String?;
      var planetId = selectedPlanetId.value;
      if (Get.isRegistered<StoreController>() && !Get.find<StoreController>().isUnlocked(planetId)) {
        planetId = 'earth';
        selectedPlanetId.value = planetId;
      }
      if (planetId.isEmpty) {
        Get.snackbar('Select a planet', 'Choose a destination before starting your journey.');
        return;
      }
      final frozenUntil = _getFrozenUntil(planetId);
      if (frozenUntil != null && frozenUntil.isAfter(DateTime.now())) {
        final mins = frozenUntil.difference(DateTime.now()).inMinutes;
        Get.snackbar('Planet frozen', 'This planet is frozen for ~$mins more minutes.');
        return;
      }

      final sessionId = _newUuidLike();
      remaining.value = Duration(minutes: durationMinutes.value);
      activeSessionId.value = sessionId;
      appLeaveViolations.value = 0;
      protectedByFreeze.value = false;
      isGuestSession.value = userId == null;

      final session = FocusSession(
        id: sessionId,
        userId: userId ?? 'guest',
        planetId: planetId,
        targetDurationSeconds: durationMinutes.value * 60,
        mode: _mapModeToSchema(selectedMode.value),
        status: 'complete',
        pointsEarned: 0,
        startTime: DateTime.now(),
      );

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (ticker) async {
        if (remaining.value.inSeconds <= 0) {
          ticker.cancel();
          await _stopSessionMusic();
          await _completeSession();
          Get.offNamed(AppRoutes.sessionComplete);
          return;
        }
        remaining.value = Duration(seconds: remaining.value.inSeconds - 1);
      });

      await Get.toNamed(AppRoutes.activeSession);
      unawaited(_startSessionMusic());

      if (userId != null) {
        unawaited(_persistSessionStart(session: session, sessionId: sessionId, userId: userId));
      } else {
        activeParticipants.clear();
        _participantsSub?.cancel();
        unawaited(
          _saveGuestSession(
            session: session,
            status: 'in_progress',
            startTime: session.startTime,
          ),
        );
      }
    } finally {
      startingSession.value = false;
    }
  }

  Future<void> _persistSessionStart({
    required FocusSession session,
    required String sessionId,
    required String userId,
  }) async {
    try {
      await _repository.addSession(session);
      await _repository.addSessionParticipant(sessionId: sessionId, userId: userId);
      if (invitedFriendIds.isNotEmpty) {
        await _repository.sendSessionInvites(
          hostId: userId,
          sessionId: sessionId,
          friendIds: invitedFriendIds.toList(),
          message:
              'You\'re invited to co-focus on ${selectedPlanet.name} (${durationMinutes.value} min)!',
        );
        Get.snackbar(
          'Invites sent',
          'Session invites sent to ${invitedFriendIds.length} friend(s).',
        );
        invitedFriendIds.clear();
      }
      _participantsSub?.cancel();
      _participantsSub = _repository.watchSessionParticipants(sessionId).listen((items) {
        activeParticipants.assignAll(items);
      });
    } catch (e, st) {
      debugPrint('[Focus] persistSessionStart: $e\n$st');
    }
  }

  Future<void> giveUp() async {
    _timer?.cancel();
    activeSessionId.value = null;
    await _stopSessionMusic();
    await _giveUpSession();
    Get.offNamed(AppRoutes.shell);
  }

  Future<void> _completeSession() async {
    final sessionId = activeSessionId.value;
    if (sessionId == null) return;
    activeSessionId.value = null;
    final userId = _box.get('user_id') as String?;
    if (userId != null) {
      streakDays.value = streakDays.value + 1;
      await _repository.upsertStreakDaily(
        userId: userId,
        day: DateTime.now(),
        completedSessions: 1,
        streakAfterDay: streakDays.value,
        protectedByFreeze: false,
      );
      await _repository.updateSessionStatus(
        sessionId: sessionId,
        status: 'complete',
        endTime: DateTime.now(),
        pointsEarned: durationMinutes.value * 2,
      );
      final sessionXpEarned = durationMinutes.value * 2;
      await _repository.awardSessionXp(userId: userId, amount: sessionXpEarned);
      if (Get.isRegistered<StoreController>()) {
        Get.find<StoreController>().refreshXpFromProfile();
      }
      return;
    }

    // Guest mode: keep all focus functionality offline-first.
    await _saveGuestSession(
      sessionId: sessionId,
      status: 'complete',
      endTime: DateTime.now(),
      pointsEarned: durationMinutes.value * 2,
    );
    streakDays.value = _computeGuestStreakDays();
    final sessionXpEarned = durationMinutes.value * 2;
    await _repository.awardSessionXp(userId: null, amount: sessionXpEarned);
    if (Get.isRegistered<StoreController>()) {
      Get.find<StoreController>().refreshXpFromProfile();
    }
  }

  Future<void> _giveUpSession() async {
    final sessionId = activeSessionId.value;
    if (sessionId == null) return;
    final userId = _box.get('user_id') as String?;
    if (userId != null) {
      final used = await _repository.consumeFreezeCredit(
        userId: userId,
        day: DateTime.now(),
        reason: 'Session give up / freeze protection',
      );
      protectedByFreeze.value = used;
      if (!used) {
        streakDays.value = 0;
      }
      await _repository.upsertStreakDaily(
        userId: userId,
        day: DateTime.now(),
        completedSessions: 0,
        streakAfterDay: streakDays.value,
        protectedByFreeze: used,
      );
      await _repository.updateSessionStatus(
        sessionId: sessionId,
        status: 'given_up',
        endTime: DateTime.now(),
        gaveUpAt: DateTime.now(),
        freezeHours: 2,
        pointsEarned: 0,
      );
      return;
    }

    // Guest mode: local-only session storage.
    protectedByFreeze.value = false;
    _freezePlanet(selectedPlanetId.value, const Duration(hours: 2));
    await _saveGuestSession(
      sessionId: sessionId,
      status: 'given_up',
      endTime: DateTime.now(),
      gaveUpAt: DateTime.now(),
      freezeHours: 2,
      pointsEarned: 0,
    );
  }

  DateTime? _getFrozenUntil(String planetId) {
    final raw = _box.get('frozen_planets', defaultValue: <dynamic, dynamic>{}) as Map;
    final map = Map<String, dynamic>.from(raw);
    final until = map[planetId]?.toString();
    if (until == null) return null;
    return DateTime.tryParse(until);
  }

  Future<void> _freezePlanet(String planetId, Duration duration) async {
    final raw = _box.get('frozen_planets', defaultValue: <dynamic, dynamic>{}) as Map;
    final map = Map<String, dynamic>.from(raw);
    map[planetId] = DateTime.now().add(duration).toIso8601String();
    await _box.put('frozen_planets', map);
  }

  List<Map<String, dynamic>> _getGuestSessions() {
    final raw = _box.get('guest_sessions', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _putGuestSessions(List<Map<String, dynamic>> sessions) => _box.put('guest_sessions', sessions);

  Future<void> _saveGuestSession({
    FocusSession? session,
    String? sessionId,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? gaveUpAt,
    int? freezeHours,
    int? pointsEarned,
  }) async {
    final sessions = _getGuestSessions();
    final id = session?.id ?? sessionId;
    if (id == null) return;
    final idx = sessions.indexWhere((s) => s['id'] == id);
    final base = <String, dynamic>{
      'id': id,
      'planet_id': session?.planetId,
      'mode': session?.mode,
      'target_duration_seconds': session?.targetDurationSeconds,
      'start_time': (session?.startTime ?? startTime)?.toIso8601String(),
    };
    final patch = <String, dynamic>{
      if (status != null) 'status': status,
      if (endTime != null) 'end_time': endTime.toIso8601String(),
      if (gaveUpAt != null) 'gave_up_at': gaveUpAt.toIso8601String(),
      if (freezeHours != null) 'freeze_hours': freezeHours,
      if (pointsEarned != null) 'points_earned': pointsEarned,
    };
    if (idx == -1) {
      sessions.add({...base, ...patch, 'status': status ?? 'in_progress'});
    } else {
      sessions[idx] = {...sessions[idx], ...base, ...patch};
    }
    await _putGuestSessions(sessions);
  }

  int _computeGuestStreakDays() {
    final sessions = _getGuestSessions();
    final completedDays = sessions
        .where((s) => s['status'] == 'complete')
        .map((s) => DateTime.tryParse((s['end_time'] ?? s['start_time'] ?? '').toString()))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (completedDays.isEmpty) return 0;
    var streak = 1;
    var cursor = completedDays.first;
    for (var i = 1; i < completedDays.length; i++) {
      final expectedPrev = cursor.subtract(const Duration(days: 1));
      if (completedDays[i] == expectedPrev) {
        streak++;
        cursor = completedDays[i];
      } else {
        break;
      }
    }
    return streak;
  }

  String _mapModeToSchema(String mode) {
    return switch (mode.toLowerCase()) {
      'hard mode' => 'hard',
      'medium mode' => 'medium',
      _ => 'easy',
    };
  }

  String _newUuidLike() {
    final r = Random.secure();
    String chunk(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${chunk(8)}-${chunk(4)}-4${chunk(3)}-a${chunk(3)}-${chunk(12)}';
  }

  @override
  void onClose() {
    _timer?.cancel();
    _participantsSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (Get.isRegistered<MusicService>()) {
      unawaited(Get.find<MusicService>().stopAll());
    }
    super.onClose();
  }

  Future<void> _startSessionMusic() async {
    if (!Get.isRegistered<MusicService>()) return;
    if (activeSessionId.value == null) return;
    final track = selectedMusicTrack;
    if (!Get.isRegistered<StoreController>() || Get.find<StoreController>().isMusicUnlocked(track.id)) {
      try {
        await Get.find<MusicService>().playSessionLoop(track.assetPath);
      } catch (e, st) {
        debugPrint('[Focus] startSessionMusic: $e\n$st');
      }
    }
  }

  Future<void> _stopSessionMusic() async {
    if (!Get.isRegistered<MusicService>()) return;
    await Get.find<MusicService>().stopSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inSession = activeSessionId.value != null;

    if (inSession && Get.isRegistered<MusicService>()) {
      final music = Get.find<MusicService>();
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        unawaited(music.pauseSession());
      } else if (state == AppLifecycleState.resumed) {
        unawaited(music.resumeSession());
      }
    }

    if (!inSession || !isRestrictionMode) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      appLeaveViolations.value++;
      // Send local warning notification on leaving the app mid-session.
      try {
        Get.find<NotificationService>().showWarning(
          title: 'Zenverse Focus Warning',
          body: 'Leaving focus may freeze your active planet. Return to keep your orbit stable.',
        );
      } catch (_) {}
      if (selectedMode.value == 'Hard Mode') {
        // In Hard Mode, leaving once freezes the planet immediately.
        _freezePlanet(selectedPlanetId.value, const Duration(hours: 2));
      }
    }
    if (state == AppLifecycleState.resumed && appLeaveViolations.value > 0) {
      if (selectedMode.value == 'Hard Mode') {
        Get.snackbar('Hard Mode', 'Leaving app is blocked in spirit. Returning you to focus.');
      } else {
        final blockedApps = (_box.get('blocked_apps', defaultValue: <dynamic>[]) as List<dynamic>).length;
        Get.snackbar('Medium Mode', 'App switch detected. $blockedApps blocked apps are being monitored.');
      }
    }
  }
}
