import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase Configuration
  // Paste your Supabase project URL and anon public key here:
  static const String supabaseUrl = 'https://ulrfugznftqrdnmuqtdr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVscmZ1Z3puZnRxcmRubXVxdGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4Nzc3MDMsImV4cCI6MjEwNzQ1MzcwM30.obkrllgSWWLd9cYY1Z3KwhZ8WDHOiAaMSTvZUpWt4mM';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE');

  SupabaseClient? get client {
    if (_initialized) {
      return Supabase.instance.client;
    }
    try {
      final c = Supabase.instance.client;
      _initialized = true;
      return c;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => client?.auth.currentUser;

  Future<void> init() async {
    if (_initialized) return;

    if (!isConfigured) {
      debugPrint('[SupabaseService] Not configured yet. Running in 100% offline mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('[SupabaseService] Supabase successfully initialized.');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization note: $e');
      try {
        Supabase.instance.client;
        _initialized = true;
      } catch (_) {}
    }
  }

  // Cloud Auth Helpers
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    if (!isConfigured || client == null) return null;
    return await client!.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured || client == null) return null;
    return await client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (client != null) {
      await client!.auth.signOut();
    }
  }
}
