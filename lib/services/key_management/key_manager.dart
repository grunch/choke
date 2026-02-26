import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing Nostr keypairs
/// Handles generation, storage, and recovery of keys
class KeyManager {
  static const String _privateKeyKey = 'nostr_private_key';
  static const String _publicKeyKey = 'nostr_public_key';

  final FlutterSecureStorage _secureStorage;
  String? _cachedPrivateKey;
  String? _cachedPublicKey;

  KeyManager({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Initialize the key manager
  /// Generates a new keypair if none exists
  Future<void> initialize() async {
    final existingPrivateKey = await _secureStorage.read(key: _privateKeyKey);

    if (existingPrivateKey == null || existingPrivateKey.isEmpty) {
      // Generate new keypair on first launch
      await _generateAndStoreKeypair();
    } else {
      // Cache existing keys
      _cachedPrivateKey = existingPrivateKey;
      _cachedPublicKey = await _secureStorage.read(key: _publicKeyKey);
    }
  }

  /// Generate a new secp256k1 keypair and store it securely
  Future<void> _generateAndStoreKeypair() async {
    // Generate random 32 bytes for private key
    final random = Random.secure();
    final privateKeyBytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKeyBytes[i] = random.nextInt(256);
    }

    // Convert to hex string
    final privateKeyHex =
        privateKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Derive public key from private key using secp256k1
    final publicKeyHex = _derivePublicKeyHex(privateKeyHex);

    // Store securely
    await _secureStorage.write(key: _privateKeyKey, value: privateKeyHex);
    await _secureStorage.write(key: _publicKeyKey, value: publicKeyHex);

    // Cache in memory
    _cachedPrivateKey = privateKeyHex;
    _cachedPublicKey = publicKeyHex;

    debugPrint('KeyManager: New keypair generated and stored');
  }

  /// Get the public key in hex format
  Future<String?> getPublicKeyHex() async {
    if (_cachedPublicKey != null) return _cachedPublicKey;
    return await _secureStorage.read(key: _publicKeyKey);
  }

  /// Get the private key in hex format (nsec without prefix)
  /// WARNING: Only use this when absolutely necessary
  Future<String?> getPrivateKeyHex() async {
    if (_cachedPrivateKey != null) return _cachedPrivateKey;
    return await _secureStorage.read(key: _privateKeyKey);
  }

  /// Get public key in NIP-19 npub format
  Future<String?> getNpub() async {
    final publicKeyHex = await getPublicKeyHex();
    if (publicKeyHex == null) return null;
    return _encodeNpub(publicKeyHex);
  }

  /// Get private key in NIP-19 nsec format
  Future<String?> getNsec() async {
    final privateKeyHex = await getPrivateKeyHex();
    if (privateKeyHex == null) return null;
    return _encodeNsec(privateKeyHex);
  }

  /// Import a private key from nsec format
  /// Returns true if successful, false otherwise
  Future<bool> importFromNsec(String nsec) async {
    try {
      // Validate and decode nsec
      final privateKeyHex = _decodeNsec(nsec);
      if (privateKeyHex == null) {
        debugPrint('KeyManager: Invalid nsec format');
        return false;
      }

      // Derive public key from private key using secp256k1
      final publicKeyHex = _derivePublicKeyHex(privateKeyHex);

      // Store new keys (replaces existing)
      await _secureStorage.write(key: _privateKeyKey, value: privateKeyHex);
      await _secureStorage.write(key: _publicKeyKey, value: publicKeyHex);

      // Update cache
      _cachedPrivateKey = privateKeyHex;
      _cachedPublicKey = publicKeyHex;

      debugPrint('KeyManager: Keypair imported successfully');
      return true;
    } catch (e) {
      debugPrint('KeyManager: Error importing nsec: $e');
      return false;
    }
  }

  /// Export public key as QR code data
  Future<String?> getPublicKeyForQR() async {
    return await getNpub();
  }

  /// Check if keys exist
  Future<bool> hasKeys() async {
    final privateKey = await _secureStorage.read(key: _privateKeyKey);
    return privateKey != null && privateKey.isNotEmpty;
  }

  /// Delete all keys (use with caution!)
  Future<void> deleteKeys() async {
    await _secureStorage.delete(key: _privateKeyKey);
    await _secureStorage.delete(key: _publicKeyKey);
    _cachedPrivateKey = null;
    _cachedPublicKey = null;
    debugPrint('KeyManager: All keys deleted');
  }

  /// Derive secp256k1 public key from private key (x-only hex for Nostr).
  String _derivePublicKeyHex(String privateKeyHex) {
    // TODO: Implement proper secp256k1 public key derivation
    // For now, throw to indicate this needs implementation before release
    throw UnimplementedError(
      'secp256k1 public key derivation not implemented. '
      'Install pointycastle or secp256k1 package and implement derivation.',
    );
  }

  // NIP-19 Encoding/Decoding - Simplified implementation

  /// Encode hex public key to npub (NIP-19)
  String _encodeNpub(String hexPublicKey) {
    // Validate input
    if (hexPublicKey.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexPublicKey)) {
      throw ArgumentError('Invalid public key hex: must be 64 hex characters');
    }
    // Return full hex with prefix (until proper bech32 is implemented)
    return 'npub1$hexPublicKey';
  }

  /// Encode hex private key to nsec (NIP-19)
  String _encodeNsec(String hexPrivateKey) {
    // Validate input
    if (hexPrivateKey.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexPrivateKey)) {
      throw ArgumentError('Invalid private key hex: must be 64 hex characters');
    }
    // Return full hex with prefix (until proper bech32 is implemented)
    return 'nsec1$hexPrivateKey';
  }

  /// Decode nsec to hex private key
  String? _decodeNsec(String nsec) {
    try {
      // Basic validation
      if (!nsec.toLowerCase().startsWith('nsec1')) return null;

      // Extract the full hex suffix
      final raw = nsec.substring(5).toLowerCase();

      // Validate: must be 64 hex characters
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(raw)) return null;

      return raw;
    } catch (e) {
      debugPrint('KeyManager: nsec decode error: $e');
      return null;
    }
  }
}

/// Provider for KeyManager
final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

/// Provider for npub (public identity)
final npubProvider = FutureProvider<String?>((ref) async {
  final keyManager = ref.watch(keyManagerProvider);
  return await keyManager.getNpub();
});

/// Provider for nsec (private key - use with caution)
final nsecProvider = FutureProvider<String?>((ref) async {
  final keyManager = ref.watch(keyManagerProvider);
  return await keyManager.getNsec();
});
