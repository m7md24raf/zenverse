import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zenverse/app/controllers/shell_controller.dart';
import 'package:zenverse/app/controllers/store_controller.dart';

Future<void> showGameWinDialog({
  required int gameXpEarned,
  required VoidCallback onPlayAgain,
}) {
  final store = Get.find<StoreController>();

  return Get.dialog(
    barrierDismissible: false,
    AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(
        children: [
          Text('🎉', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text(
            'You Won!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Great job! You earned:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset_rounded, color: Color(0xFFD4B6FF), size: 32),
              const SizedBox(width: 8),
              Text(
                '+$gameXpEarned Game XP',
                style: const TextStyle(
                  color: Color(0xFFD4B6FF),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              'Total: ${store.gameXp.value} Game XP',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            Get.back();
            Get.find<ShellController>().selectedTab.value = 3;
          },
          child: const Text(
            'Go to Store',
            style: TextStyle(color: Colors.cyanAccent),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            onPlayAgain();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
          ),
          child: const Text('Play Again'),
        ),
      ],
    ),
  );
}
