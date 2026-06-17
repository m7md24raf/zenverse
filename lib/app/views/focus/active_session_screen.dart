import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zenverse/app/controllers/focus_controller.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/views/focus/planet_session_hero.dart';

/// Deep-space background used on the orbit session screen.
const _sessionBackground = Color(0xFF050A14);

const _sessionQuotes = [
  'The stars are not seen by day, but they are always there.',
  'Focus is the gravity that keeps your orbit steady.',
  'Every minute in orbit builds your galaxy.',
  'Silence the noise — the universe rewards stillness.',
];

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({
    super.key,
    this.planetImagePath,
  });

  /// When null, uses [FocusController.selectedPlanetImagePath].
  final String? planetImagePath;

  void _onGiveUp(FocusController focus) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0D1528),
        title: const Text('Freeze Warning'),
        content: const Text('Your planet will be frozen for 2 hours. Continue?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              focus.giveUp();
            },
            child: const Text('Give Up'),
          ),
        ],
      ),
    );
  }

  void _showSessionInfo(FocusController focus) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1528),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF243856))),
        ),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Session Info', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.group_outlined,
                label: 'Co-Focusing',
                value: '${focus.activeParticipants.length} active',
              ),
              const SizedBox(height: 10),
              _infoRow(
                icon: Icons.tune_outlined,
                label: 'Mode',
                value: focus.selectedMode.value,
              ),
              const SizedBox(height: 10),
              _infoRow(
                icon: Icons.warning_amber_outlined,
                label: 'Off-app warnings',
                value: '${focus.appLeaveViolations.value}',
              ),
              const SizedBox(height: 10),
              _infoRow(
                icon: Icons.public,
                label: 'Planet',
                value: PlanetCatalog.byId(focus.selectedPlanetId.value).name,
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.cyanAccent),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = Get.find<FocusController>();
    final stars = generateStarfield();
    final quote = _sessionQuotes[focus.selectedPlanetId.value.hashCode.abs() % _sessionQuotes.length];

    return Scaffold(
      backgroundColor: _sessionBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: Get.back,
        ),
        centerTitle: true,
        title: Text(
          'ZENVERSE',
          style: GoogleFonts.orbitron(
            color: Colors.cyanAccent,
            letterSpacing: 2,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => _showSessionInfo(focus),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: StarfieldBackground(stars: stars)),
          SafeArea(
            child: Obx(() {
              final planet = PlanetCatalog.byId(focus.selectedPlanetId.value);
              final imagePath = planetImagePath ?? focus.selectedPlanetImagePath;
              final modeLabel = focus.selectedMode.value.replaceAll(' Mode', '');

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _ModePill(label: modeLabel),
                          const SizedBox(height: 28),
                          PlanetSessionHero(
                            planetImagePath: imagePath,
                            planetType: planet.type,
                          ),
                          const SizedBox(height: 36),
                          _SessionTimerDisplay(remaining: focus.remaining.value),
                          const SizedBox(height: 10),
                          Text(
                            'REMAINING FOCUS TIME',
                            style: GoogleFonts.inter(
                              letterSpacing: 3,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.cyanAccent.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            quote,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.55),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Co-Focusing: ${focus.activeParticipants.length} • Warnings: ${focus.appLeaveViolations.value}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _onGiveUp(focus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 12,
                          shadowColor: Colors.cyanAccent.withValues(alpha: 0.75),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'GIVE UP',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent, width: 1),
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.cyanAccent,
          fontSize: 13,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SessionTimerDisplay extends StatelessWidget {
  const _SessionTimerDisplay({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    const digitStyle = TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      height: 1,
    );
    const colonStyle = TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.bold,
      color: Colors.cyanAccent,
      height: 1,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(minutes, style: digitStyle),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: colonStyle),
        ),
        Text(seconds, style: digitStyle),
      ],
    );
  }
}
