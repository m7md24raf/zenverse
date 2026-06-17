import 'package:zenverse/app/games/game_2048_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Game2048Engine.collapseAndMergeLine', () {
    test('[2, 2, 2, 2] left -> [4, 4, 0, 0]', () {
      expect(
        Game2048Engine.collapseAndMergeLine([2, 2, 2, 2]),
        [4, 4, 0, 0],
      );
    });

    test('[2, 0, 2, 0] left -> [4, 0, 0, 0]', () {
      expect(
        Game2048Engine.collapseAndMergeLine([2, 0, 2, 0]),
        [4, 0, 0, 0],
      );
    });

    test('[2, 2, 4, 4] left -> [4, 8, 0, 0]', () {
      expect(
        Game2048Engine.collapseAndMergeLine([2, 2, 4, 4]),
        [4, 8, 0, 0],
      );
    });

    test('[0, 0, 0, 2] left -> [2, 0, 0, 0]', () {
      expect(
        Game2048Engine.collapseAndMergeLine([0, 0, 0, 2]),
        [2, 0, 0, 0],
      );
    });

    test('score adds merged tile values', () {
      var gained = 0;
      Game2048Engine.collapseAndMergeLine([2, 2, 4, 4], onMerge: (v) => gained += v);
      expect(gained, 12);
    });
  });

  group('Game2048Engine.move', () {
    test('does not spawn when board unchanged', () {
      final engine = Game2048Engine()
        ..grid = [0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      final changed = engine.move(MoveDirection.right);
      expect(changed, isFalse);
      expect(engine.grid[3], 2);
    });
  });
}
