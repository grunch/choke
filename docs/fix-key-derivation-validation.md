# Fix: Key Derivation Validation

## Problem

The `npub` displayed in the Account screen did not correspond to the `nsec` (private key). Users copying their `nsec` and verifying it externally would get a different `npub` than what Choke showed.

## Root Causes

### 1. No validation on initialization

When `KeyManager.initialize()` found existing keys in secure storage, it blindly trusted the stored public key without verifying it matched the private key:

```dart
// OLD — trusts stored public key without verification
_cachedPrivateKey = existingPrivateKey;
_cachedPublicKey = await _secureStorage.read(key: _publicKeyKey);
```

If the stored public key was corrupted, stale, or written incorrectly during a previous session, the mismatch would persist forever.

### 2. Manual random byte generation

The original `_generateAndStoreKeypair()` generated 32 random bytes manually and hoped they formed a valid secp256k1 private key:

```dart
// OLD — no guarantee the bytes are a valid secp256k1 private key
final random = Random.secure();
final privateKeyBytes = Uint8List(32);
for (var i = 0; i < 32; i++) {
  privateKeyBytes[i] = random.nextInt(256);
}
```

A valid secp256k1 private key must be in the range `[1, n-1]` where `n` is the curve order. Random 32-byte values can theoretically fall outside this range (e.g., all zeros or values >= n), leading to invalid or incorrect key derivation.

## Fix

### 1. Validate public key on every initialization

`initialize()` now always derives the public key from the stored private key and compares it with the stored value. If they don't match, it corrects the stored public key:

```dart
final derivedPublicKey = _derivePublicKeyHex(existingPrivateKey);
final storedPublicKey = await _secureStorage.read(key: _publicKeyKey);
if (storedPublicKey != derivedPublicKey) {
  await _secureStorage.write(key: _publicKeyKey, value: derivedPublicKey);
}
_cachedPublicKey = derivedPublicKey;
```

### 2. Use `nostr_tools` `KeyApi.generatePrivateKey()`

Instead of manual random byte generation, we now use the library's built-in key generation which guarantees a valid secp256k1 private key:

```dart
final keyApi = KeyApi();
final privateKeyHex = keyApi.generatePrivateKey();
final publicKeyHex = keyApi.getPublicKey(privateKeyHex);
```

## Files Changed

- `lib/services/key_management/key_manager.dart`
  - Removed `dart:math` and `dart:typed_data` imports (no longer needed)
  - `initialize()`: Added public key derivation validation
  - `_generateAndStoreKeypair()`: Replaced manual random bytes with `KeyApi.generatePrivateKey()`

## Impact

- **Self-healing**: Existing users with mismatched keys will have their public key auto-corrected on next app launch
- **Prevention**: New key generation always produces valid secp256k1 keys
- **No data loss**: Private keys are never modified; only the derived public key is corrected
