import 'dart:math';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/games/game_2048_engine.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/views/shared/game_win_dialog.dart';

export 'package:zenverse/app/games/game_2048_engine.dart' show MoveDirection;

class Game2048Controller extends GetxController {
  Game2048Controller(this._repository, this._box);

  static const int winBonusXp = 30;

  final ZenRepository _repository;
  final Box<dynamic> _box;
  final _engine = Game2048Engine();
  final Random _random = Random();

  final grid = List<int>.filled(16, 0).obs;
  final score = 0.obs;
  final won = false.obs;
  final over = false.obs;
  final awarded = false.obs;
  bool _hasWon = false;

  @override
  void onInit() {
    super.onInit();
    reset();
  }

  void reset() {
    _engine.grid = List<int>.filled(16, 0);
    _engine.score = 0;
    _engine.won = false;
    _engine.over = false;
    _spawnTile();
    _spawnTile();
    _syncFromEngine();
    awarded.value = false;
    _hasWon = false;
  }

  void handleSwipe({required double dx, required double dy}) {
    if (won.value || over.value) return;
    if (dx.abs() < 120 && dy.abs() < 120) return;

    final direction = dx.abs() >= dy.abs()
        ? (dx < 0 ? MoveDirection.left : MoveDirection.right)
        : (dy < 0 ? MoveDirection.up : MoveDirection.down);

    final changed = _engine.move(direction);
    if (!changed) return;

    _syncFromEngine();
    _checkWin();
  }

  void move(MoveDirection direction) {
    if (won.value || over.value) return;
    if (!_engine.move(direction)) return;
    _syncFromEngine();
    _checkWin();
  }

  void _syncFromEngine() {
    grid.assignAll(_engine.grid);
    score.value = _engine.score;
    won.value = _engine.won;
    over.value = _engine.over;
    grid.refresh();
  }

  void _checkWin() {
    if (_hasWon) return;
    if (won.value) {
      _hasWon = true;
      _onWin();
    }
  }

  Future<void> _onWin() async {
    if (!awarded.value) {
      awarded.value = true;
      final xp = max(100, score.value ~/ 8) + winBonusXp;
      final userId = _box.get('user_id') as String?;
      await _repository.awardGameXp(userId: userId, amount: xp);
      if (Get.isRegistered<StoreController>()) {
        Get.find<StoreController>().refreshXpFromProfile();
      }
      await showGameWinDialog(gameXpEarned: xp, onPlayAgain: reset);
      return;
    }
    await showGameWinDialog(gameXpEarned: 0, onPlayAgain: reset);
  }

  void _spawnTile() {
    _engine.spawnTile(
      pickIndex: () => _random.nextInt(16),
      roll: () => _random.nextDouble(),
    );
  }
}
