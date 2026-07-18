import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/mock_data_service.dart';

class AuthService {
  static const String _userIdKey = 'qistiraha_user_id';

  /// Checks if there is a saved active user session.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userIdKey);
  }

  /// Signs the user out by wiping the session ID.
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }

  /// Authenticates with Email & Password.
  /// If kDebugMode is true, this automatically bypasses real auth.
  static Future<bool> signInWithEmail(String email, String password) async {
    if (kDebugMode) {
      // DEVELOPMENT BYPASS
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, 'dev_bypass_user_id');
      
      // Ensure mock data exists so the app doesn't crash on empty DB
      await MockDataService.populateMockData();
      return true;
    } else {
      // TODO: Integrate Firebase/Supabase here for Beta
      // e.g., await supabase.auth.signInWithPassword(email: email, password: password);
      
      return false; // Not implemented for prod yet
    }
  }

  /// Creates a new account.
  /// If kDebugMode is true, this automatically bypasses real auth.
  static Future<bool> signUpWithEmail(String name, String email, String password) async {
    if (kDebugMode) {
      // DEVELOPMENT BYPASS
      final prefs = await SharedPreferences.getInstance();
      var uuid = const Uuid().v4();
      await prefs.setString(_userIdKey, uuid);
      
      // Ensure mock data exists
      await MockDataService.populateMockData();
      return true;
    } else {
      // TODO: Integrate Firebase/Supabase here for Beta
      // e.g., await supabase.auth.signUp(email: email, password: password);
      
      return false; // Not implemented for prod yet
    }
  }
}
