import 'package:get/get.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/views/profile_onboarding_screen.dart';
import 'package:zenverse/app/views/focus/active_session_screen.dart';
import 'package:zenverse/app/views/focus/journey_setup_screen.dart';
import 'package:zenverse/app/views/screens.dart';

class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.permissionOnboarding, page: () => const PermissionOnboardingScreen()),
    GetPage(name: AppRoutes.onboarding1, page: () => const OnboardingCoreScreen()),
    GetPage(name: AppRoutes.onboarding2, page: () => const OnboardingWelcomeScreen()),
    GetPage(name: AppRoutes.profileOnboarding, page: () => const ProfileOnboardingScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.register, page: () => const RegisterScreen()),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordScreen()),
    GetPage(name: AppRoutes.otpVerification, page: () => const OtpVerificationScreen()),
    GetPage(name: AppRoutes.resetPassword, page: () => const ResetPasswordScreen()),
    GetPage(name: AppRoutes.shell, page: () => const AppShellScreen()),
    GetPage(name: AppRoutes.streak, page: () => const StreakScreen()),
    GetPage(name: AppRoutes.journeySetup, page: () => const JourneySetupScreen()),
    GetPage(name: AppRoutes.appPermissionPicker, page: () => const AppPermissionPickerScreen()),
    GetPage(name: AppRoutes.galaxyPicker, page: () => const GalaxyPickerScreen()),
    GetPage(name: AppRoutes.sessionFriendsPicker, page: () => const SessionFriendsPickerScreen()),
    GetPage(name: AppRoutes.activeSession, page: () => const ActiveSessionScreen()),
    GetPage(name: AppRoutes.sessionComplete, page: () => const SessionCompleteScreen()),
    GetPage(name: AppRoutes.shareVictory, page: () => const ShareVictoryScreen()),
    GetPage(name: AppRoutes.scheduleReminder, page: () => const ScheduleReminderScreen()),
    GetPage(name: AppRoutes.friends, page: () => const FriendsScreen()),
    GetPage(name: AppRoutes.directChat, page: () => const DirectChatScreen()),
    GetPage(name: AppRoutes.planetGameSelection, page: () => const PlanetGameSelectionScreen()),
    GetPage(name: AppRoutes.game2048, page: () => const Game2048Screen()),
    GetPage(name: AppRoutes.orbitPuzzle, page: () => const OrbitPuzzleScreen()),
    GetPage(name: AppRoutes.planetDetail, page: () => const PlanetDetailScreen()),
    GetPage(name: AppRoutes.editProfile, page: () => const EditProfileScreen()),
  ];
}
