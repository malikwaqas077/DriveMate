import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist and retrieve the preferred role (owner/instructor)
/// for users who have both roles.
class RolePreferenceService {
  RolePreferenceService._();

  static final RolePreferenceService instance = RolePreferenceService._();

  static const _keyPreferredRole = 'preferred_role';

  /// Save the preferred role for a user
  Future<void> savePreferredRole(String userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyPreferredRole}_$userId', role);
  }

  /// Get the preferred role for a user
  Future<String?> getPreferredRole(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_keyPreferredRole}_$userId');
  }

  /// Clear the preferred role for a user (e.g., on logout)
  Future<void> clearPreferredRole(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_keyPreferredRole}_$userId');
  }
}
