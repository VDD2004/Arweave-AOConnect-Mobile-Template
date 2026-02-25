import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSettingsException implements Exception {
  final String message;
  AppSettingsException(this.message);
  @override
  String toString() => 'AppSettingsException: $message';
}

class AutoLockSettings {
  final bool enabled;
  final Duration timeout;

  const AutoLockSettings({required this.enabled, required this.timeout});

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'timeoutSeconds': timeout.inSeconds,
  };

  static AutoLockSettings fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final timeoutSeconds = json['timeoutSeconds'];

    if (enabled is! bool || timeoutSeconds is! int) {
      throw AppSettingsException('Malformed AutoLockSettings payload.');
    }

    return AutoLockSettings(
      enabled: enabled,
      timeout: Duration(seconds: timeoutSeconds),
    );
  }
}

/// Minimal persistence helper for app-level, user-facing settings.
///
/// Intentionally tiny + easy to swap later (SharedPreferences, server, etc).
class AppSettingsStore {
  static const String autoLockKey = 'app_settings_auto_lock_v1';

  // Tracks the last time the vault was successfully unlocked (UTC ISO string).
  static const String lastUnlockAtKey = 'app_settings_last_unlock_at_v1';

  final FlutterSecureStorage _storage;

  AppSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Saves the auto-lock toggle and timeout.
  ///
  /// Scaffold-only: you can call this from `SettingsScreen` when you wire up state.
  Future<void> saveAutoLockSettings(AutoLockSettings settings) async {
    final payload = jsonEncode(settings.toJson());
    await _storage.write(key: autoLockKey, value: payload);
  }

  /// Loads the auto-lock settings.
  ///
  /// If nothing is stored yet, returns [fallback] when provided, otherwise null.
  Future<AutoLockSettings?> loadAutoLockSettings({
    AutoLockSettings? fallback,
  }) async {
    final raw = await _storage.read(key: autoLockKey);
    if (raw == null || raw.isEmpty) return fallback;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw AppSettingsException('Auto-lock settings are not a JSON object.');
      }
      return AutoLockSettings.fromJson(decoded);
    } catch (_) {
      // Keep load resilient; bad data shouldn't crash settings screen.
      return fallback;
    }
  }

  Future<void> deleteAutoLockSettings() async {
    await _storage.delete(key: autoLockKey);
  }

  Future<void> saveLastUnlockAt(DateTime when) async {
    await _storage.write(
      key: lastUnlockAtKey,
      value: when.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> loadLastUnlockAt() async {
    final raw = await _storage.read(key: lastUnlockAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> deleteLastUnlockAt() async {
    await _storage.delete(key: lastUnlockAtKey);
  }
}
