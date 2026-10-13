import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import '../main_navigation_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _botHoneypotController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  DateTime? _lastSubmitTime;
  int _consecutiveFailures = 0;
  DateTime? _cooldownUntil;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _botHoneypotController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 1. Bot Honeypot Protection: Ignore automated bot scripts
    if (_botHoneypotController.text.isNotEmpty) {
      return;
    }

    // 2. Spam Rate Limiting Cooldown
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      final remaining = _cooldownUntil!.difference(now).inSeconds;
      AppToast.show(context, 'Too many attempts. Please wait $remaining seconds.');
      return;
    }

    if (!_isLogin && _lastSubmitTime != null && now.difference(_lastSubmitTime!).inSeconds < 5) {
      AppToast.show(context, 'Please wait 5 seconds before submitting again.');
      return;
    }
    _lastSubmitTime = now;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final profileNotifier = ref.read(profileNotifierProvider.notifier);

    try {
      if (_isLogin) {
        final success = await profileNotifier.loginUser(email, password);
        if (!mounted) return;
        if (success) {
          _consecutiveFailures = 0;
          _cooldownUntil = null;
          AppToast.show(context, 'Login successful!');
          _navigateNext();
        } else {
          _registerFailure();
          AppToast.show(context, 'Invalid credentials. Please check your password.');
        }
      } else {
        await profileNotifier.registerUser(email, password);
        if (!mounted) return;
        _consecutiveFailures = 0;
        _cooldownUntil = null;
        AppToast.show(context, 'Account created successfully!');
        _navigateNext();
      }
    } on AuthException catch (e) {
      _registerFailure();
      if (mounted) {
        if (e.message.toLowerCase().contains('email not confirmed')) {
          _showEmailNotConfirmedDialog(email);
        } else {
          AppToast.show(context, e.message);
        }
      }
    } catch (e) {
      _registerFailure();
      if (mounted) {
        AppToast.show(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEmailNotConfirmedDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: AppTheme.expenseColor),
            SizedBox(width: 8),
            Text('Email Not Confirmed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supabase requires email confirmation before signing in.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'A verification link was sent to:\n$email\n\nPlease check your email inbox and click the confirmation link to activate your account.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Tip: In your Supabase Dashboard ➔ Authentication ➔ Providers ➔ Email, you can toggle "Confirm email" OFF if you want instant logins without confirmation links.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await SupabaseService().client?.auth.resend(
                      type: OtpType.signup,
                      email: email,
                    );
                if (mounted) {
                  AppToast.show(context, 'Confirmation email resent to $email');
                }
              } catch (e) {
                if (mounted) {
                  AppToast.show(context, 'Resend failed: $e');
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Resend Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _registerFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      _cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
      _consecutiveFailures = 0;
    }
  }

  Future<void> _continueOffline() async {
    setState(() => _isLoading = true);
    try {
      final profileNotifier = ref.read(profileNotifierProvider.notifier);
      await profileNotifier.registerUser('local_user@offline', '1234');
      if (!mounted) return;
      _navigateNext();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Offline login failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateNext() {
    // Automatically backup / sync existing local data to the newly logged in cloud account
    try {
      final db = ref.read(databaseProvider);
      final profile = ref.read(profileNotifierProvider);
      if (profile.userEmail != 'local_user@offline' && profile.userEmail.isNotEmpty) {
        SupabaseService().syncLocalDataToCloud(db: db, profile: profile).catchError(
              (_) => const SyncResult(success: false, message: ''),
            );
      }
    } catch (_) {}

    final profile = ref.read(profileNotifierProvider);
    final nextScreen = !profile.hasCompletedOnboarding
        ? const OnboardingScreen()
        : const MainNavigationScreen();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => nextScreen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 64,
                    color: AppTheme.primaryAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to access and sync your expenses'
                        : 'Sign up to backup your budget & sync data',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  // Segmented control toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLogin = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isLogin ? AppTheme.primaryAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Login',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isLogin ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLogin = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isLogin ? AppTheme.primaryAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Register',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isLogin ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Honeypot field for anti-spam bot blocking (invisible to human users)
                  Visibility(
                    visible: false,
                    maintainState: true,
                    child: TextFormField(
                      controller: _botHoneypotController,
                      decoration: const InputDecoration(labelText: 'Leave empty'),
                    ),
                  ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email address';
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Min. 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isLogin ? 'LOG IN' : 'CREATE ACCOUNT',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueOffline,
                    icon: const Icon(Icons.flash_on_outlined, size: 18),
                    label: const Text('CONTINUE OFFLINE (GUEST MODE)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
