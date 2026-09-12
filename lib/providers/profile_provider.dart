import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in ProviderScope');
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(sharedPreferencesProvider));
});

class ProfileNotifier extends StateNotifier<UserProfile> {
  final ProfileRepository repository;

  ProfileNotifier(this.repository) : super(repository.getProfile());

  Future<void> registerUser(String email, String password) async {
    await repository.registerUser(email, password);
    state = repository.getProfile();
  }

  Future<bool> loginUser(String email, String password) async {
    final success = await repository.loginUser(email, password);
    if (success) {
      state = repository.getProfile();
    }
    return success;
  }

  Future<void> logout() async {
    await repository.logout();
    state = repository.getProfile();
  }

  Future<void> saveOnboardingProfile({
    required double salary,
    required double dailyTarget,
    required double monthlyTarget,
    required double savingsTarget,
  }) async {
    await repository.saveOnboardingProfile(
      salary: salary,
      dailyTarget: dailyTarget,
      monthlyTarget: monthlyTarget,
      savingsTarget: savingsTarget,
    );
    state = repository.getProfile();
  }

  Future<void> updateTargets({
    double? salary,
    double? dailyTarget,
    double? monthlyTarget,
    double? savingsTarget,
    bool? notificationsEnabled,
  }) async {
    await repository.updateTargets(
      salary: salary,
      dailyTarget: dailyTarget,
      monthlyTarget: monthlyTarget,
      savingsTarget: savingsTarget,
      notificationsEnabled: notificationsEnabled,
    );
    state = repository.getProfile();
  }
}

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider));
});
