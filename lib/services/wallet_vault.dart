// wallet_vault.dart
//
// A small, versioned vault for encrypting/decrypting an Arweave JWK JSON string
// using PBKDF2-HMAC-SHA256 + AES-256-GCM, and storing it in flutter_secure_storage.
//
// Migration-friendly (payload has a version + params).
//
// Usage:
//   final vault = WalletVault();
//   final export = await vault.encryptJwkToExportString(
//     password: pw,
//     jwkJson: jwkJsonString,
//     address: address,
//   );
//   await vault.saveExportString(export);
//
//   final loaded = await vault.loadExportString();
//   final jwkJson = await vault.decryptJwkFromExportString(password: pw, exportString: loaded!);

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:arweave_aoconnect_mobile_template/services/app_settings_store.dart';
import 'package:arweave_aoconnect_mobile_template/services/arweavejs.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletVaultException implements Exception {
  final String message;
  WalletVaultException(this.message);
  @override
  String toString() => 'WalletVaultException: $message';
}

class WalletVault {
  // Change this key if you want multiple vault slots.
  static const String defaultStorageKey = 'wallet_vault_export_v1';
  static const String defaultPasswordKey = 'wallet_vault_password_v1';
  static Map<String, dynamic>? jwk;
  static bool get isLoggedIn {
    return jwk != null;
  }

  final FlutterSecureStorage _storage;

  WalletVault({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        super();

  // --- Tunables (safe defaults for this template) ---
  //
  // PBKDF2 iterations:
  // - You can tune this per device class. 310k is a decent modern baseline.
  // - Keep it stored in the payload so you can raise it later.
  static const int _pbkdf2Iterations = 600_000;

  // 16 bytes salt is standard for PBKDF2
  static const int _saltLen = 16;

  // AES-GCM 12-byte nonce is recommended
  static const int _nonceLen = 12;

  // AES-256 key length
  static const int _keyLen = 32;

  // For separating this ciphertext from any other AES-GCM you might do later.
  // This is not secret; it is included as AAD so tampering breaks decryption.
  static const String _aadContext = 'ArweaveAOConnectTemplate/WalletVault/v1';

  // Payload version (for migrations later)
  static const int _version = 1;

  // --- Public API ---

  /// Attempts to log the user in using the stored encrypted jwk & password
  ///   @returns - true if login is successful, false otherwise
  Future<bool> attemptLogin({String? encryptedJwk, String? password}) async {
    try {
      final AppSettingsStore settingsStore = AppSettingsStore();
      if (password == null) {
        // 1) Enforce auto-lock window (if enabled)
        final autoLock = await settingsStore.loadAutoLockSettings(
          fallback: const AutoLockSettings(enabled: true, timeout: Duration(days: 7)),
        );

        if (autoLock != null && autoLock.enabled) {
          final lastUnlockAt = await settingsStore.loadLastUnlockAt();
          if (lastUnlockAt == null) {
            return false; // never unlocked before -> don't auto-login
          }

          final expiresAt = lastUnlockAt.toLocal().add(autoLock.timeout);
          if (DateTime.now().isAfter(expiresAt)) {
            // auto-lock window elapsed -> delete password & return false
            await settingsStore.deleteLastUnlockAt();
            await _storage.delete(key: defaultPasswordKey);
            return false;
          }
        }

        password = await _storage.read(key: defaultPasswordKey);
        if (password == null) return false;
      }

      String jwkString;
      if (encryptedJwk != null) {
        jwkString = await decryptJwkFromExportString(password: password, exportString: encryptedJwk);
      } else {
        jwkString = await decryptStoredJwk(password: password);
      }

      // TODO NOTE the bulk of the login time (~98% with 600k iterations) is spent decrypting the wallet key
      // On my tests, it took an average of 4175 ms (4275 ms total login time) on a Pixel 6a emulator. You can tune the PBKDF2 iterations to balance security and login time
      // Also, to make app loading times faster, you could decrypt the key and save it in memory until the password expires (based on the auto-lock settings). But, this would be less secure than only having it in memory during the login function, so it's not implemented in this template.
      jwk = jsonDecode(jwkString) as Map<String, dynamic>;

      // if the jwk can be used to sign data, it's completely valid
      await ArweaveJs.sign(jwk: jwk!, messageBytes: utf8.encode('jwk validity test'));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Encrypt a JWK JSON string into a portable export string (base64url(JSON)).
  /// Optionally include the derived address (non-secret) for convenience.
  Future<String> encryptJwkToExportString({
    required String password,
    required String jwkJson,
    String? address,
  }) async {
    if (password.isEmpty) {
      throw WalletVaultException('Password is empty.');
    }
    if (jwkJson.isEmpty) {
      throw WalletVaultException('JWK JSON is empty.');
    }

    final salt = _randomBytes(_saltLen);
    final nonce = _randomBytes(_nonceLen);

    final key = await _deriveKey(password: password, salt: salt);

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(jwkJson),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_aadContext),
    );

    final payload = <String, dynamic>{
      'v': _version,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'salt_b64u': _b64uEncode(salt),
        'dkLen': _keyLen,
      },
      'cipher': {
        'name': 'AES-256-GCM',
        'nonce_b64u': _b64uEncode(nonce),
        'ct_b64u': _b64uEncode(secretBox.cipherText),
        'tag_b64u': _b64uEncode(secretBox.mac.bytes),
        'aad': _aadContext,
      },
      if (address != null && address.isNotEmpty) 'address': address,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final jsonStr = jsonEncode(payload);
    return _b64uEncode(utf8.encode(jsonStr));
  }

  /// Decrypts an export string back into the JWK JSON string.
  Future<String> decryptJwkFromExportString({
    required String password,
    required String exportString,
  }) async {
    if (password.isEmpty) {
      throw WalletVaultException('Password is empty.');
    }
    if (exportString.isEmpty) {
      throw WalletVaultException('Export string is empty.');
    }

    Map<String, dynamic> payload;
    try {
      final jsonBytes = _b64uDecode(exportString);
      payload = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw WalletVaultException('Export string is not valid base64url(JSON).');
    }

    final v = payload['v'];
    if (v != _version) {
      throw WalletVaultException('Unsupported vault version: $v');
    }

    final kdf = payload['kdf'] as Map<String, dynamic>?;
    final cipher = payload['cipher'] as Map<String, dynamic>?;
    if (kdf == null || cipher == null) {
      throw WalletVaultException('Malformed vault payload.');
    }

    final kdfName = kdf['name'];
    final iterations = kdf['iterations'];
    final saltB64u = kdf['salt_b64u'];
    final dkLen = kdf['dkLen'];

    if (kdfName != 'PBKDF2-HMAC-SHA256' ||
        iterations is! int ||
        saltB64u is! String ||
        dkLen is! int) {
      throw WalletVaultException('Unsupported or malformed KDF params.');
    }

    final cipherName = cipher['name'];
    final nonceB64u = cipher['nonce_b64u'];
    final ctB64u = cipher['ct_b64u'];
    final tagB64u = cipher['tag_b64u'];
    final aad = cipher['aad'];

    if (cipherName != 'AES-256-GCM' ||
        nonceB64u is! String ||
        ctB64u is! String ||
        tagB64u is! String ||
        aad is! String) {
      throw WalletVaultException('Unsupported or malformed cipher params.');
    }

    // Use the AAD stored in payload (lets you rotate context if you version)
    final aadBytes = utf8.encode(aad);

    final salt = _b64uDecode(saltB64u);
    final nonce = _b64uDecode(nonceB64u);
    final ciphertext = _b64uDecode(ctB64u);
    final tag = _b64uDecode(tagB64u);

    final key = await _deriveKey(
      password: password,
      salt: salt,
      iterations: iterations,
      derivedKeyLength: dkLen,
    );

    final box = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tag),
    );

    try {
      final clearBytes = await _aesGcm.decrypt(
        box,
        secretKey: key,
        aad: aadBytes,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      // This is what you want to show as "wrong password or hash"
      throw WalletVaultException('Incorrect password or corrupted export data.');
    } catch (e) {
      throw WalletVaultException('Failed to decrypt: $e');
    }
  }

  /// Store the export string (encrypted payload) in Android Keystore-backed secure storage.
  Future<void> saveExportString(
    String exportString, {
    String storageKey = defaultStorageKey,
  }) async {
    await _storage.write(key: storageKey, value: exportString);
  }

  /// Saves a password to Android Keystore-backed secure storage, and updates the last unlock timestamp for auto-lock purposes.
  Future<void> savePassword(String password) async {
    await _storage.write(key: defaultPasswordKey, value: password);
    await AppSettingsStore().saveLastUnlockAt(DateTime.now());
  }

  /// Removes the saved password from secure storage and clears unlock timestamp.
  Future<void> deleteSavedPassword() async {
    await _storage.delete(key: defaultPasswordKey);
    await AppSettingsStore().deleteLastUnlockAt();
    jwk = null;
  }

  /// Load the export string from secure storage.
  Future<String?> loadExportString({
    String storageKey = defaultStorageKey,
  }) async {
    return _storage.read(key: storageKey);
  }

  /// Remove the stored export string (logout / wipe).
  Future<void> deleteExportString({
    String storageKey = defaultStorageKey,
  }) async {
    await _storage.delete(key: storageKey);
  }

  /// Convenience: decrypt directly from stored export string.
  Future<String> decryptStoredJwk({
    required String password,
    String storageKey = defaultStorageKey,
  }) async {
    final export = await loadExportString(storageKey: storageKey);
    if (export == null || export.isEmpty) {
      throw WalletVaultException('No vault data found in secure storage.');
    }
    return decryptJwkFromExportString(password: password, exportString: export);
  }

  // --- Internals ---

  AesGcm get _aesGcm => AesGcm.with256bits();

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    int? iterations,
    int? derivedKeyLength,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations ?? _pbkdf2Iterations,
      bits: (derivedKeyLength ?? _keyLen) * 8,
    );

    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // Ensure derived length matches what we expect for AES-256.
    final bytes = await key.extractBytes();
    if (bytes.length != (derivedKeyLength ?? _keyLen)) {
      throw WalletVaultException('Derived key length mismatch.');
    }
    return SecretKey(bytes);
  }

  List<int> _randomBytes(int length) {
    final rnd = math.Random.secure();
    final out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  // --- base64url helpers (no padding) ---

  String _b64uEncode(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Uint8List _b64uDecode(String b64u) {
    var s = b64u.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return Uint8List.fromList(base64Decode(s));
  }
}
