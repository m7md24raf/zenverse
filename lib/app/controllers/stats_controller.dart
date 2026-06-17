import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zenverse/app/models/zen_models.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';

class StatsController extends GetxController {
  StatsController(this._repository, this._box);

  final ZenRepository _repository;
  final Box<dynamic> _box;

  final loading = false.obs;
  final totalSessions = 0.obs;
  final totalFocusMinutes = 0.obs;
  final currentStreak = 0.obs;
  final longestStreak = 0.obs;
  final chartSpots = <FlSpot>[].obs;

  String? get userId => _box.get('user_id') as String?;

  @override
  void onInit() {
    super.onInit();
    refreshStats();
  }

  Future<void> refreshStats() async {
    final uid = userId;
    if (uid == null) return;
    loading.value = true;
    try {
      final sessions = await _repository.listSessionsForUser(uid, limit: 2000);
      _compute(sessions);
    } finally {
      loading.value = false;
    }
  }

  void _compute(List<FocusSession> sessions) {
    final completed = sessions.where((s) => s.status == 'complete' && s.endTime != null).toList();
    totalSessions.value = completed.length;
    totalFocusMinutes.value = completed.fold<int>(0, (sum, s) => sum + (s.targetDurationSeconds ~/ 60));

    final byDay = <DateTime, int>{};
    for (final s in completed) {
      final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      byDay[d] = (byDay[d] ?? 0) + 1;
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));
    chartSpots.assignAll(
      List.generate(14, (i) {
        final d = start.add(Duration(days: i));
        return FlSpot(i.toDouble(), (byDay[d] ?? 0).toDouble());
      }),
    );

    final sortedDays = byDay.keys.toList()..sort();
    longestStreak.value = _longestConsecutiveDays(sortedDays);
    currentStreak.value = _currentConsecutiveDays(sortedDays);
  }

  int _longestConsecutiveDays(List<DateTime> days) {
    if (days.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }
    return best;
  }

  int _currentConsecutiveDays(List<DateTime> days) {
    if (days.isEmpty) return 0;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final daySet = days.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    var cursor = normalizedToday;
    var streak = 0;
    if (!daySet.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!daySet.contains(cursor)) return 0;
    }
    while (daySet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
