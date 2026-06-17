import 'dart:math';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/views/shared/game_win_dialog.dart';

class OrbitPuzzleController extends GetxController {
  OrbitPuzzleController(this._repository, this._box);

  static const int winBonusXp = 20;

  final ZenRepository _repository;
  final Box<dynamic> _box;

  final difficulty = 'Easy'.obs;
  final cards = <String>[].obs;
  final revealed = <int>{}.obs;
  final matched = <int>{}.obs;
  final moves = 0.obs;
  final completed = false.obs;
  final awarded = false.obs;
  final _random = Random();
  int? _firstPick;
  bool _hasWon = false;

  int get columns => switch (difficulty.value) {
        'Hard' => 6,
        'Medium' => 5,
        _ => 4,
      };

  int get rows => switch (difficulty.value) {
        'Hard' => 6,
        'Medium' => 6,
        _ => 4,
      };

  @override
  void onInit() {
    super.onInit();
    startNewGame(level: difficulty.value);
  }

  void startNewGame({required String level}) {
    difficulty.value = level;
    final total = rows * columns;
    final pairCount = total ~/ 2;
    final symbols = List<String>.generate(pairCount, (i) => 'P${i + 1}');
    final deck = [...symbols, ...symbols]..shuffle(_random);
    cards.assignAll(deck);
    revealed.clear();
    matched.clear();
    moves.value = 0;
    completed.value = false;
    awarded.value = false;
    _hasWon = false;
    _firstPick = null;
  }

  Future<void> tapCard(int index) async {
    if (completed.value) return;
    if (matched.contains(index) || revealed.contains(index)) return;
    if (revealed.length == 2) return;

    revealed.add(index);
    if (_firstPick == null) {
      _firstPick = index;
      revealed.refresh();
      return;
    }

    moves.value++;
    final first = _firstPick!;
    final second = index;
    _firstPick = null;
    revealed.refresh();

    if (cards[first] == cards[second]) {
      matched.add(first);
      matched.add(second);
      revealed.remove(first);
      revealed.remove(second);
      revealed.refresh();
      matched.refresh();
      if (matched.length == cards.length) {
        completed.value = true;
        _checkWin();
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
    revealed.remove(first);
    revealed.remove(second);
    revealed.refresh();
  }

  void _checkWin() {
    if (_hasWon) return;
    if (completed.value) {
      _hasWon = true;
      _onWin();
    }
  }

  Future<void> _onWin() async {
    if (!awarded.value) {
      awarded.value = true;
      final base = switch (difficulty.value) {
        'Hard' => 220,
        'Medium' => 150,
        _ => 100,
      };
      final speedBonus = max(0, 80 - moves.value);
      final xp = base + speedBonus + winBonusXp;
      final userId = _box.get('user_id') as String?;
      await _repository.awardGameXp(userId: userId, amount: xp);
      if (Get.isRegistered<StoreController>()) {
        Get.find<StoreController>().refreshXpFromProfile();
      }
      await showGameWinDialog(
        gameXpEarned: xp,
        onPlayAgain: () => startNewGame(level: difficulty.value),
      );
      return;
    }
    await showGameWinDialog(
      gameXpEarned: 0,
      onPlayAgain: () => startNewGame(level: difficulty.value),
    );
  }
}
