import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zenverse/app/controllers/focus_controller.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/theme/app_colors.dart';
import 'package:zenverse/app/views/focus/session_music_picker.dart';
import 'package:zenverse/app/views/shared/space_widgets.dart';

class JourneySetupScreen extends StatelessWidget {
  const JourneySetupScreen({super.key});

  FocusController get _focus => Get.find<FocusController>();
  StoreController get _store => Get.find<StoreController>();

  Future<void> _startJourney() async {
    final focus = _focus;
    final store = _store;

    if (focus.startingSession.value) return;

    focus.ensureValidMusicSelection();

    final selectedId = focus.selectedPlanetId.value;
    if (selectedId.isEmpty || !store.isUnlocked(selectedId)) {
      if (store.isUnlocked('earth')) {
        focus.selectPlanet('earth');
      } else {
        Get.snackbar('Select a planet', 'Choose a destination before starting your journey.');
        return;
      }
    }

    if (focus.selectedMode.value == 'Medium Mode' && !focus.hasBlockedAppsConfigured) {
      await Get.toNamed(AppRoutes.appPermissionPicker);
      if (!focus.hasBlockedAppsConfigured) {
        Get.snackbar('Select apps first', 'Pick apps to block before starting a Medium Mode session.');
        return;
      }
    }

    await focus.startSession();
  }

  void _ensureValidSelection(FocusController focus, StoreController store, String selectedId) {
    if (!store.isUnlocked(selectedId) && store.isUnlocked('earth')) {
      focus.selectPlanet('earth');
    }
  }

  Widget _sessionXpBadge(StoreController store) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 4),
          Text(
            '${store.sessionXp.value}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildOwnedPlanetGrid({
    required String selectedId,
    required List<PlanetDefinition> ownedPlanets,
  }) {
    if (ownedPlanets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No planets available yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: ownedPlanets.length,
      itemBuilder: (context, index) {
        final planet = ownedPlanets[index];
        final isSelected = planet.id == selectedId;

        return _DestinationPlanetCard(
          planet: planet,
          selected: isSelected,
          onTap: () => _focus.selectPlanet(planet.id),
        );
      },
    );
  }

  Widget _storeHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, color: Colors.white38, size: 14),
          SizedBox(width: 6),
          Text(
            'Get more planets in the Store',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = _focus;
    final store = _store;

    return SpaceScaffold(
      appBar: AppBar(
        title: const Text('Focus Journey'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _sessionXpBadge(store),
          ),
        ],
      ),
      body: ListView(
        children: [
          Text('Start Your Journey', style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w800)),
          const Text('Select your destination and prepare for liftoff.'),
          const SizedBox(height: 16),
          sectionLabel('Destination'),
          Obx(() {
            final selectedId = focus.selectedPlanetId.value;
            final unlockedIds = Set<String>.from(store.unlockedPlanets);
            _ensureValidSelection(focus, store, selectedId);
            final effectiveSelectedId = unlockedIds.contains(selectedId) ? selectedId : 'earth';
            final ownedPlanets = PlanetCatalog.all.where((p) => unlockedIds.contains(p.id)).toList();

            return Column(
              children: [
                _buildOwnedPlanetGrid(
                  selectedId: effectiveSelectedId,
                  ownedPlanets: ownedPlanets,
                ),
                _storeHint(),
              ],
            );
          }),
          const SizedBox(height: 8),
          sectionLabel('Engine Mode'),
          Wrap(
            spacing: 8,
            children: ['Easy Mode', 'Medium Mode', 'Hard Mode']
                .map(
                  (m) => Obx(
                    () => ChoiceChip(
                      label: Text(m.replaceAll(' Mode', '')),
                      selected: focus.selectedMode.value == m,
                      onSelected: (_) async {
                        focus.setMode(m);
                        if (m == 'Medium Mode') {
                          await Get.toNamed(AppRoutes.appPermissionPicker);
                        }
                      },
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          sectionLabel('Duration'),
          Obx(
            () => Text(
              '${focus.durationMinutes.value} MIN',
              style: GoogleFonts.orbitron(fontSize: 42),
            ),
          ),
          Row(
            children: [
              IconButton(onPressed: () => focus.adjustMinutes(-5), icon: const Icon(Icons.remove_circle_outline)),
              Expanded(
                child: Obx(
                  () => Slider(
                    value: focus.durationMinutes.value.toDouble(),
                    min: 5,
                    max: 180,
                    onChanged: (v) => focus.durationMinutes.value = v.round(),
                  ),
                ),
              ),
              IconButton(onPressed: () => focus.adjustMinutes(5), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const SizedBox(height: 8),
          const SessionMusicPicker(),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.surface,
            title: const Text('Invite friends to this session'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.toNamed(AppRoutes.sessionFriendsPicker),
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (focus.startingSession.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return primaryButton('Start Journey', _startJourney);
          }),
        ],
      ),
    );
  }
}

class _DestinationPlanetCard extends StatelessWidget {
  const _DestinationPlanetCard({
    required this.planet,
    required this.selected,
    required this.onTap,
  });

  final PlanetDefinition planet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Colors.cyanAccent : const Color(0xFF243856),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: PlanetWidget(type: planet.type, size: 72, glow: selected)),
              const SizedBox(height: 6),
              Text(
                planet.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                planet.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GalaxyPickerScreen extends StatelessWidget {
  const GalaxyPickerScreen({super.key});

  FocusController get _focus => Get.find<FocusController>();
  StoreController get _store => Get.find<StoreController>();

  Widget _sessionXpBadge(StoreController store) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 4),
          Text(
            '${store.sessionXp.value}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildOwnedPlanetGrid({
    required String selectedId,
    required List<PlanetDefinition> ownedPlanets,
  }) {
    final focus = _focus;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: ownedPlanets.length,
      itemBuilder: (context, index) {
        final planet = ownedPlanets[index];
        final isSelected = planet.id == selectedId;

        return _DestinationPlanetCard(
          planet: planet,
          selected: isSelected,
          onTap: () {
            focus.selectPlanet(planet.id);
            Get.back();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = _focus;
    final store = _store;

    return SpaceScaffold(
      appBar: AppBar(
        title: const Text('My Planets'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _sessionXpBadge(store),
          ),
        ],
      ),
      body: Obx(() {
        final selectedId = focus.selectedPlanetId.value;
        final unlockedIds = Set<String>.from(store.unlockedPlanets);
        final ownedPlanets = PlanetCatalog.all.where((p) => unlockedIds.contains(p.id)).toList();
        final effectiveSelectedId = unlockedIds.contains(selectedId) ? selectedId : 'earth';

        return _buildOwnedPlanetGrid(
          selectedId: effectiveSelectedId,
          ownedPlanets: ownedPlanets,
        );
      }),
    );
  }
}
