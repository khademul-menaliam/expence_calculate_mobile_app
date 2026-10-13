import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class UserProfile {
  final bool isLoggedIn;
  final String userEmail;
  final String userPassword;
  final bool hasCompletedOnboarding;
  final double monthlySalary;
  final double dailyExpenseTarget;
  final double monthlyExpenseTarget;
  final double monthlySavingsTarget;
  final bool notificationsEnabled;

  const UserProfile({
    required this.isLoggedIn,
    required this.userEmail,
    required this.userPassword,
    required this.hasCompletedOnboarding,
    required this.monthlySalary,
    required this.dailyExpenseTarget,
    required this.monthlyExpenseTarget,
    required this.monthlySavingsTarget,
    required this.notificationsEnabled,
  });

  UserProfile copyWith({
    bool? isLoggedIn,
    String? userEmail,
    String? userPassword,
    bool? hasCompletedOnboarding,
    double? monthlySalary,
    double? dailyExpenseTarget,
    double? monthlyExpenseTarget,
    double? monthlySavingsTarget,
    bool? notificationsEnabled,
  }) {
    return UserProfile(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userEmail: userEmail ?? this.userEmail,
      userPassword: userPassword ?? this.userPassword,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      dailyExpenseTarget: dailyExpenseTarget ?? this.dailyExpenseTarget,
      monthlyExpenseTarget: monthlyExpenseTarget ?? this.monthlyExpenseTarget,
      monthlySavingsTarget: monthlySavingsTarget ?? this.monthlySavingsTarget,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class ProfileRepository {
  static const _keyIsLoggedIn = 'auth_is_logged_in';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserPassword = 'auth_user_password';
  static const _keyCompletedOnboarding = 'profile_completed_onboarding';
  static const _keyMonthlySalary = 'profile_monthly_salary';
  static const _keyDailyTarget = 'profile_daily_target';
  static const _keyMonthlyTarget = 'profile_monthly_target';
  static const _keySavingsTarget = 'profile_savings_target';
  static const _keyNotificationsEnabled = 'profile_notifications_enabled';

  final SharedPreferences prefs;

  ProfileRepository(this.prefs);

  UserProfile getProfile() {
    return UserProfile(
      isLoggedIn: prefs.getBool(_keyIsLoggedIn) ?? false,
      userEmail: prefs.getString(_keyUserEmail) ?? '',
      userPassword: prefs.getString(_keyUserPassword) ?? '',
      hasCompletedOnboarding: prefs.getBool(_keyCompletedOnboarding) ?? false,
      monthlySalary: prefs.getDouble(_keyMonthlySalary) ?? 20000.0,
      dailyExpenseTarget: prefs.getDouble(_keyDailyTarget) ?? 500.0,
      monthlyExpenseTarget: prefs.getDouble(_keyMonthlyTarget) ?? 15000.0,
      monthlySavingsTarget: prefs.getDouble(_keySavingsTarget) ?? 5000.0,
      notificationsEnabled: prefs.getBool(_keyNotificationsEnabled) ?? true,
    );
  }

  bool _isNetworkError(dynamic error) {
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('clientexception') ||
        str.contains('connection refused') ||
        str.contains('connection timed out') ||
        str.contains('handshakeexception');
  }

  Future<void> registerUser(String email, String password) async {
    final supabase = SupabaseService();
    if (supabase.isConfigured && email != 'local_user@offline') {
      try {
        await supabase.signUp(email: email, password: password);
      } catch (e) {
        if (_isNetworkError(e)) {
          // Graceful fallback: when device is offline, allow local account creation
        } else {
          // Re-throw AuthException / validation failures so user sees the message
          rethrow;
        }
      }
    }

    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPassword, password);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<bool> loginUser(String email, String password) async {
    final supabase = SupabaseService();
    if (supabase.isConfigured && email != 'local_user@offline') {
      try {
        final res = await supabase.signIn(email: email, password: password);
        if (res != null && res.user != null) {
          await prefs.setString(_keyUserEmail, email);
          await prefs.setString(_keyUserPassword, password);
          await prefs.setBool(_keyIsLoggedIn, true);
          return true;
        }
      } catch (e) {
        if (_isNetworkError(e)) {
          // Device is offline: check cached credentials for offline access
          final savedEmail = prefs.getString(_keyUserEmail) ?? '';
          final savedPassword = prefs.getString(_keyUserPassword) ?? '';
          if (savedEmail == email && savedPassword == password) {
            await prefs.setBool(_keyIsLoggedIn, true);
            return true;
          }
          throw Exception('Device is offline and no matching saved account was found.');
        }
        rethrow;
      }
    }

    final savedEmail = prefs.getString(_keyUserEmail) ?? '';
    final savedPassword = prefs.getString(_keyUserPassword) ?? '';

    // If no user exists yet in local mode, auto-register on first login attempt
    if (savedEmail.isEmpty) {
      await registerUser(email, password);
      return true;
    }

    if (savedEmail == email && savedPassword == password) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final supabase = SupabaseService();
    if (supabase.isConfigured) {
      try {
        await supabase.signOut();
      } catch (_) {}
    }
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  Future<void> saveOnboardingProfile({
    required double salary,
    required double dailyTarget,
    required double monthlyTarget,
    required double savingsTarget,
  }) async {
    await prefs.setDouble(_keyMonthlySalary, salary);
    await prefs.setDouble(_keyDailyTarget, dailyTarget);
    await prefs.setDouble(_keyMonthlyTarget, monthlyTarget);
    await prefs.setDouble(_keySavingsTarget, savingsTarget);
    await prefs.setBool(_keyCompletedOnboarding, true);
  }

  Future<void> updateTargets({
    double? salary,
    double? dailyTarget,
    double? monthlyTarget,
    double? savingsTarget,
    bool? notificationsEnabled,
  }) async {
    if (salary != null) await prefs.setDouble(_keyMonthlySalary, salary);
    if (dailyTarget != null) await prefs.setDouble(_keyDailyTarget, dailyTarget);
    if (monthlyTarget != null) await prefs.setDouble(_keyMonthlyTarget, monthlyTarget);
    if (savingsTarget != null) await prefs.setDouble(_keySavingsTarget, savingsTarget);
    if (notificationsEnabled != null) {
      await prefs.setBool(_keyNotificationsEnabled, notificationsEnabled);
    }
  }
}
