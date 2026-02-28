import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_tools/nostr_tools.dart';

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
  /// Validates that stored public key matches the private key
  Future<void> initialize() async {
    final existingPrivateKey = await _secureStorage.read(key: _privateKeyKey);

    if (existingPrivateKey == null || existingPrivateKey.isEmpty) {
      // Generate new keypair on first launch
      await _generateAndStoreKeypair();
    } else {
      // Always derive the public key from the private key to ensure
      // the npub displayed actually corresponds to the stored nsec.
      _cachedPrivateKey = existingPrivateKey;
      final derivedPublicKey = _derivePublicKeyHex(existingPrivateKey);

      // Check if stored public key matches derived key and fix if needed
      final storedPublicKey = await _secureStorage.read(key: _publicKeyKey);
      if (storedPublicKey != derivedPublicKey) {
        debugPrint('KeyManager: Stored public key mismatch — correcting');
        await _secureStorage.write(
            key: _publicKeyKey, value: derivedPublicKey);
      }
      _cachedPublicKey = derivedPublicKey;
    }
  }

  /// Generate a new secp256k1 keypair and store it securely.
  /// Uses nostr_tools KeyApi to guarantee a valid private key.
  Future<void> _generateAndStoreKeypair() async {
    final keyApi = KeyApi();

    // Generate a valid secp256k1 private key via nostr_tools
    final privateKeyHex = keyApi.generatePrivateKey();

    // Derive public key from private key
    final publicKeyHex = keyApi.getPublicKey(privateKeyHex);

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

  /// Derive secp256k1 public key from private key using nostr_tools.
  String _derivePublicKeyHex(String privateKeyHex) {
    try {
      final keyApi = KeyApi();
      return keyApi.getPublicKey(privateKeyHex);
    } catch (e) {
      debugPrint('KeyManager: Error deriving public key: $e');
      rethrow;
    }
  }

  // NIP-19 Encoding/Decoding using nostr_tools

  /// Encode hex public key to npub (NIP-19 bech32)
  String _encodeNpub(String hexPublicKey) {
    try {
      final nip19 = Nip19();
      return nip19.npubEncode(hexPublicKey);
    } catch (e) {
      debugPrint('KeyManager: Error encoding npub: $e');
      rethrow;
    }
  }

  /// Encode hex private key to nsec (NIP-19 bech32)
  String _encodeNsec(String hexPrivateKey) {
    try {
      final nip19 = Nip19();
      return nip19.nsecEncode(hexPrivateKey);
    } catch (e) {
      debugPrint('KeyManager: Error encoding nsec: $e');
      rethrow;
    }
  }

  /// Decode nsec to hex private key
  String? _decodeNsec(String nsec) {
    try {
      final nip19 = Nip19();
      final decoded = nip19.decode(nsec);

      // Validate type is 'nsec'
      if (decoded['type'] != 'nsec') return null;

      // Return the hex data
      return decoded['data'] as String?;
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
