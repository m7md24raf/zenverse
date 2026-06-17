import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/controllers/auth_controller.dart';
import 'package:zenverse/app/controllers/chat_controller.dart';
import 'package:zenverse/app/controllers/focus_controller.dart';
import 'package:zenverse/app/controllers/friends_controller.dart';
import 'package:zenverse/app/controllers/game_2048_controller.dart';
import 'package:zenverse/app/controllers/orbit_puzzle_controller.dart';
import 'package:zenverse/app/controllers/shell_controller.dart';
import 'package:zenverse/app/controllers/stats_controller.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/repositories/local/local_data_source.dart';
import 'package:zenverse/app/repositories/remote/remote_data_source.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/services/music_service.dart';
import 'package:zenverse/app/services/notification_service.dart';
import 'package:zenverse/app/services/permission_service.dart';
import 'package:zenverse/app/services/sync_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    final box = Hive.box('zenverse_box');
    Get.put<Box<dynamic>>(box, permanent: true);
    Get.put(LocalDataSource(box), permanent: true);
    Get.put(RemoteDataSource(), permanent: true);
    Get.put(
      ZenRepository(local: Get.find<LocalDataSource>(), remote: Get.find<RemoteDataSource>()),
      permanent: true,
    );
    Get.put(NotificationService(), permanent: true);
    Get.put<MusicService>(MusicService(), permanent: true);
    Get.put(PermissionService(), permanent: true);
    Get.put(SyncService(Get.find<ZenRepository>()), permanent: true);
    Get.put(AuthController(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(ShellController(), permanent: true);
    Get.put(StoreController(), permanent: true);
    Get.put(FocusController(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(ChatController(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(FriendsController(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(Game2048Controller(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(OrbitPuzzleController(Get.find<ZenRepository>(), box), permanent: true);
    Get.put(StatsController(Get.find<ZenRepository>(), box), permanent: true);

    // Keep Supabase client available through DI.
    Get.put<SupabaseClient>(Supabase.instance.client, permanent: true);
  }
}
