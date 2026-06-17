import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/controllers/auth_controller.dart';
import 'package:zenverse/app/repositories/local/local_data_source.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/theme/app_colors.dart';
import 'package:zenverse/app/views/shared/space_widgets.dart';

/// Preset avatar shown in onboarding; persisted as `profiles.avatar_url` = `preset:<id>`.
const List<Map<String, String>> _kAvatarPresets = [
  {'id': 'saturn_ring', 'emoji': '🪐', 'label': 'Saturn'},
  {'id': 'golden_star', 'emoji': '🌟', 'label': 'Star'},
  {'id': 'crescent_moon', 'emoji': '🌙', 'label': 'Moon'},
  {'id': 'orbit_comet', 'emoji': '☄️', 'label': 'Comet'},
  {'id': 'milky_way', 'emoji': '🌌', 'label': 'Nebula'},
  {'id': 'deep_probe', 'emoji': '🛸', 'label': 'Probe'},
];

String _detectDeviceTimezoneDescriptor() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.inMinutes.abs();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  final zoneName = now.timeZoneName;
  return '$zoneName (UTC$sign$hh:$mm)';
}

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  State<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _sessionsGoal = 2;
  String _avatarPresetId = _kAvatarPresets.first['id']!;
  bool _submitting = false;
  late final String _timezone = _detectDeviceTimezoneDescriptor();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final authUser = Supabase.instance.client.auth.currentUser;
    final hint = AuthController.displayNameGuessFromEmail(authUser?.email);
    final local = Get.find<LocalDataSource>().getProfileJson();
    final seedName =
        ((local != null ? local['display_name'] as String? : null)?.trim()) ?? '';
    if (hint != null && hint.isNotEmpty) {
      _nameController.text = seedName.length >= 2 ? seedName : hint;
    } else if (seedName.length >= 2) {
      _nameController.text = seedName;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final repo = Get.find<ZenRepository>();
    final localDs = Get.find<LocalDataSource>();
    final uid = localDs.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      Get.snackbar('Setup', 'Not signed in. Please log in again.');
      return;
    }
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    setState(() => _submitting = true);
    try {
      await repo.saveProfileOnboarding(
        userId: uid,
        email: email.isNotEmpty ? email : 'user@unknown.local',
        displayName: _nameController.text,
        avatarPresetId: _avatarPresetId,
        dailyGoalSessions: _sessionsGoal,
        timezone: _timezone,
      );
      await Get.find<AuthController>().markProfileOnboardingComplete(uid);
      await Get.find<AuthController>().loadUserData(refreshRemote: true);
      if (!mounted) return;
      Get.offAllNamed(AppRoutes.shell);
    } catch (e) {
      Get.snackbar('Could not save profile', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome aboard',
            style: GoogleFonts.orbitron(
              fontSize: 26,
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us how you’d like to show up in Zenverse. You only see this once per account on this device.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: zenCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Display name', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 60,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'Cosmic Navigator',
                          counterText: '',
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.length < 2) return 'At least 2 characters';
                          if (t.length > 60) return 'Max 60 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Space avatar', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final preset in _kAvatarPresets)
                            _AvatarChip(
                              emoji: preset['emoji']!,
                              label: preset['label']!,
                              selected: preset['id'] == _avatarPresetId,
                              onTap: () => setState(() => _avatarPresetId = preset['id']!),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Daily sessions goal', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                        'How many focus sessions you aim for each day.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var n = 1; n <= 4; n++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: n == 4 ? 0 : 8),
                                child: ChoiceChip(
                                  label: Center(child: Text('$n')),
                                  selected: _sessionsGoal == n,
                                  selectedColor: AppColors.secondary.withValues(alpha: 0.35),
                                  onSelected: (_) => setState(() => _sessionsGoal = n),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Timezone', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: Text(
                          _timezone,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detected from your device clock.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.secondary,
                      foregroundColor: const Color(0xFF071C2A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(
                            'Continue to Zenverse',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: selected ? 2.2 : 1,
              color: selected ? AppColors.secondary : AppColors.primary.withValues(alpha: 0.4),
            ),
            color: Colors.black.withValues(alpha: selected ? 0.32 : 0.18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 12,
                      spreadRadius: 0,
                      color: AppColors.secondary.withValues(alpha: 0.25),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52, maxWidth: 112),
                child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
