import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

import '../main_navigation_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  bool _navigated = false;

  void _proceed() {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      final profile = ref.read(profileNotifierProvider);
      Widget nextScreen;
      if (!profile.isLoggedIn) {
        nextScreen = const AuthScreen();
      } else if (!profile.hasCompletedOnboarding) {
        nextScreen = const OnboardingScreen();
      } else {
        nextScreen = const MainNavigationScreen();
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextScreen),
        (route) => false,
      );
    } catch (_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _proceed();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 72,
                color: AppTheme.primaryAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Expense & Goals',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Personal Finance',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
