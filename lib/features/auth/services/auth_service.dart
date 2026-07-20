import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/mock_merchant_data_service.dart';
import '../../../core/services/hive_service.dart';
import '../models/user_role.dart';

class AuthService {
  static const String _userIdKey = 'qistiraha_user_id';
  static const String _roleKey = 'qistiraha_role';

  /// Checks if there is a saved active user session.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userIdKey);
  }

  /// The role the current session logged in as. Defaults to consumer.
  static Future<UserRole> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return UserRole.fromRaw(prefs.getString(_roleKey));
  }

  /// Signs the user out by wiping the session ID.
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }

  /// Authenticates with Email & Password.
  /// If kDebugMode is true, this automatically bypasses real auth.
  static Future<bool> signInWithEmail(
    String email,
    String password, {
    required UserRole role,
  }) async {
    if (kDebugMode) {
      // DEVELOPMENT BYPASS
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, 'dev_bypass_user_id');
      await prefs.setString(_roleKey, role.raw);

      await _seedMockDataFor(role);
      return true;
    } else {
      // TODO: Integrate Firebase/Supabase here for Beta
      // e.g., await supabase.auth.signInWithPassword(email: email, password: password);

      return false; // Not implemented for prod yet
    }
  }

  /// Creates a new account.
  /// If kDebugMode is true, this automatically bypasses real auth.
  static Future<bool> signUpWithEmail(
    String name,
    String email,
    String password, {
    required UserRole role,
  }) async {
    if (kDebugMode) {
      // DEVELOPMENT BYPASS
      final prefs = await SharedPreferences.getInstance();
      var uuid = const Uuid().v4();
      await prefs.setString(_userIdKey, uuid);
      await prefs.setString(_roleKey, role.raw);

      await _seedMockDataFor(role, name: name);
      return true;
    } else {
      // TODO: Integrate Firebase/Supabase here for Beta
      // e.g., await supabase.auth.signUp(email: email, password: password);

      return false; // Not implemented for prod yet
    }
  }

  static Future<void> _seedMockDataFor(UserRole role, {String? name}) async {
    if (role == UserRole.merchant) {
      final userBox = HiveService.getUserBox();
      // Seed the base consumer identity first if needed — MockDataService
      // clears the installment box, so it must run *before* the merchant
      // installments are added below, never after.
      if (userBox.isEmpty) {
        await MockDataService.populateMockData();
      }
      final business = await MockMerchantDataService.populateMockData();
      final user = userBox.values.first;
      user.role = UserRole.merchant.raw;
      user.businessId = business.id;
      if (name != null && name.isNotEmpty) user.name = name;
      await user.save();
    } else {
      await MockDataService.populateMockData();
      final userBox = HiveService.getUserBox();
      final user = userBox.values.first;
      user.role = UserRole.consumer.raw;
      if (name != null && name.isNotEmpty) user.name = name;
      await user.save();
    }
  }
}
