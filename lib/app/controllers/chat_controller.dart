import 'dart:async';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';

class ChatController extends GetxController {
  ChatController(this._repository, this._box);

  final ZenRepository _repository;
  final Box<dynamic> _box;

  final activePeerId = RxnString();
  final messages = <DirectMessage>[].obs;
  final acceptedFriends = <FriendProfile>[].obs;
  final loading = false.obs;
  final loadingFriends = false.obs;
  StreamSubscription<List<DirectMessage>>? _messagesSub;

  String? get currentUserId => _box.get('user_id') as String?;

  @override
  void onInit() {
    super.onInit();
    loadAcceptedFriends();
  }

  Future<void> loadAcceptedFriends() async {
    final me = currentUserId;
    if (me == null) return;
    loadingFriends.value = true;
    try {
      final rows = await _repository.listAcceptedFriends(me);
      acceptedFriends.assignAll(rows);
      if (activePeerId.value == null && rows.isNotEmpty) {
        openChatWith(peerUserId: rows.first.id);
      }
      final active = activePeerId.value;
      final stillValid = rows.any((f) => f.id == active);
      if (active != null && !stillValid) {
        activePeerId.value = null;
        messages.clear();
      }
    } finally {
      loadingFriends.value = false;
    }
  }

  void openChatWith({
    required String peerUserId,
  }) {
    final me = currentUserId;
    if (me == null) return;
    final isFriend = acceptedFriends.any((f) => f.id == peerUserId);
    if (!isFriend) {
      Get.snackbar('Unavailable', 'You can only chat with accepted friends.');
      return;
    }
    activePeerId.value = peerUserId;
    _messagesSub?.cancel();
    loading.value = true;
    _messagesSub = _repository.watchDirectMessages(userA: me, userB: peerUserId).listen((rows) {
      messages.assignAll(rows);
      loading.value = false;
    });
  }

  Future<void> sendMessage(String content, {String? sessionId}) async {
    final me = currentUserId;
    final peer = activePeerId.value;
    if (me == null || peer == null || content.trim().isEmpty) return;
    await _repository.sendDirectMessage(
      senderId: me,
      receiverId: peer,
      content: content.trim(),
      sessionId: sessionId,
    );
  }

  Future<void> markVisibleAsRead() async {
    final me = currentUserId;
    if (me == null) return;
    for (final msg in messages.where((m) => m.receiverId == me)) {
      await _repository.markDirectMessageRead(messageId: msg.id, userId: me);
    }
  }

  @override
  void onClose() {
    _messagesSub?.cancel();
    super.onClose();
  }
}
