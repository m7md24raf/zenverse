import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';

class SyncService extends GetxService {
  SyncService(this._repository);

  final ZenRepository _repository;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((e) => e != ConnectivityResult.none)) {
        _repository.flushSyncQueue();
      }
    });
  }

  Future<void> flushNow() => _repository.flushSyncQueue();

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
