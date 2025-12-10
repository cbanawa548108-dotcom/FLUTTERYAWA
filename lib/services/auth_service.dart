import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final supabase = Supabase.instance.client;

  /// Login method
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed - no user returned');
      }

      // Safely get role from users table
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', response.user!.id)
          .maybeSingle();

      final role = userData != null ? userData['role'] ?? 'user' : 'user';

      return {'user': response.user, 'role': role};
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Logout method
  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  /// Get current user ID
  static String? getCurrentUserId() {
    return supabase.auth.currentUser?.id;
  }

  /// Check if user is logged in
  static bool isLoggedIn() {
    return supabase.auth.currentUser != null;
  }

  /// Register method
  static Future<void> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      // Sign up with Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) throw Exception('Registration failed');

      // Insert user into users table
      await supabase.from('users').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'name': fullName,
        'role': 'user',
      });
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }
}
