import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

enum PlaybackContext { none, session, preview }

/// Central audio controller for session loops and store previews.
class MusicService extends GetxService {
  static const Duration previewMaxDuration = Duration(seconds: 10);

  MusicService() {
    _player.playerStateStream.listen((state) {
      if (context.value == PlaybackContext.session &&
          state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.play());
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  Timer? _previewTimer;

  final context = PlaybackContext.none.obs;
  final previewTrackId = RxnString();
  String? _currentAsset;

  double get volume => _player.volume;

  bool get isPlaying => _player.playing;

  String? get currentAsset => _currentAsset;

  bool get isPreviewing => context.value == PlaybackContext.preview;

  bool get isSessionPlaying => context.value == PlaybackContext.session;

  Future<void> setVolume(double value) async {
    await _player.setVolume(value.clamp(0.0, 1.0));
  }

  Future<void> playSessionLoop(String assetPath, {double volume = 0.65}) async {
    await _cancelPreviewTimer();
    if (context.value == PlaybackContext.preview) {
      await _player.stop();
    }
    context.value = PlaybackContext.session;
    previewTrackId.value = null;
    _currentAsset = assetPath;
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(volume);
    await _player.setAsset(assetPath);
    await _player.play();
  }

  Future<void> playPreview({
    required String trackId,
    required String assetPath,
  }) async {
    if (context.value == PlaybackContext.session) return;

    await _cancelPreviewTimer();
    await _player.stop();

    context.value = PlaybackContext.preview;
    previewTrackId.value = trackId;
    _currentAsset = assetPath;
    await _player.setLoopMode(LoopMode.off);
    await _player.setVolume(0.75);
    await _player.setAsset(assetPath);
    await _player.play();

    _previewTimer = Timer(previewMaxDuration, () {
      unawaited(stopPreview());
    });
  }

  Future<void> pauseSession() async {
    if (context.value != PlaybackContext.session) return;
    await _player.pause();
  }

  Future<void> resumeSession() async {
    if (context.value != PlaybackContext.session || _currentAsset == null) return;
    await _player.play();
  }

  Future<void> stopPreview() async {
    if (context.value != PlaybackContext.preview) return;
    await _cancelPreviewTimer();
    previewTrackId.value = null;
    context.value = PlaybackContext.none;
    _currentAsset = null;
    await _player.stop();
  }

  Future<void> stopSession() async {
    if (context.value != PlaybackContext.session) return;
    await _cancelPreviewTimer();
    previewTrackId.value = null;
    context.value = PlaybackContext.none;
    _currentAsset = null;
    await _player.stop();
  }

  Future<void> stopAll() async {
    await _cancelPreviewTimer();
    previewTrackId.value = null;
    context.value = PlaybackContext.none;
    _currentAsset = null;
    await _player.stop();
  }

  Future<void> _cancelPreviewTimer() async {
    _previewTimer?.cancel();
    _previewTimer = null;
  }

  @override
  void onClose() {
    _previewTimer?.cancel();
    _player.dispose();
    super.onClose();
  }
}
