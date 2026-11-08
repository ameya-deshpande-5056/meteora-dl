import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class ChecksumVerifier {
  /// Computes the SHA-256 hex string of the given bytes and verifies it matches the expected hash.
  static bool verifySha256(Uint8List bytes, String expectedSha256) {
    if (expectedSha256.trim().isEmpty) return true; // Checksum not provided
    final computed = sha256.convert(bytes).toString().toLowerCase();
    final expected = expectedSha256.trim().toLowerCase();
    return computed == expected;
  }

  /// Computes the SHA-256 digest of bytes.
  static String computeSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }
}
