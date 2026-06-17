import 'package:get/get.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';

class PermissionService extends GetxService {
  Future<void> handleInitialPermissionOnboarding() async {
    await _explainOpenAndConfirm(
      title: 'Usage Access',
      message:
          'Zenverse needs Usage Access to detect app switching and enforce focus boundaries in Medium/Hard journeys.',
      intentAction: 'android.settings.USAGE_ACCESS_SETTINGS',
      confirmLabel: 'Continue',
      strict: false,
    );
    await _explainOpenAndConfirm(
      title: 'Do Not Disturb (DND) Access',
      message:
          'DND Access helps silence distractions during focus sessions. You can adjust this anytime in system settings.',
      intentAction: 'android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS',
      confirmLabel: 'Continue',
      strict: false,
    );
    await _explainOpenAndConfirm(
      title: 'Notification Listener',
      message:
          'Notification Listener lets Zenverse detect interruptive notifications and keep your journey protected.',
      intentAction: 'android.settings.NOTIFICATION_LISTENER_SETTINGS',
      confirmLabel: 'Continue',
      strict: false,
    );
    await _explainOpenAndConfirm(
      title: 'Display Over Other Apps',
      message:
          'Overlay permission allows Zenverse to show urgent focus warnings if you switch away mid-session.',
      intentAction: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
      confirmLabel: 'Continue',
      strict: false,
    );
  }

  Future<bool> requestMediumModePermissions() async {
    return true;
  }

  Future<bool> requestHardModePermissions() async {
    final usageOk = await _explainOpenAndConfirm(
      title: 'Usage Access',
      message:
          'Hard Mode needs Usage Access so Zenverse can detect app switching and help keep your focus session protected.',
      intentAction: 'android.settings.USAGE_ACCESS_SETTINGS',
      confirmLabel: 'I enabled Usage Access',
      strict: true,
    );
    if (!usageOk) return false;

    final dndOk = await _explainOpenAndConfirm(
      title: 'Do Not Disturb (DND) Access',
      message:
          'Hard Mode uses Do Not Disturb to reduce interruptions while you focus. You can change this anytime in Settings.',
      intentAction: 'android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS',
      confirmLabel: 'I enabled DND Access',
      strict: true,
    );
    if (!dndOk) return false;

    final listenerOk = await _explainOpenAndConfirm(
      title: 'Notification Listener',
      message:
          'Hard Mode can optionally monitor notification activity to warn you when your focus might be disrupted.',
      intentAction: 'android.settings.NOTIFICATION_LISTENER_SETTINGS',
      confirmLabel: 'I enabled Notification Listener',
      strict: true,
    );
    if (!listenerOk) return false;

    return true;
  }

  Future<bool> _explainOpenAndConfirm({
    required String title,
    required String message,
    required String intentAction,
    required String confirmLabel,
    required bool strict,
  }) async {
    final proceed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (proceed != true) return !strict;

    try {
      final intent = AndroidIntent(
        action: intentAction,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (_) {
      // If the intent fails, treat as denied.
      return !strict;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm'),
        content: Text('After enabling it in Settings, return here and tap "$confirmLabel".'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('I didn’t enable it'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(confirmLabel),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return strict ? confirmed == true : true;
  }
}
