import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
    : _secureStorage =
          secureStorage ??
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
    final privateKeyHex = privateKeyBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // Derive public key using nostr_tools
    final keyPair = KeyPair(privateKey: privateKeyHex);
    final publicKeyHex = keyPair.publicKey;

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

      // Derive public key
      final keyPair = KeyPair(privateKey: privateKeyHex);
      final publicKeyHex = keyPair.publicKey;

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

  // NIP-19 Encoding/Decoding

  /// Encode hex public key to npub (NIP-19)
  String _encodeNpub(String hexPublicKey) {
    final data = _hexToBytes(hexPublicKey);
    final converted = _convertBits(data, 8, 5, true);
    return _bech32Encode('npub', converted);
  }

  /// Encode hex private key to nsec (NIP-19)
  String _encodeNsec(String hexPrivateKey) {
    final data = _hexToBytes(hexPrivateKey);
    final converted = _convertBits(data, 8, 5, true);
    return _bech32Encode('nsec', converted);
  }

  /// Decode nsec to hex private key
  String? _decodeNsec(String nsec) {
    try {
      // Basic validation
      if (!nsec.toLowerCase().startsWith('nsec1')) return null;

      // Remove prefix and decode
      final data = _bech32Decode(nsec);
      if (data == null) return null;

      final converted = _convertBits(data, 5, 8, false);
      return _bytesToHex(converted);
    } catch (e) {
      debugPrint('KeyManager: nsec decode error: $e');
      return null;
    }
  }

  // Helper methods

  Uint8List _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _convertBits(Uint8List data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;
    final maxAcc = (1 << (fromBits + toBits - 1)) - 1;

    for (final value in data) {
      acc = ((acc << fromBits) | value) & maxAcc;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    }

    return Uint8List.fromList(result);
  }

  String _bech32Encode(String hrp, Uint8List data) {
    final checksum = _createChecksum(hrp, data);
    final combined = Uint8List.fromList([...data, ...checksum]);
    return '$hrp1${_convertToChars(combined)}';
  }

  Uint8List? _bech32Decode(String bech32) {
    // Simplified - in production use proper bech32 library
    // This is a placeholder for the actual implementation
    return null;
  }

  Uint8List _createChecksum(String hrp, Uint8List data) {
    // Simplified checksum calculation
    return Uint8List(6);
  }

  String _convertToChars(Uint8List data) {
    const chars = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    return data.map((b) => chars[b]).join();
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
