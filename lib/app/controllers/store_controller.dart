import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenverse/app/models/music_catalog.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';

class StoreController extends GetxController {
  final sessionXp = 0.obs;
  final gameXp = 0.obs;
  final unlockedPlanets = RxSet<String>();
  final unlockedMusicTracks = RxSet<String>();

  Box<dynamic>? _box;

  @override
  void onInit() {
    super.onInit();
    for (final planet in PlanetCatalog.all.where((p) => p.unlockedByDefault)) {
      unlockedPlanets.add(planet.id);
    }
    for (final track in MusicCatalog.all.where((t) => t.unlockedByDefault)) {
      unlockedMusicTracks.add(track.id);
    }
    if (Get.isRegistered<Box<dynamic>>()) {
      _box = Get.find<Box<dynamic>>();
    }
    _loadFromPrefs();
    refreshXpFromProfile();
  }

  void refreshXpFromProfile() {
    final raw = _box?.get('profile');
    if (raw == null) {
      sessionXp.value = 0;
      gameXp.value = 0;
      return;
    }
    final profile = Map<String, dynamic>.from(raw as Map);
    sessionXp.value = profile['xp_session'] as int? ?? 0;
    gameXp.value = profile['xp_games'] as int? ?? 0;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlanets = prefs.getStringList('unlocked_planets') ?? [];
    unlockedPlanets.addAll(
      PlanetCatalog.all.where((p) => p.unlockedByDefault).map((p) => p.id),
    );
    unlockedPlanets.addAll(savedPlanets);
    unlockedPlanets.refresh();

    final savedMusic = prefs.getStringList('unlocked_music_tracks') ?? [];
    unlockedMusicTracks.addAll(
      MusicCatalog.all.where((t) => t.unlockedByDefault).map((t) => t.id),
    );
    unlockedMusicTracks.addAll(savedMusic);
    unlockedMusicTracks.refresh();
    _box?.put('unlocked_music_tracks', unlockedMusicTracks.toList());
  }

  Future<void> _saveUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedPlanets = unlockedPlanets
        .where((id) => !PlanetCatalog.byId(id).unlockedByDefault)
        .toList();
    await prefs.setStringList('unlocked_planets', purchasedPlanets);

    final purchasedMusic = unlockedMusicTracks
        .where((id) => !MusicCatalog.byId(id).unlockedByDefault)
        .toList();
    await prefs.setStringList('unlocked_music_tracks', purchasedMusic);
    await _box?.put('unlocked_music_tracks', unlockedMusicTracks.toList());

    await _syncMusicToRemote();
  }

  Future<void> _syncMusicToRemote() async {
    if (!Get.isRegistered<ZenRepository>()) return;
    final userId = _box?.get('user_id') as String?;
    if (userId == null || userId.isEmpty) return;
    try {
      await Get.find<ZenRepository>().syncMusicUnlocks(
        userId: userId,
        trackIds: unlockedMusicTracks.toList(),
      );
    } catch (_) {}
  }

  String? get _userId => _box?.get('user_id') as String?;

  bool isUnlocked(String planetId) => unlockedPlanets.contains(planetId);

  bool isMusicUnlocked(String trackId) => unlockedMusicTracks.contains(trackId);

  Future<bool> purchasePlanet(String planetId) async {
    final planet = PlanetCatalog.byId(planetId);
    if (isUnlocked(planetId)) return true;
    if (!Get.isRegistered<ZenRepository>()) return false;
    final repo = Get.find<ZenRepository>();
    final spent = await repo.spendSessionXp(userId: _userId, amount: planet.price);
    if (!spent) return false;
    unlockedPlanets.add(planetId);
    unlockedPlanets.refresh();
    refreshXpFromProfile();
    await _saveUnlocks();
    return true;
  }

  Future<bool> purchaseMusicTrack(String trackId) async {
    final track = MusicCatalog.byId(trackId);
    if (isMusicUnlocked(trackId)) return true;
    if (track.unlockedByDefault) return true;
    if (!Get.isRegistered<ZenRepository>()) return false;
    final repo = Get.find<ZenRepository>();
    final spent = await repo.spendGameXp(userId: _userId, amount: track.price);
    if (!spent) return false;
    unlockedMusicTracks.add(trackId);
    unlockedMusicTracks.refresh();
    refreshXpFromProfile();
    await _saveUnlocks();
    return true;
  }
}
