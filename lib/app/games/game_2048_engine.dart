/// Pure 2048 game logic (no UI / GetX dependencies).
class Game2048Engine {
  static const int size = 4;
  static const int winTile = 2048;

  List<int> grid = List<int>.filled(16, 0);
  int score = 0;
  bool won = false;
  bool over = false;

  /// Collapses and merges a single row/column (length 4) per standard 2048 rules.
  /// Each tile merges at most once per move.
  static List<int> collapseAndMergeLine(List<int> line, {void Function(int mergedValue)? onMerge}) {
    final compact = line.where((v) => v != 0).toList();
    final merged = <int>[];
    for (var i = 0; i < compact.length; i++) {
      if (i + 1 < compact.length && compact[i] == compact[i + 1]) {
        final value = compact[i] * 2;
        merged.add(value);
        onMerge?.call(value);
        i++;
      } else {
        merged.add(compact[i]);
      }
    }
    while (merged.length < size) {
      merged.add(0);
    }
    return merged;
  }

  List<int> readLine(int index, MoveDirection direction) {
    switch (direction) {
      case MoveDirection.left:
        return row(index);
      case MoveDirection.right:
        return row(index).reversed.toList();
      case MoveDirection.up:
        return col(index);
      case MoveDirection.down:
        return col(index).reversed.toList();
    }
  }

  void writeLine(int index, MoveDirection direction, List<int> line) {
    switch (direction) {
      case MoveDirection.left:
        setRow(index, line);
        break;
      case MoveDirection.right:
        setRow(index, line.reversed.toList());
        break;
      case MoveDirection.up:
        setCol(index, line);
        break;
      case MoveDirection.down:
        setCol(index, line.reversed.toList());
        break;
    }
  }

  bool move(MoveDirection direction) {
    if (won || over) return false;
    final before = List<int>.from(grid);
    var gained = 0;
    var reachedWin = false;

    for (var index = 0; index < size; index++) {
      final line = readLine(index, direction);
      final mergedLine = collapseAndMergeLine(line, onMerge: (value) {
        gained += value;
        if (value >= winTile) reachedWin = true;
      });
      writeLine(index, direction, mergedLine);
    }

    if (_listEquals(before, grid)) return false;

    score += gained;
    if (reachedWin) won = true;
    spawnTile();
    _updateGameOver();
    return true;
  }

  void spawnTile({int Function()? pickIndex, double Function()? roll}) {
    final empty = <int>[];
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] == 0) empty.add(i);
    }
    if (empty.isEmpty) return;
    final indexPicker = pickIndex ?? () => 0;
    final roller = roll ?? () => 0.5;
    final pos = empty[indexPicker() % empty.length];
    grid[pos] = roller() < 0.9 ? 2 : 4;
  }

  void _updateGameOver() {
    if (grid.any((v) => v == 0)) return;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final value = grid[r * size + c];
        if (c < size - 1 && value == grid[r * size + c + 1]) return;
        if (r < size - 1 && value == grid[(r + 1) * size + c]) return;
      }
    }
    over = true;
  }

  List<int> row(int r) => [grid[r * 4], grid[r * 4 + 1], grid[r * 4 + 2], grid[r * 4 + 3]];

  List<int> col(int c) => [grid[c], grid[c + 4], grid[c + 8], grid[c + 12]];

  void setRow(int r, List<int> values) {
    for (var i = 0; i < size; i++) {
      grid[r * size + i] = values[i];
    }
  }

  void setCol(int c, List<int> values) {
    for (var r = 0; r < size; r++) {
      grid[r * size + c] = values[r];
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum MoveDirection { left, right, up, down }
