import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenverse/app/repositories/zen_repository.dart';
import 'package:zenverse/app/routes/app_routes.dart';
import 'package:zenverse/app/utils/user_code_util.dart';

class AuthController extends GetxController {
  AuthController(this._repository, this._box);

  /// Web OAuth client ID used as [GoogleSignIn.serverClientId] on native mobile
  /// so Google returns an ID token for Supabase.
  static const String _googleWebClientId =
      '995836429357-kujs1b9ddnnala9kkcp1ii7ipj9oe9b7.apps.googleusercontent.com';

  static const List<String> _googleScopes = ['email', 'profile'];

  /// [google_sign_in_web] rejects a non-null [serverClientId] (debug assert).
  /// Only pass it on Android / iOS so Web (or WebView-hosted Flutter web) cannot hit that path.
  static String? get _googleServerClientIdNative {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => _googleWebClientId,
      _ => null,
    };
  }

  final ZenRepository _repository;
  final Box<dynamic> _box;
  final loading = false.obs;
  final googleLoading = false.obs;
  final userName = ''.obs;
  final userEmail = ''.obs;
  final userPhotoUrl = ''.obs;
  final userCode = ''.obs;
  final userUsername = ''.obs;
  final savingProfile = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  /// Loads display name, email, and photo from local cache, Supabase session, and Google Sign-In.
  Future<void> loadUserData({bool refreshRemote = false}) async {
    if (isGuest) {
      userName.value = 'Guest';
      userEmail.value = '';
      userPhotoUrl.value = '';
      userCode.value = '';
      userUsername.value = '';
      return;
    }

    final uid = _currentUserId;
    if (uid != null && uid.isNotEmpty && !isGuest) {
      try {
        final email = Supabase.instance.client.auth.currentUser?.email ?? '';
        await _repository.syncCurrentUserProfileToRemote(
          userId: uid,
          fallbackEmail: email,
        );
      } catch (e) {
        debugPrint('[Auth] syncCurrentUserProfileToRemote: $e');
      }
    }

    if (refreshRemote && uid != null && uid.isNotEmpty) {
      try {
        final email = Supabase.instance.client.auth.currentUser?.email ?? '';
        await _repository.refreshLocalProfileFromRemote(
          userId: uid,
          fallbackEmail: email,
        );
      } catch (e) {
        debugPrint('[Auth] loadUserData refreshRemote: $e');
      }
    }

    var name = '';
    var email = '';
    var photo = '';
    var code = '';
    var username = '';

    final localRaw = _box.get('profile');
    if (localRaw != null) {
      final local = Map<String, dynamic>.from(localRaw as Map);
      name = (local['display_name'] as String?)?.trim() ?? '';
      email = (local['email'] as String?)?.trim() ?? '';
      code = (local['user_code'] as String?)?.trim() ?? '';
      final avatar = (local['avatar_url'] as String?)?.trim() ?? '';
      if (avatar.startsWith('http')) {
        photo = avatar;
      }
    }

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser != null) {
      email = supabaseUser.email?.trim() ?? email;
      final meta = supabaseUser.userMetadata;
      if (meta != null) {
        final metaName = (meta['full_name'] as String?) ??
            (meta['name'] as String?) ??
            (meta['display_name'] as String?);
        if (metaName != null && metaName.trim().isNotEmpty) {
          name = metaName.trim();
        }
        final metaPhoto = (meta['avatar_url'] as String?) ?? (meta['picture'] as String?);
        if (metaPhoto != null && metaPhoto.trim().startsWith('http')) {
          photo = metaPhoto.trim();
        }
        final metaUsername = meta['username'] as String?;
        if (metaUsername != null && metaUsername.trim().isNotEmpty) {
          username = metaUsername.trim();
        }
      }
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          if (googleUser.displayName?.trim().isNotEmpty == true) {
            name = googleUser.displayName!.trim();
          }
          if (googleUser.photoUrl != null && googleUser.photoUrl!.trim().isNotEmpty) {
            photo = googleUser.photoUrl!.trim();
          }
          email = googleUser.email.trim().isNotEmpty ? googleUser.email.trim() : email;
        }
      } catch (e) {
        debugPrint('[Auth] loadUserData Google silent sign-in: $e');
      }
    }

    // Prefer locally saved profile name (onboarding / Supabase sync) over OAuth metadata.
    if (localRaw != null) {
      final localMap = Map<String, dynamic>.from(localRaw as Map);
      final localName = (localMap['display_name'] as String?)?.trim();
      if (localName != null && localName.isNotEmpty) {
        name = localName;
      }
      final localCode = (localMap['user_code'] as String?)?.trim();
      if (localCode != null && localCode.isNotEmpty) {
        code = localCode;
      }
    }

    if (username.isEmpty && email.isNotEmpty) {
      username = _displayNameFromEmail(email);
    }

    if (name.isEmpty && email.isNotEmpty) {
      name = _displayNameFromEmail(email);
    }
    if (name.isEmpty) {
      name = 'User';
    }

    userName.value = name;
    userEmail.value = email;
    userPhotoUrl.value = photo;
    userCode.value = normalizeUserCode(code);
    userUsername.value = username;
  }

  Future<bool> updateProfile({
    required String displayName,
    required String username,
  }) async {
    final uid = _currentUserId;
    if (uid == null || isGuest) {
      Get.snackbar('Profile', 'Sign in to update your profile.');
      return false;
    }
    final trimmedName = displayName.trim();
    final trimmedUsername = username.trim();
    if (trimmedName.length < 2) {
      Get.snackbar('Profile', 'Full name must be at least 2 characters.');
      return false;
    }
    if (trimmedUsername.length < 2) {
      Get.snackbar('Profile', 'Username must be at least 2 characters.');
      return false;
    }

    savingProfile.value = true;
    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? userEmail.value;
      await _repository.updateEditableProfile(
        userId: uid,
        displayName: trimmedName,
        email: email,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': trimmedName,
            'username': trimmedUsername,
          },
        ),
      );
      await loadUserData(refreshRemote: true);
      Get.snackbar('Profile updated', 'Your changes were saved.');
      return true;
    } on AuthException catch (e) {
      Get.snackbar('Profile update failed', e.message);
      return false;
    } catch (e) {
      Get.snackbar('Profile update failed', e.toString());
      return false;
    } finally {
      savingProfile.value = false;
    }
  }

  void _clearUserData() {
    userName.value = '';
    userEmail.value = '';
    userPhotoUrl.value = '';
    userCode.value = '';
    userUsername.value = '';
  }

  /// Native (Android/iOS): Web OAuth client ID as [serverClientId] so Google returns an ID token
  /// for Supabase. Do not set [clientId] — that targets Web/meta-tag flows.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientIdNative,
    scopes: _googleScopes,
  );

  bool get isFirstLaunch => _box.get('is_first_launch', defaultValue: true) as bool;
  bool get isLoggedIn => _box.get('is_logged_in', defaultValue: false) as bool;
  bool get isGuest => _box.get('guest_mode', defaultValue: false) as bool;

  String? get _currentUserId => _box.get('user_id') as String?;

  /// Per-user Hive flag stored as `onboarding_complete_<supabase_uid>`.
  bool get needsProfileOnboarding {
    if (isGuest) return false;
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return false;
    return _box.get(ZenRepository.onboardingHiveKeyForUser(uid)) != true;
  }

  Future<void> markProfileOnboardingComplete(String userId) async {
    await _box.put(ZenRepository.onboardingHiveKeyForUser(userId), true);
  }

  /// After email/password login, Google login, or email registration (authenticated users only).
  void navigateAuthenticatedHome() {
    final next = needsProfileOnboarding ? AppRoutes.profileOnboarding : AppRoutes.shell;
    Get.offAllNamed(next);
  }

  /// Friendly email-local-part fallback for onboarding / username hints.
  static String? displayNameGuessFromEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim();
    final local = trimmed.contains('@') ? trimmed.split('@').first.trim() : trimmed;
    if (local.length >= 2) {
      return local.length > 60 ? local.substring(0, 60) : local;
    }
    if (local.length == 1) return '$local$local';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> completeOnboarding() async {
    await _box.put('is_first_launch', false);
  }

  Future<void> continueAsGuest() async {
    await _box.put('guest_mode', true);
    await _box.put('is_logged_in', false);
    await _box.delete('user_id');
    await loadUserData();
    Get.offAllNamed(AppRoutes.shell);
  }

  /// Dev / anonymous shortcut (unchanged behavior).
  Future<void> loginDemo() async {
    loading.value = true;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      loading.value = false;
      Get.snackbar('Auth Error', 'Unable to authenticate user.');
      return;
    }

    if (_box.get('user_id') == null) {
      final demoEmail = client.auth.currentUser?.email ?? 'anonymous@zenverse.local';
      await _repository.createUser(
        userId: userId,
        name: _displayNameFromEmail(demoEmail),
        email: demoEmail,
      );
    } else {
      await _box.put('is_logged_in', true);
    }
    await _box.put('guest_mode', false);
    loading.value = false;
    await markProfileOnboardingComplete(userId);
    await loadUserData();
    navigateAuthenticatedHome();
  }

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    loading.value = true;
    try {
      final trimmed = email.trim();
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: trimmed,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        Get.snackbar('Login failed', 'No user returned from Supabase.');
        return;
      }

      final resolvedEmail = user.email ?? trimmed;
      await _repository.createOrUpdateProfileOnLogin(
        userId: user.id,
        displayName: _displayNameFromEmail(resolvedEmail),
        email: resolvedEmail,
      );
      await _box.put('guest_mode', false);
      await _box.put('user_id', user.id);
      await _box.put('is_logged_in', true);
      await loadUserData();
      navigateAuthenticatedHome();
    } on AuthException catch (e) {
      debugPrint('[Auth] signInWithPassword AuthException: ${e.message}');
      Get.snackbar('Login failed', e.message);
    } catch (e, st) {
      debugPrint('[Auth] signInWithPassword: $e\n$st');
      Get.snackbar('Login failed', e.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (password != confirmPassword) {
      Get.snackbar('Sign up', 'Passwords do not match.');
      return;
    }
    loading.value = true;
    try {
      final trimmed = email.trim();
      final res = await Supabase.instance.client.auth.signUp(
        email: trimmed,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        Get.snackbar(
          'Sign up failed',
          'No account session was created. Turn off Confirm email under Supabase Dashboard → Authentication → Providers → Email during development — see supabase/development-notes.txt.',
        );
        return;
      }

      await _repository.createProfileAfterEmailSignUp(
        userId: user.id,
        email: user.email ?? trimmed,
      );
      await _box.put('guest_mode', false);
      await _box.put('user_id', user.id);
      await _box.put('is_logged_in', true);
      await loadUserData();
      navigateAuthenticatedHome();
    } on AuthException catch (e) {
      debugPrint('[Auth] signUp AuthException: ${e.message}');
      Get.snackbar('Sign up failed', _friendlySignupError(e.message));
    } catch (e, st) {
      debugPrint('[Auth] signUp: $e\n$st');
      Get.snackbar('Sign up failed', e.toString());
    } finally {
      loading.value = false;
    }
  }

  String _displayNameFromEmail(String email) =>
      AuthController.displayNameGuessFromEmail(email) ?? 'ZenUser';

  String _friendlySignupError(String message) {
    final raw = message.trim();
    final lower = raw.toLowerCase();
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('429') ||
        lower.contains('over_email_send_rate')) {
      return 'Too many emails or signup attempts. Wait several minutes.\nDev: disable Confirm email under Supabase → Auth → Providers → Email (supabase/development-notes.txt).';
    }
    if (lower.contains('already registered') || lower.contains('user already')) {
      return 'That email already has an account. Try signing in instead.';
    }
    return raw.isEmpty ? 'Sign-up failed.' : raw;
  }

  Future<void> loginWithGoogle() async {
    googleLoading.value = true;
    try {
      if (kIsWeb) {
        Get.snackbar(
          'Google Sign-In',
          'Google Sign-In runs in the native Android/iOS build. Avoid running this flow on Chrome/Web.',
        );
        return;
      }
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        Get.snackbar('Google Sign-In', 'Unsupported on this platform.');
        return;
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        debugPrint('[Auth] Google sign-in failed: missing ID token from Google.');
        Get.snackbar('Google Sign-In', 'Missing ID token from Google.');
        googleLoading.value = false;
        return;
      }

      final supabase = Supabase.instance.client;
      final authRes = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final user = authRes.user;
      if (user == null) {
        Get.snackbar('Google Sign-In', 'Supabase login failed.');
        googleLoading.value = false;
        return;
      }

      final fallbackName = googleUser.displayName?.trim().isNotEmpty == true
          ? googleUser.displayName!.trim()
          : 'Zen Explorer';
      final fallbackEmail = user.email ?? googleUser.email;
      await _repository.createOrUpdateProfileOnLogin(
        userId: user.id,
        displayName: fallbackName,
        email: fallbackEmail,
      );
      await _box.put('guest_mode', false);
      await _box.put('user_id', user.id);
      await _box.put('is_logged_in', true);
      await loadUserData();
      navigateAuthenticatedHome();
    } on AuthException catch (e) {
      final details = 'Supabase AuthException: ${e.message}';
      debugPrint('[Auth] $details');
      Get.snackbar('Google Sign-In Failed', '$details\n${_googleSignInTroubleshootingHint(details)}');
    } on PlatformException catch (e) {
      final details = 'Google Sign-In (${e.code}): ${e.message ?? e.details ?? 'Unknown error'}';
      debugPrint('[Auth] $details');
      Get.snackbar('Google Sign-In Failed', '$details\n${_googleSignInTroubleshootingHint(details)}');
    } catch (e, stackTrace) {
      final details = 'Unexpected Google sign-in error: $e';
      debugPrint('[Auth] $details');
      debugPrint('[Auth] StackTrace: $stackTrace');
      Get.snackbar('Google Sign-In Failed', '$details\n${_googleSignInTroubleshootingHint(details)}');
    } finally {
      googleLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _box.put('is_logged_in', false);
    await _box.put('guest_mode', false);
    await _box.delete('user_id');
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _clearUserData();
    Get.offAllNamed(AppRoutes.login);
  }

  String _googleSignInTroubleshootingHint(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('network')) {
      return 'Hint: check internet connection and retry.';
    }
    if (lower.contains('invalid_audience') || lower.contains('audience')) {
      return 'Hint: Web Client ID in Google Cloud / Supabase Auth Google provider must match this app.';
    }
    if (lower.contains('10:') || lower.contains('developer_error') || lower.contains('12500')) {
      return 'Hint: SHA-1/SHA-256 or Android package mismatch; verify com.zenverse.app and keystore fingerprints in Google Console.';
    }
    if (lower.contains('redirect') || lower.contains('callback') || lower.contains('unauthorized')) {
      return 'Hint: Supabase redirect URL may not match Google Console/Supabase Auth settings.';
    }
    return 'Hint: verify Web Client ID, SHA fingerprints, package name com.zenverse.app, and Supabase redirect URL.';
  }
}
