import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> registerUser(String email, String password) async {
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPassword, password);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<bool> loginUser(String email, String password) async {
    final savedEmail = prefs.getString(_keyUserEmail) ?? '';
    final savedPassword = prefs.getString(_keyUserPassword) ?? '';

    // If no user exists yet, auto-register on first login attempt or validate
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
