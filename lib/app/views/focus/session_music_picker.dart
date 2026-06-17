import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zenverse/app/controllers/focus_controller.dart';
import 'package:zenverse/app/controllers/shell_controller.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/models/music_catalog.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/theme/app_colors.dart';

class SessionMusicPicker extends StatelessWidget {
  const SessionMusicPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = Get.find<FocusController>();
    final store = Get.find<StoreController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Session Music',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose ambient audio for your focus journey',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Obx(() {
          focus.ensureValidMusicSelection();

          final unlocked = store.unlockedMusicTracks.toSet();
          final visibleTracks = MusicCatalog.all.where((track) {
            if (track.unlockedByDefault) return true;
            return unlocked.contains(track.id);
          }).toList();

          final selectedId = visibleTracks.any((t) => t.id == focus.selectedMusicTrackId.value)
              ? focus.selectedMusicTrackId.value
              : MusicCatalog.defaultTrackId;

          if (visibleTracks.length <= 1) {
            final defaultTrack = MusicCatalog.byId(MusicCatalog.defaultTrackId);
            return Column(
              children: [
                _trackTile(
                  track: defaultTrack,
                  selected: selectedId == defaultTrack.id,
                  unlocked: true,
                  onTap: () => focus.selectMusicTrack(defaultTrack.id),
                ),
                const SizedBox(height: 8),
                ...MusicCatalog.all
                    .where((t) => !t.unlockedByDefault && !unlocked.contains(t.id))
                    .map((track) => _lockedTrackTile(track: track)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Get.find<ShellController>().selectedTab.value = 3;
                    Get.offNamed(AppRoutes.shell);
                  },
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('Go to Store'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: visibleTracks
                .map(
                  (track) => _trackTile(
                    track: track,
                    selected: selectedId == track.id,
                    unlocked: true,
                    onTap: () => focus.selectMusicTrack(track.id),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _trackTile({
    required MusicTrack track,
    required bool selected,
    required bool unlocked,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: unlocked ? onTap : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Colors.cyanAccent : const Color(0xFF243856),
            width: selected ? 2 : 1,
          ),
        ),
        tileColor: AppColors.surface,
        leading: Icon(
          selected ? Icons.graphic_eq : Icons.music_note_outlined,
          color: selected ? Colors.cyanAccent : Colors.white54,
        ),
        title: Text(track.name),
        subtitle: Text(
          track.description,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
            : (track.unlockedByDefault
                ? const Text('Free', style: TextStyle(color: Colors.greenAccent, fontSize: 12))
                : null),
      ),
    );
  }

  Widget _lockedTrackTile({required MusicTrack track}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF243856)),
        ),
        tileColor: AppColors.surface.withValues(alpha: 0.6),
        leading: const Icon(Icons.lock_outline, color: Colors.white38),
        title: Text(track.name, style: const TextStyle(color: Colors.white54)),
        subtitle: Text(
          '${track.price} Game XP in Store',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: TextButton(
          onPressed: () {
            Get.find<ShellController>().selectedTab.value = 3;
            Get.offNamed(AppRoutes.shell);
          },
          child: const Text('Store'),
        ),
      ),
    );
  }
}
