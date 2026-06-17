import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zenverse/app/controllers/auth_controller.dart';
import 'package:zenverse/app/controllers/chat_controller.dart';
import 'package:zenverse/app/controllers/focus_controller.dart';
import 'package:zenverse/app/controllers/friends_controller.dart';
import 'package:zenverse/app/controllers/game_2048_controller.dart';
import 'package:zenverse/app/controllers/orbit_puzzle_controller.dart';
import 'package:zenverse/app/controllers/shell_controller.dart';
import 'package:zenverse/app/controllers/stats_controller.dart';
import 'package:zenverse/app/controllers/store_controller.dart';
import 'package:zenverse/app/models/music_catalog.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/services/music_service.dart';
import 'package:zenverse/app/services/permission_service.dart';
import 'package:zenverse/app/theme/app_colors.dart';
import 'package:zenverse/app/views/shared/space_widgets.dart';
import 'package:zenverse/widgets/ai_chat_bubble/ai_chat_bubble.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Fade in immediately after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1);
    });
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      final auth = Get.find<AuthController>();
      final box = Hive.box('zenverse_box');
      final permissionsDone =
          box.get('permissions_onboarding_done', defaultValue: false) as bool;
      if (!permissionsDone) {
        Get.offNamed(AppRoutes.permissionOnboarding);
      } else if (auth.isFirstLaunch) {
        Get.offNamed(AppRoutes.onboarding1);
      } else if (auth.isLoggedIn || auth.isGuest) {
        if (auth.isGuest) {
          Get.offNamed(AppRoutes.shell);
        } else if (auth.needsProfileOnboarding) {
          Get.offNamed(AppRoutes.profileOnboarding);
        } else {
          Get.offNamed(AppRoutes.shell);
        }
      } else {
        Get.offNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    body: Center(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZenLogo(size: 170),
            const SizedBox(height: 18),
            Text(
              'Zenverse',
              style: GoogleFonts.orbitron(
                fontSize: 40,
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Celestial Equilibrium',
              style: TextStyle(
                color: AppColors.textSecondary,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PermissionOnboardingScreen extends StatelessWidget {
  const PermissionOnboardingScreen({super.key});

  static void _goNextAfterPermissions(AuthController auth) {
    if (auth.isGuest) {
      Get.offNamed(AppRoutes.shell);
    } else if (auth.isLoggedIn && auth.needsProfileOnboarding) {
      Get.offNamed(AppRoutes.profileOnboarding);
    } else if (auth.isLoggedIn) {
      Get.offNamed(AppRoutes.shell);
    } else if (auth.isFirstLaunch) {
      Get.offNamed(AppRoutes.onboarding1);
    } else {
      Get.offNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final permissionService = Get.find<PermissionService>();
    final loading = false.obs;
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Permission Setup')),
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enable Focus Protection',
              style: GoogleFonts.orbitron(fontSize: 30),
            ),
            const SizedBox(height: 8),
            const Text(
              'Grant the following once so Zenverse can protect your sessions effectively.',
            ),
            const SizedBox(height: 16),
            _permissionTile(
              Icons.insights_outlined,
              'Usage Access',
              'Detect app switching in Medium/Hard sessions.',
            ),
            _permissionTile(
              Icons.do_not_disturb_alt_outlined,
              'Do Not Disturb',
              'Silence interruptions while focusing.',
            ),
            _permissionTile(
              Icons.notifications_active_outlined,
              'Notification Listener',
              'Detect disruptive notifications and alert you.',
            ),
            _permissionTile(
              Icons.layers_outlined,
              'Display over other apps',
              'Show urgent warning overlays while in session.',
            ),
            const Spacer(),
            primaryButton(
              loading.value ? 'Opening settings...' : 'Start Permission Setup',
              () async {
                if (loading.value) return;
                loading.value = true;
                await permissionService.handleInitialPermissionOnboarding();
                await Hive.box(
                  'zenverse_box',
                ).put('permissions_onboarding_done', true);
                loading.value = false;
                _goNextAfterPermissions(auth);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading.value
                  ? null
                  : () async {
                      await Hive.box(
                        'zenverse_box',
                      ).put('permissions_onboarding_done', true);
                      _goNextAfterPermissions(auth);
                    },
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: zenCard(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class OnboardingCoreScreen extends StatelessWidget {
  const OnboardingCoreScreen({super.key});

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    body: Column(
      children: [
        Row(
          children: [
            const ZenLogo(size: 36),
            const SizedBox(width: 8),
            Text(
              'Zenverse',
              style: GoogleFonts.orbitron(color: AppColors.secondary),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Get.offNamed(AppRoutes.login),
              child: const Text('Skip'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const PlanetWidget(type: PlanetType.saturn, size: 240),
        const SizedBox(height: 12),
        Text(
          'Core Concept',
          style: GoogleFonts.orbitron(color: AppColors.secondary),
        ),
        Text(
          'Transform Focus\ninto Planets',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(fontSize: 34),
        ),
        const SizedBox(height: 8),
        const Text('Study. Earn. Collect.'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) => _dayDot('${i + 1}')),
        ),
        const Spacer(),
        primaryButton('Next', () => Get.toNamed(AppRoutes.onboarding2)),
      ],
    ),
  );
}

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ZenLogo(size: 100),
        const SizedBox(height: 20),
        Text(
          'Welcome to\nyour Universe',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(fontSize: 38),
        ),
        const SizedBox(height: 10),
        const Text(
          'Focus deeply, grow your galaxy,\nand find your inner peace.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        primaryButton('Get Started', () async {
          await Get.find<AuthController>().completeOnboarding();
          Get.offNamed(AppRoutes.login);
        }),
      ],
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return SpaceScaffold(
      body: ListView(
        children: [
          const SizedBox(height: 18),
          const Center(child: ZenLogo(size: 86, glow: false)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Zenverse',
              style: GoogleFonts.orbitron(
                fontSize: 34,
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to\nyour Universe',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 44,
              height: 1.06,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Focus deeply, grow your galaxy,\nand find your inner peace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: zenCard(),
            child: Column(
              children: [
                formInput(
                  'Email address',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                formInput('Password', controller: _password, obscure: true),
                const SizedBox(height: 14),
                Obx(
                  () => primaryButton(
                    auth.loading.value ? 'Loading...' : 'Login',
                    () => auth.loginWithEmailPassword(
                      email: _email.text,
                      password: _password.text,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Obx(
                  () => OutlinedButton(
                    onPressed: auth.googleLoading.value
                        ? null
                        : auth.loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.55),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      auth.googleLoading.value
                          ? 'Signing in...'
                          : 'Sign in with Google',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: auth.continueAsGuest,
                  child: const Text('Skip for now (Continue as Guest)'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
            child: const Text('Forgot password?'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? "),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.register),
                child: const Text(
                  'Register',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Register')),
      body: ListView(
        children: [
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: zenCard(),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(hintText: 'Email'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter your email';
                        if (!t.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(hintText: 'Password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a password';
                        if (v.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        hintText: 'Confirm password',
                      ),
                      onFieldSubmitted: (_) => _submit(auth),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirm your password';
                        if (v != _password.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Obx(() {
                      final busy = auth.loading.value;
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: busy ? null : () => _submit(auth),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.secondary,
                            foregroundColor: const Color(0xFF071C2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            busy ? 'Creating account...' : 'Register',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(AuthController auth) {
    if (auth.loading.value) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext(shouldSave: true);
    auth.registerWithEmailPassword(
      email: _email.text.trim(),
      password: _password.text,
      confirmPassword: _confirm.text.trim(),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => _authScaffold('Reset Orbit', [
    formInput('Email address'),
    const SizedBox(height: 14),
    primaryButton(
      'Send Reset Code',
      () => Get.toNamed(AppRoutes.otpVerification),
    ),
  ]);
}

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});
  @override
  Widget build(BuildContext context) => _authScaffold('OTP Verification', [
    const Text('Enter the code sent to your email'),
    const SizedBox(height: 12),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (_) => _otpBox()),
    ),
    const SizedBox(height: 14),
    primaryButton('Verify', () => Get.toNamed(AppRoutes.resetPassword)),
  ]);
}

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => _authScaffold('Save New Password', [
    formInput('New password', obscure: true),
    const SizedBox(height: 10),
    formInput('Confirm password', obscure: true),
    const SizedBox(height: 14),
    primaryButton('Save New Password', () => Get.offAllNamed(AppRoutes.login)),
  ]);
}

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ShellController>();
    final tabs = const [
      FocusHomeScreen(),
      GalaxyScreen(),
      StatsScreen(),
      StoreScreen(),
      ProfileScreen(),
    ];
    return Obx(
      () => SpaceScaffold(
        body: tabs[shell.selectedTab.value],
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF243856)),
            color: AppColors.surface.withValues(alpha: 0.95),
          ),
          child: NavigationBar(
            selectedIndex: shell.selectedTab.value,
            onDestinationSelected: (i) {
              if (shell.selectedTab.value == 3 &&
                  i != 3 &&
                  Get.isRegistered<MusicService>()) {
                unawaited(Get.find<MusicService>().stopPreview());
              }
              shell.selectedTab.value = i;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                label: 'Focus',
              ),
              NavigationDestination(icon: Icon(Icons.public), label: 'Galaxy'),
              NavigationDestination(
                icon: Icon(Icons.show_chart),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                label: 'Store',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FocusHomeScreen extends StatelessWidget {
  const FocusHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final focus = Get.find<FocusController>();
    final auth = Get.find<AuthController>();
    final completedToday = 0.55; // placeholder UI metric
    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          children: [
            Row(
              children: [
                Text(
                  'ZENVERSE',
                  style: GoogleFonts.orbitron(
                    color: AppColors.primary,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF243856)),
                  ),
                  child: Text(
                    'YOUR LEVEL 1',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.streak),
              child: Obx(
                () => Text(
                  'Momentum\n${focus.streakDays.value} Day Streak',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Obx(
                () => ProgressRing(
                  progress: 0.0,
                  size: 260,
                  stroke: 14,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${focus.durationMinutes.value}:00',
                        style: GoogleFonts.orbitron(
                          fontSize: 54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'DEEP FOCUS',
                        style: GoogleFonts.inter(
                          letterSpacing: 3,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            primaryButton(
              'Start Session',
              () => Get.toNamed(AppRoutes.journeySetup),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: zenCard(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Daily Progress'),
                      const Spacer(),
                      Text(
                        '${(completedToday * 4).toStringAsFixed(1)}/4 Hours Focused today',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: completedToday,
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor: const Color(
                        0xFF243856,
                      ).withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: zenCard(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel('Your mission'),
                        Text(
                          'Active World:\nSaturn',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Unlocking deeper focus in the rings of calm.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const PlanetWidget(
                    type: PlanetType.saturn,
                    size: 110,
                    glow: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Social',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (!auth.isLoggedIn) {
                      Get.snackbar(
                        'Login required',
                        'Sign in to use Friends & Chat.',
                      );
                      Get.toNamed(AppRoutes.login);
                      return;
                    }
                    Get.toNamed(AppRoutes.friends);
                  },
                  icon: const Icon(Icons.people_alt_outlined),
                ),
              ],
            ),
          ],
        ),
        const AiChatBubble(assistantTitle: 'Zen AI'),
      ],
    );
  }
}

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});
  @override
  Widget build(BuildContext context) => SpaceScaffold(
    appBar: AppBar(
      title: Text(
        'ZENVERSE',
        style: GoogleFonts.orbitron(color: AppColors.primary, letterSpacing: 2),
      ),
      leading: IconButton(
        onPressed: Get.back,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: Obx(() {
      final focus = Get.find<FocusController>();
      final streak = focus.streakDays.value;
      final nextTarget = max(7, ((streak ~/ 7) + 1) * 7);
      final pct = (streak / nextTarget).clamp(0.0, 1.0);
      return Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 22,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.local_fire_department,
                size: 48,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$streak Day Streak',
            style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            "You're glowing, Walker.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: zenCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionLabel('Next milestone'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nebula Walker\nBadge',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.12,
                        ),
                      ),
                    ),
                    Text(
                      '$streak/$nextTarget\ndays',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    color: AppColors.primary,
                    backgroundColor: const Color(
                      0xFF243856,
                    ).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${max(0, nextTarget - streak)} days left to reach Level 2',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: zenCard(),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '99',
                    style: GoogleFonts.orbitron(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"Consistency is the bridge between goals\nand accomplishment."',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'DAILY AFFIRMATION',
                  style: GoogleFonts.inter(
                    letterSpacing: 3,
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          primaryButton('Continue Journey', Get.back),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              side: const BorderSide(color: Color(0xFF243856)),
            ),
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'My Zenverse streak is $streak days!'),
            ),
            child: const Text('Share Progress'),
          ),
          const SizedBox(height: 6),
        ],
      );
    }),
  );
}

class AppPermissionPickerScreen extends StatefulWidget {
  const AppPermissionPickerScreen({super.key});

  @override
  State<AppPermissionPickerScreen> createState() =>
      _AppPermissionPickerScreenState();
}

class _AppPermissionPickerScreenState extends State<AppPermissionPickerScreen> {
  final _selected = <String>{}.obs;
  final _apps = <AppInfo>[].obs;
  final _loading = true.obs;

  @override
  void initState() {
    super.initState();
    final raw =
        Hive.box('zenverse_box').get('blocked_apps', defaultValue: <dynamic>[])
            as List<dynamic>;
    _selected.addAll(raw.map((e) => e.toString()));
    _loadApps();
  }

  Future<void> _loadApps() async {
    if (!GetPlatform.isAndroid) {
      _loading.value = false;
      return;
    }
    final apps = await InstalledApps.getInstalledApps(
      withIcon: true,
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _apps.assignAll(apps);
    _loading.value = false;
  }

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    appBar: AppBar(title: const Text('Select Apps to Block')),
    body: Obx(() {
      if (_loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!GetPlatform.isAndroid) {
        return Column(
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'App blocking selection is available on Android only.',
                ),
              ),
            ),
            primaryButton('Done', Get.back),
          ],
        );
      }
      return Column(
        children: [
          const Text(
            'Choose apps that should trigger warnings during Medium mode sessions.',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _apps.length,
              itemBuilder: (_, i) {
                final app = _apps[i];
                final pkg = app.packageName;
                return Obx(
                  () => CheckboxListTile(
                    value: _selected.contains(pkg),
                    onChanged: (v) =>
                        v == true ? _selected.add(pkg) : _selected.remove(pkg),
                    title: Text(app.name),
                    subtitle: Text(
                      pkg,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    secondary: app.icon != null
                        ? Image.memory(app.icon!, width: 28, height: 28)
                        : const Icon(Icons.apps),
                  ),
                );
              },
            ),
          ),
          primaryButton('Save Selection', () async {
            await Hive.box(
              'zenverse_box',
            ).put('blocked_apps', _selected.toList());
            Get.back();
          }),
        ],
      );
    }),
  );
}

class SessionFriendsPickerScreen extends StatefulWidget {
  const SessionFriendsPickerScreen({super.key});

  @override
  State<SessionFriendsPickerScreen> createState() =>
      _SessionFriendsPickerScreenState();
}

class _SessionFriendsPickerScreenState
    extends State<SessionFriendsPickerScreen> {
  final _selectedFriendIds = <String>{};

  @override
  void initState() {
    super.initState();
    Get.find<FriendsController>().refreshAll();
  }

  Future<void> _sendInvites() async {
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      Get.snackbar(
        'Sign in required',
        'Log in to invite friends to a session.',
      );
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      Get.snackbar('Select friends', 'Choose at least one friend to invite.');
      return;
    }
    Get.find<FocusController>().setInvitedFriends(_selectedFriendIds.toList());
    Get.back();
    Get.snackbar(
      'Friends selected',
      '${_selectedFriendIds.length} friend(s) will be invited when you start the session.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = Get.find<FriendsController>();
    final auth = Get.find<AuthController>();

    if (!auth.isLoggedIn) {
      return SpaceScaffold(
        appBar: AppBar(title: const Text('Invite Friends')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign in to invite friends to co-focus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                primaryButton(
                  'Go to Login',
                  () => Get.toNamed(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SpaceScaffold(
      appBar: AppBar(title: const Text('Invite Friends')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Select accepted friends to invite when your session starts.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (friends.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (friends.acceptedFriends.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No friends yet. Add friends by code on the Friends tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        primaryButton(
                          'Open Friends',
                          () => Get.toNamed(AppRoutes.friends),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: friends.acceptedFriends.length,
                itemBuilder: (_, index) {
                  final friend = friends.acceptedFriends[index];
                  final isSelected = _selectedFriendIds.contains(friend.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedFriendIds.add(friend.id);
                        } else {
                          _selectedFriendIds.remove(friend.id);
                        }
                      });
                    },
                    title: Text(friend.displayName),
                    subtitle: Text(friend.userCode),
                  );
                },
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: primaryButton('Send Invite', _sendInvites),
          ),
        ],
      ),
    );
  }
}

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({super.key});
  @override
  Widget build(BuildContext context) => SpaceScaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, size: 36, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Session Complete!',
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your galaxy is expanding beautifully.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: zenCard(),
                child: Column(
                  children: [
                    sectionLabel('Duration'),
                    Text(
                      '45:00',
                      style: GoogleFonts.orbitron(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: zenCard(),
                child: Column(
                  children: [
                    sectionLabel('Focus mode'),
                    Text(
                      'Deep Focus',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD4B6FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: zenCard(),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      '+50 Stars',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: zenCard(),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFD4B6FF)),
                    const SizedBox(width: 10),
                    Text(
                      '+100 XP',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: zenCard(),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF7A2A).withValues(alpha: 0.12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_fire_department,
                    color: Color(0xFFFF7A2A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '7 Day Streak',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "You're on fire! Keep it up.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA34A).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'NEW RECORD',
                  style: TextStyle(
                    color: Color(0xFFFFA34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        primaryButton('View My Galaxy', () => Get.offNamed(AppRoutes.shell)),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            side: const BorderSide(color: Color(0xFF243856)),
          ),
          onPressed: () => Get.toNamed(AppRoutes.shareVictory),
          child: const Text('Share Achievement'),
        ),
      ],
    ),
  );
}

class ShareVictoryScreen extends StatelessWidget {
  const ShareVictoryScreen({super.key});
  @override
  Widget build(BuildContext context) => _listPicker(
    'Share Your Victory',
    const ['Alex', 'Mila', 'Jordan'],
    'Send',
  );
}

class ScheduleReminderScreen extends StatelessWidget {
  const ScheduleReminderScreen({super.key});
  @override
  Widget build(BuildContext context) => SpaceScaffold(
    appBar: AppBar(title: const Text('Schedule Focus Time')),
    body: Column(
      children: [
        formInput('Task label'),
        const SizedBox(height: 8),
        formInput('Duration minutes'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: const [
            Chip(label: Text('Mon')),
            Chip(label: Text('Tue')),
            Chip(label: Text('Wed')),
            Chip(label: Text('Thu')),
            Chip(label: Text('Fri')),
          ],
        ),
        const SizedBox(height: 12),
        primaryButton('Save', Get.back),
      ],
    ),
  );
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = Get.find<FriendsController>();
    final chat = Get.find<ChatController>();
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return SpaceScaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: zenCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  'Social features require login',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to add friends, chat, and co-focus together.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                primaryButton(
                  'Go to Login',
                  () => Get.toNamed(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          Obx(() {
            final code = auth.userCode.value;
            if (code.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Your friend code: $code\nShare this code so others can add you.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter friend code (ZEN-XXXX)',
                    ),
                    onSubmitted: friends.searchByCode,
                  ),
                ),
                IconButton(
                  onPressed: () => friends.searchByCode(_codeController.text),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            if (friends.searching.value) {
              return const LinearProgressIndicator();
            }
            final message = friends.searchMessage.value;
            if (message != null && message.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }
            final result = friends.searchResult.value;
            if (result == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: AppColors.surface,
                child: ListTile(
                  title: Text(result.displayName),
                  subtitle: Text(result.userCode),
                  trailing: IconButton(
                    onPressed: () => friends.sendFriendRequest(result),
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (friends.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: friends.refreshAll,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text('Friend Requests', style: GoogleFonts.orbitron()),
                    const SizedBox(height: 6),
                    if (friends.pendingRequests.isEmpty)
                      const Text(
                        'No pending requests',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ...friends.pendingRequests.map(
                      (req) => Card(
                        color: AppColors.surface,
                        child: ListTile(
                          title: Text(
                            req.requesterProfile?.displayName ??
                                req.requesterId,
                          ),
                          subtitle: Text(req.requesterProfile?.userCode ?? ''),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => friends.acceptRequest(req),
                                child: const Text('Accept'),
                              ),
                              TextButton(
                                onPressed: () => friends.declineRequest(req),
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Accepted Friends', style: GoogleFonts.orbitron()),
                    const SizedBox(height: 6),
                    if (friends.acceptedFriends.isEmpty)
                      const Text(
                        'No accepted friends yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ...friends.acceptedFriends.map(
                      (f) => Card(
                        color: AppColors.surface,
                        child: ListTile(
                          title: Text(f.displayName),
                          subtitle: Text(f.userCode),
                          trailing: IconButton(
                            onPressed: () {
                              chat.openChatWith(peerUserId: f.id);
                              Get.toNamed(AppRoutes.directChat);
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class DirectChatScreen extends StatelessWidget {
  const DirectChatScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final chat = Get.find<ChatController>();
    final auth = Get.find<AuthController>();
    if (!auth.isLoggedIn) {
      return SpaceScaffold(
        appBar: AppBar(title: const Text('Direct Chat')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: zenCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  'Chat requires login',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to send messages to accepted friends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                primaryButton(
                  'Go to Login',
                  () => Get.toNamed(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final messageController = TextEditingController();
    final selectedFriend = RxnString(chat.activePeerId.value);
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Direct Chat')),
      body: Column(
        children: [
          Obx(() {
            if (chat.loadingFriends.value) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              );
            }
            if (chat.acceptedFriends.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: zenCard(),
                child: const Text(
                  'No accepted friends yet. Accept a request to start chatting.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return DropdownButtonFormField<String>(
              value:
                  selectedFriend.value ??
                  (chat.acceptedFriends.isNotEmpty
                      ? chat.acceptedFriends.first.id
                      : null),
              items: chat.acceptedFriends
                  .map(
                    (f) => DropdownMenuItem<String>(
                      value: f.id,
                      child: Text('${f.displayName} (${f.userCode})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                selectedFriend.value = value;
                chat.openChatWith(peerUserId: value);
              },
              decoration: const InputDecoration(labelText: 'Select friend'),
            );
          }),
          const SizedBox(height: 8),
          Obx(
            () => Expanded(
              child: chat.loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: chat.messages.length,
                      itemBuilder: (_, i) {
                        final msg = chat.messages[i];
                        final isMine = msg.senderId == chat.currentUserId;
                        return ListTile(
                          title: Text(msg.content),
                          subtitle: Text(isMine ? 'You' : 'Friend'),
                        );
                      },
                    ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(hintText: 'Type message'),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await chat.sendMessage(messageController.text);
                  messageController.clear();
                },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GalaxyScreen extends StatelessWidget {
  const GalaxyScreen({super.key});

  static const _floatingPositions = [
    Offset(0.15, 0.35),
    Offset(0.5, 0.15),
    Offset(0.75, 0.45),
    Offset(0.25, 0.65),
    Offset(0.6, 0.7),
    Offset(0.85, 0.25),
    Offset(0.4, 0.5),
    Offset(0.1, 0.75),
  ];

  void _openStoreTab() {
    Get.find<ShellController>().selectedTab.value = 3;
  }

  double _floatingPlanetSize(int index) {
    if (index == 0) return 96;
    return 54 + (index % 3) * 8;
  }

  Widget _buildFloatingGalaxy(List<PlanetDefinition> ownedPlanets) {
    if (ownedPlanets.isEmpty) {
      return Center(
        child: Text(
          'No worlds yet',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < ownedPlanets.length; i++)
              Builder(
                builder: (_) {
                  final planet = ownedPlanets[i];
                  final size = _floatingPlanetSize(i);
                  final pos = _floatingPositions[i % _floatingPositions.length];
                  return Positioned(
                    left: pos.dx * (width - size).clamp(0, width),
                    top: pos.dy * (height - size).clamp(0, height),
                    child: PlanetWidget(
                      type: planet.type,
                      size: size,
                      glow: i == 0,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildCollectionCard(
    PlanetDefinition planet, {
    required bool isOwned,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: zenCard(),
      child: Column(
        children: [
          PlanetWidget(type: planet.type, size: 92, glow: isOwned),
          const SizedBox(height: 10),
          Text(
            planet.name,
            style: TextStyle(
              color: isOwned ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            isOwned ? planet.description : 'Get in Store',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isOwned ? AppColors.textSecondary : Colors.amber,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (isOwned) {
      return card;
    }

    return GestureDetector(
      onTap: _openStoreTab,
      child: Stack(
        children: [
          Opacity(opacity: 0.4, child: card),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.15),
              ),
              child: const Center(
                child: Icon(Icons.lock, color: Colors.white70, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Get.find<StoreController>();
    final cardWidth = (MediaQuery.sizeOf(context).width - 44) / 2;

    return ListView(
      children: [
        const SizedBox(height: 8),
        Text(
          'My Galaxy',
          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Obx(() {
          final unlockedIds = Set<String>.from(store.unlockedPlanets);
          final count = PlanetCatalog.all
              .where((p) => unlockedIds.contains(p.id))
              .length;
          return Text(
            'Solar System\nYour $count discovered worlds',
            style: const TextStyle(color: AppColors.textSecondary),
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          final unlockedIds = Set<String>.from(store.unlockedPlanets);
          final ownedPlanets = PlanetCatalog.all
              .where((p) => unlockedIds.contains(p.id))
              .toList();
          return Container(
            height: 300,
            decoration: zenCard(),
            child: _buildFloatingGalaxy(ownedPlanets),
          );
        }),
        const SizedBox(height: 14),
        primaryButton(
          'Enter Sanctuary',
          () => Get.toNamed(AppRoutes.planetGameSelection),
        ),
        const SizedBox(height: 14),
        Text(
          'Celestial Collection',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final unlockedIds = Set<String>.from(store.unlockedPlanets);
          final owned = PlanetCatalog.all
              .where((p) => unlockedIds.contains(p.id))
              .toList();
          final locked = PlanetCatalog.all
              .where((p) => !unlockedIds.contains(p.id))
              .toList();

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final planet in owned)
                SizedBox(
                  width: cardWidth,
                  child: _buildCollectionCard(planet, isOwned: true),
                ),
              for (final planet in locked)
                SizedBox(
                  width: cardWidth,
                  child: _buildCollectionCard(planet, isOwned: false),
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class PlanetGameSelectionScreen extends StatelessWidget {
  const PlanetGameSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) => SpaceScaffold(
    appBar: AppBar(title: const Text('Planet Games')),
    body: Row(
      children: [
        Expanded(
          child: _gameCard('2048', () => Get.toNamed(AppRoutes.game2048)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _gameCard(
            'Orbit Puzzle',
            () => Get.toNamed(AppRoutes.orbitPuzzle),
          ),
        ),
      ],
    ),
  );
}

class Game2048Screen extends StatelessWidget {
  const Game2048Screen({super.key});
  @override
  Widget build(BuildContext context) {
    final game = Get.find<Game2048Controller>();
    return SpaceScaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            'Score: ${game.score.value}',
            style: GoogleFonts.orbitron(fontSize: 18),
          ),
        ),
        actions: [
          TextButton(onPressed: game.reset, child: const Text('Reset')),
        ],
      ),
      body: Column(
        children: [
          Obx(
            () => game.over.value
                ? const Text('No moves left.')
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(
              child: GestureDetector(
                onPanEnd: (d) {
                  game.handleSwipe(
                    dx: d.velocity.pixelsPerSecond.dx,
                    dy: d.velocity.pixelsPerSecond.dy,
                  );
                },
                child: Obx(() {
                  final cells = game.grid.toList();
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cells.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                        ),
                    itemBuilder: (_, i) {
                      final value = cells[i];
                      return RepaintBoundary(
                        child: Card(
                          color: value == 0
                              ? AppColors.surface
                              : AppColors.secondary.withValues(
                                  alpha:
                                      0.2 + min(0.6, log(max(2, value)) / 10),
                                ),
                          child: Center(
                            child: value == 0
                                ? const SizedBox.shrink()
                                : Text(
                                    '$value',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrbitPuzzleScreen extends StatelessWidget {
  const OrbitPuzzleScreen({super.key});

  Widget _buildTile({
    required bool isOpen,
    required String symbol,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isOpen ? const Color(0xFF1A3A5C) : const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen
                ? Colors.cyanAccent.withValues(alpha: 0.3)
                : Colors.white12,
            width: 0.5,
          ),
        ),
        child: isOpen
            ? Center(
                child: Text(
                  symbol,
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = Get.find<OrbitPuzzleController>();
    return SpaceScaffold(
      appBar: AppBar(
        title: const Text('Orbit Puzzle'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => puzzle.startNewGame(level: v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Easy', child: Text('Easy (4x4)')),
              PopupMenuItem(value: 'Medium', child: Text('Medium (5x6)')),
              PopupMenuItem(value: 'Hard', child: Text('Hard (6x6)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(
            () => Text(
              'Level: ${puzzle.difficulty.value} | Moves: ${puzzle.moves.value}',
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RepaintBoundary(
              child: Obx(() {
                final cardList = puzzle.cards.toList();
                final revealedIndices = Set<int>.from(puzzle.revealed);
                final matchedIndices = Set<int>.from(puzzle.matched);
                final columnCount = puzzle.columns;

                return GridView.builder(
                  itemCount: cardList.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                  ),
                  itemBuilder: (_, i) {
                    final isOpen =
                        revealedIndices.contains(i) ||
                        matchedIndices.contains(i);
                    return RepaintBoundary(
                      child: _buildTile(
                        isOpen: isOpen,
                        symbol: cardList[i],
                        onTap: () => puzzle.tapCard(i),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final stats = Get.find<StatsController>();
    return Obx(
      () => RefreshIndicator(
        onRefresh: stats.refreshStats,
        child: ListView(
          children: [
            Text(
              'Your Orbital Progress',
              style: GoogleFonts.orbitron(fontSize: 34),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: stats.chartSpots.isEmpty
                          ? const [FlSpot(0, 0)]
                          : stats.chartSpots,
                      color: AppColors.secondary,
                      isCurved: true,
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppColors.surface,
              child: ListTile(
                title: const Text('Total Sessions'),
                subtitle: Text(
                  '${stats.totalSessions.value} completed sessions',
                ),
              ),
            ),
            Card(
              color: AppColors.surface,
              child: ListTile(
                title: const Text('Total Focus Time'),
                subtitle: Text(
                  '${stats.totalFocusMinutes.value} minutes focused',
                ),
              ),
            ),
            Card(
              color: AppColors.surface,
              child: ListTile(
                title: const Text('Current Streak'),
                subtitle: Text('${stats.currentStreak.value} days'),
              ),
            ),
            Card(
              color: AppColors.surface,
              child: ListTile(
                title: const Text('Longest Streak'),
                subtitle: Text('${stats.longestStreak.value} days'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    final shell = Get.find<ShellController>();
    _tabWorker = ever<int>(shell.selectedTab, (tab) {
      if (tab != 3 && Get.isRegistered<MusicService>()) {
        unawaited(Get.find<MusicService>().stopPreview());
      }
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    if (Get.isRegistered<MusicService>()) {
      unawaited(Get.find<MusicService>().stopPreview());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const _StoreScreenBody();
}

class _StoreScreenBody extends StatelessWidget {
  const _StoreScreenBody();

  Widget _storePlanetCard({
    required PlanetDefinition planet,
    required bool isOwned,
    required bool canAfford,
    required StoreController store,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOwned
              ? Colors.cyanAccent.withValues(alpha: 0.4)
              : Colors.white12,
          width: isOwned ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: planet.glowColor.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: Image.asset(
                planet.imageAssetPath,
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) =>
                    PlanetWidget(type: planet.type, size: 56, glow: false),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  planet.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (!planet.unlockedByDefault) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${planet.price} Session XP',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: planet.unlockedByDefault || isOwned
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '✓ Owned',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    ),
                  )
                : ElevatedButton(
                    onPressed: canAfford
                        ? () async {
                            final success = await store.purchasePlanet(
                              planet.id,
                            );
                            if (success) {
                              Get.snackbar(
                                '🎉 Unlocked!',
                                '${planet.name} is now available in Focus Journey',
                                backgroundColor: Colors.cyanAccent.withValues(
                                  alpha: 0.15,
                                ),
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? Colors.cyanAccent
                          : Colors.white12,
                      foregroundColor: canAfford
                          ? Colors.black
                          : Colors.white30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(canAfford ? 'Unlock' : 'Need XP'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _storeMusicTrackCard({
    required MusicTrack track,
    required bool isOwned,
    required bool canAfford,
    required StoreController store,
    required MusicService music,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOwned
              ? Colors.cyanAccent.withValues(alpha: 0.4)
              : Colors.white12,
          width: isOwned ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.music_note,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (!track.unlockedByDefault) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.videogame_asset_rounded,
                        color: Color(0xFFD4B6FF),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${track.price} Game XP',
                        style: const TextStyle(
                          color: Color(0xFFD4B6FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 36,
            child: Obx(() {
              final isPreviewing = music.previewTrackId.value == track.id;
              return IconButton(
                padding: EdgeInsets.zero,
                tooltip: isPreviewing ? 'Previewing' : 'Preview',
                onPressed: () => music.playPreview(
                  trackId: track.id,
                  assetPath: track.assetPath,
                ),
                icon: Icon(
                  isPreviewing ? Icons.equalizer : Icons.play_circle_outline,
                  color: isPreviewing ? Colors.cyanAccent : AppColors.primary,
                  size: 26,
                ),
              );
            }),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: track.unlockedByDefault || isOwned
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      track.unlockedByDefault ? 'Free' : 'Owned',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: canAfford
                        ? () async {
                            final ok = await store.purchaseMusicTrack(track.id);
                            if (ok) {
                              Get.snackbar(
                                'Unlocked',
                                '${track.name} is ready for your sessions.',
                              );
                            } else {
                              Get.snackbar(
                                'Not enough Game XP',
                                'Win mini-games to earn Game XP for tracks.',
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? Colors.cyanAccent
                          : Colors.white12,
                      foregroundColor: canAfford
                          ? Colors.black
                          : Colors.white30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(canAfford ? 'Buy' : 'Need XP'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _storeMusicSection(
    StoreController store,
    MusicService music,
    int gameXpBalance,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            children: [
              Text(
                '🎵  Music Tracks',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Ambient audio for focus',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          final unlockedIds = Set<String>.from(store.unlockedMusicTracks);
          return Column(
            children: MusicCatalog.all.map((track) {
              final isOwned = unlockedIds.contains(track.id);
              final canAfford = gameXpBalance >= track.price;
              return _storeMusicTrackCard(
                track: track,
                isOwned: isOwned,
                canAfford: canAfford,
                store: store,
                music: music,
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _storePlanetsSection(StoreController store, int sessionXpBalance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            children: [
              Text(
                '🪐  Planets',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Unlock worlds for focus',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          final unlockedIds = Set<String>.from(store.unlockedPlanets);
          return Column(
            children: PlanetCatalog.all.map((planet) {
              final isOwned = unlockedIds.contains(planet.id);
              final canAfford = sessionXpBalance >= planet.price;
              return _storePlanetCard(
                planet: planet,
                isOwned: isOwned,
                canAfford: canAfford,
                store: store,
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final store = Get.find<StoreController>();
    final music = Get.find<MusicService>();
    final box = Hive.box<dynamic>('zenverse_box');

    return StreamBuilder(
      stream: box.watch(key: 'profile'),
      builder: (context, snapshot) {
        final raw = box.get('profile');
        final profileJson = raw == null
            ? null
            : Map<String, dynamic>.from(raw as Map);
        final sessionXp = (profileJson?['xp_session'] as int?) ?? 0;
        final gameXp = (profileJson?['xp_games'] as int?) ?? 0;
        final isGuest = auth.isGuest || !auth.isLoggedIn;

        store.refreshXpFromProfile();

        Widget xpBalanceCard({
          required IconData icon,
          required String label,
          required int value,
          required Color accent,
          required String hint,
        }) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$value',
                    style: TextStyle(
                      color: accent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          children: [
            Row(
              children: [
                xpBalanceCard(
                  icon: Icons.bolt_rounded,
                  label: 'Session XP',
                  value: sessionXp,
                  accent: AppColors.primary,
                  hint: 'Earn from focus sessions',
                ),
                const SizedBox(width: 10),
                xpBalanceCard(
                  icon: Icons.videogame_asset_rounded,
                  label: 'Game XP',
                  value: gameXp,
                  accent: const Color(0xFFD4B6FF),
                  hint: 'Earn from mini-games',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'ZENVERSE',
                  style: GoogleFonts.orbitron(
                    color: AppColors.primary,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Currently Viewing',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saturn',
              style: GoogleFonts.inter(
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The ringed giant of peace and long-term focus.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Center(child: PlanetWidget(type: PlanetType.saturn, size: 260)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF243856)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Requires 15-day streak',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            primaryButton(
              'Unlock for 1,200 ⭐',
              () => Get.toNamed(AppRoutes.planetDetail),
            ),
            if (isGuest) ...[
              const SizedBox(height: 8),
              const Text(
                'Tip: Sign in to sync purchases and XP across devices.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Limited Edition',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  'RARE FINDS',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD4B6FF),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: zenCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.blur_on_rounded, color: Color(0xFFD4B6FF)),
                        SizedBox(height: 18),
                        Text(
                          'Black Hole',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'COMING SOON',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: zenCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFFD4B6FF)),
                        SizedBox(height: 18),
                        Text(
                          'Supernova',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '15,000',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Planet Galaxy',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  'RARE FINDS',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: zenCard(),
                    child: Column(
                      children: const [
                        PlanetWidget(
                          type: PlanetType.earth,
                          size: 90,
                          glow: false,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Earth',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'THE ORIGIN',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: zenCard(),
                    child: Column(
                      children: const [
                        PlanetWidget(
                          type: PlanetType.mars,
                          size: 90,
                          glow: false,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Mars',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '500',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _storeMusicSection(store, music, gameXp),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: zenCard(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Celestial Collector',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You have unlocked 1 of 12 available celestial bodies.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 1 / 12,
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor: const Color(
                        0xFF243856,
                      ).withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            _storePlanetsSection(store, sessionXp),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class PlanetDetailScreen extends StatelessWidget {
  const PlanetDetailScreen({super.key});
  @override
  Widget build(BuildContext context) => SpaceScaffold(
    appBar: AppBar(title: const Text('Planet Detail')),
    body: Column(
      children: [
        const PlanetWidget(type: PlanetType.saturn, size: 180),
        Text('Saturn Prime', style: GoogleFonts.orbitron(fontSize: 28)),
        const SizedBox(height: 8),
        const Text('Price: 1200 Game XP'),
        const SizedBox(height: 14),
        primaryButton(
          'Buy',
          () => Get.snackbar('Store', 'Purchased with game XP'),
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final countdown = true.obs;
  final notifications = true.obs;
  final dayMode = false.obs;

  @override
  void initState() {
    super.initState();
    Get.find<AuthController>().loadUserData(refreshRemote: true);
  }

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return ListView(
      children: [
        Text(
          'ZENVERSE',
          style: GoogleFonts.orbitron(
            color: AppColors.primary,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 50,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Customize your meditation journey and visual experience within the Zenverse sanctuary.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: zenCard(),
          child: Row(
            children: [
              Obx(() {
                final photoUrl = auth.userPhotoUrl.value;
                final name = auth.userName.value;
                final initials = _initialsFromName(name);
                return CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.purple.withValues(alpha: 0.3),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                );
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  final name = auth.userName.value;
                  final email = auth.userEmail.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'User' : name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        email.isNotEmpty ? email : 'Zen Pro Member',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      if (auth.userCode.value.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Friend code: ${auth.userCode.value}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.editProfile),
                child: const Text('MANAGE'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: zenCard(),
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
            title: const Text('Timer Duration'),
            subtitle: const Text(
              'Default session length',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Obx(
              () => Text(
                countdown.value ? '25m' : 'Count-up',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            onTap: () => countdown.value = !countdown.value,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: zenCard(),
          child: const ListTile(
            leading: Icon(Icons.graphic_eq_outlined, color: Color(0xFFD4B6FF)),
            title: Text('Sound Settings'),
            subtitle: Text(
              'Background atmosphere',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Text(
              'Ambient Space',
              style: TextStyle(
                color: Color(0xFFD4B6FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: zenCard(),
          child: Obx(
            () => SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text(
                'Daily reminders & alerts',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              value: notifications.value,
              onChanged: (v) => notifications.value = v,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: zenCard(),
          child: Obx(
            () => SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(
                dayMode.value ? 'Enabled' : 'Disabled',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              value: dayMode.value,
              onChanged: (v) => dayMode.value = v,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: Get.find<AuthController>().logout,
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _userCodeController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfileFields();
  }

  Future<void> _loadProfileFields() async {
    final auth = Get.find<AuthController>();
    await auth.loadUserData(refreshRemote: true);
    if (!mounted) return;
    setState(() {
      _fullNameController.text = auth.userName.value;
      _usernameController.text = auth.userUsername.value;
      _emailController.text = auth.userEmail.value;
      _userCodeController.text = auth.userCode.value;
      _loaded = true;
    });
  }

  Future<void> _saveChanges() async {
    final auth = Get.find<AuthController>();
    final ok = await auth.updateProfile(
      displayName: _fullNameController.text,
      username: _usernameController.text,
    );
    if (ok && mounted) {
      Get.back();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _userCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return SpaceScaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Obx(() {
                  final photoUrl = auth.userPhotoUrl.value;
                  final initials = auth.userName.value.trim().isNotEmpty
                      ? auth.userName.value
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((p) => p.isNotEmpty)
                            .map((p) => p[0])
                            .take(2)
                            .join()
                            .toUpperCase()
                      : 'U';
                  return Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.purple.withValues(alpha: 0.3),
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 16),
                formInput('Full name', controller: _fullNameController),
                const SizedBox(height: 10),
                formInput('Username', controller: _usernameController),
                const SizedBox(height: 10),
                formInput(
                  'Email (read-only)',
                  controller: _emailController,
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                formInput(
                  'User code (read-only)',
                  controller: _userCodeController,
                  readOnly: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your user code so friends can add you. Email and user code cannot be changed here.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => primaryButton(
                    auth.savingProfile.value ? 'Saving...' : 'Save Changes',
                    auth.savingProfile.value ? () {} : _saveChanges,
                  ),
                ),
              ],
            ),
    );
  }
}

Widget _authScaffold(String title, List<Widget> children) => SpaceScaffold(
  appBar: AppBar(title: Text(title)),
  body: ListView(children: children),
);

Widget _otpBox() => Container(
  width: 42,
  height: 52,
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0xFF2A4430)),
  ),
);

Widget _dayDot(String label) => Container(
  margin: const EdgeInsets.symmetric(horizontal: 4),
  width: 30,
  height: 30,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: AppColors.secondary.withValues(alpha: 0.2),
    border: Border.all(color: AppColors.secondary),
  ),
  child: Center(child: Text(label)),
);

Widget _listPicker(String title, List<String> items, String buttonLabel) {
  final selected = <String>{}.obs;
  return SpaceScaffold(
    appBar: AppBar(title: Text(title)),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            children: items
                .map(
                  (e) => Obx(
                    () => CheckboxListTile(
                      value: selected.contains(e),
                      onChanged: (v) =>
                          v == true ? selected.add(e) : selected.remove(e),
                      title: Text(e),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        primaryButton(buttonLabel, Get.back),
      ],
    ),
  );
}

Widget _gameCard(String title, VoidCallback onTap) => InkWell(
  onTap: onTap,
  child: Container(
    decoration: zenCard(),
    child: Center(
      child: Text(title, style: GoogleFonts.orbitron(fontSize: 22)),
    ),
  ),
);
