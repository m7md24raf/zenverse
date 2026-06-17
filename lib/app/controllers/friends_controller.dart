import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/controllers/auth_controller.dart';
import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/utils/user_code_util.dart';

class FriendsController extends GetxController {
  FriendsController(this._repository, this._box);

  final ZenRepository _repository;
  final Box<dynamic> _box;

  final acceptedFriends = <FriendProfile>[].obs;
  final pendingRequests = <FriendshipRequest>[].obs;
  final searchResult = Rxn<FriendProfile>();
  final searchMessage = RxnString();
  final loading = false.obs;
  final searching = false.obs;
  StreamSubscription<void>? _friendshipSub;
  Timer? _refreshDebounce;

  String? get currentUserId => _box.get('user_id') as String?;

  String get myUserCode {
    final authCode = Get.isRegistered<AuthController>() ? Get.find<AuthController>().userCode.value : '';
    final localCode = _box.get('profile') != null
        ? (Map<String, dynamic>.from(_box.get('profile') as Map)['user_code'] as String?)
        : null;
    return normalizeUserCode(localCode ?? authCode);
  }

  @override
  void onInit() {
    super.onInit();
    _prepareFriends();
  }

  Future<void> _prepareFriends() async {
    final me = currentUserId;
    if (me == null) return;
    loading.value = true;
    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      await _repository.syncCurrentUserProfileToRemote(
        userId: me,
        fallbackEmail: email,
      );
      if (Get.isRegistered<AuthController>()) {
        await Get.find<AuthController>().loadUserData();
      }
      await refreshAll();
      _bindRealtime();
    } catch (e, st) {
      debugPrint('[Friends] prepare: $e\n$st');
    } finally {
      loading.value = false;
    }
  }

  Future<void> refreshAll() async {
    final me = currentUserId;
    if (me == null) return;
    loading.value = true;
    try {
      final accepted = await _repository.listAcceptedFriends(me);
      final pending = await _repository.listPendingIncomingRequests(me);
      acceptedFriends.assignAll(accepted);
      pendingRequests.assignAll(pending);
    } catch (e, st) {
      debugPrint('[Friends] refreshAll: $e\n$st');
    } finally {
      loading.value = false;
    }
  }

  void _bindRealtime() {
    final me = currentUserId;
    if (me == null) return;
    _friendshipSub?.cancel();
    _friendshipSub = _repository.watchFriendships(me).listen((_) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 250), refreshAll);
    });
  }

  Future<void> searchByCode(String code) async {
    final me = currentUserId;
    final normalized = normalizeUserCode(code);
    searchResult.value = null;

    if (me == null) {
      searchMessage.value = 'Sign in to search for friends.';
      return;
    }
    if (normalized.length < 7) {
      searchMessage.value = 'Enter a valid friend code like ZEN-XXXX.';
      return;
    }

    final ownCode = myUserCode;
    if (ownCode.isNotEmpty && ownCode == normalized) {
      searchMessage.value =
          'That is your friend code ($ownCode). Share it with someone else so they can add you.';
      return;
    }

    searching.value = true;
    searchMessage.value = null;
    try {
      final profile = await _repository.findProfileByUserCode(normalized);
      if (profile == null) {
        searchMessage.value = 'No user found with code $normalized.';
        return;
      }
      if (profile.id == me) {
        searchMessage.value = 'That is your friend code. Share it with others to connect.';
        return;
      }
      if (acceptedFriends.any((f) => f.id == profile.id)) {
        searchMessage.value = 'You are already friends with ${profile.displayName}.';
        return;
      }
      final pendingFromThem = pendingRequests.any((r) => r.requesterId == profile.id);
      if (pendingFromThem) {
        searchMessage.value = '${profile.displayName} already sent you a request — check Friend Requests below.';
        return;
      }
      searchMessage.value = null;
      searchResult.value = profile;
    } catch (e, st) {
      debugPrint('[Friends] searchByCode: $e\n$st');
      searchMessage.value = 'Could not search right now. Check your connection and try again.';
    } finally {
      searching.value = false;
    }
  }

  Future<void> sendFriendRequest(FriendProfile profile) async {
    final me = currentUserId;
    if (me == null) return;
    try {
      await _repository.enqueueFriendRequest(requesterId: me, addresseeId: profile.id);
      searchResult.value = null;
      searchMessage.value = null;
      await refreshAll();
      Get.snackbar('Friend Request', 'Request sent to ${profile.displayName}');
    } catch (e, st) {
      debugPrint('[Friends] sendFriendRequest: $e\n$st');
      Get.snackbar('Request failed', 'Could not send friend request. Try again.');
    }
  }

  Future<void> acceptRequest(FriendshipRequest request) async {
    try {
      await _repository.updateFriendRequestStatus(friendshipId: request.id, status: 'accepted');
      await refreshAll();
      Get.snackbar('Friends', 'You are now connected with ${request.requesterProfile?.displayName ?? 'your friend'}.');
    } catch (e, st) {
      debugPrint('[Friends] acceptRequest: $e\n$st');
      Get.snackbar('Could not accept', 'Please try again.');
    }
  }

  Future<void> declineRequest(FriendshipRequest request) async {
    try {
      await _repository.updateFriendRequestStatus(friendshipId: request.id, status: 'declined');
      await refreshAll();
    } catch (e, st) {
      debugPrint('[Friends] declineRequest: $e\n$st');
      Get.snackbar('Could not decline', 'Please try again.');
    }
  }

  @override
  void onClose() {
    _friendshipSub?.cancel();
    _refreshDebounce?.cancel();
    super.onClose();
  }
}
