import 'package:hive/hive.dart';
import 'package:zenverse/app/models/zen_models.dart';

class LocalDataSource {
  LocalDataSource(this._box);

  final Box<dynamic> _box;

  bool get isFirstLaunch => _box.get('is_first_launch', defaultValue: true) as bool;
  bool get isLoggedIn => _box.get('is_logged_in', defaultValue: false) as bool;
  String? get userId => _box.get('user_id') as String?;

  Future<void> markFirstLaunchDone() => _box.put('is_first_launch', false);
  Future<void> setLoggedIn(bool value) => _box.put('is_logged_in', value);
  Future<void> setUserId(String id) => _box.put('user_id', id);

  Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) => _box.put('sync_queue', queue);

  List<Map<String, dynamic>> getSyncQueue() {
    final raw = _box.get('sync_queue', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveProfile(UserProfile profile) => _box.put('profile', profile.toJson());

  Map<String, dynamic>? getProfileJson() {
    final raw = _box.get('profile');
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }
}
