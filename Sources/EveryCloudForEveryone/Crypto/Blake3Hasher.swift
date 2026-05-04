import Foundation
import Crypto

/// Computes Blake3-compatible integrity hashes over arbitrary data.
///
/// The current implementation uses SHA-256 as a portable stand-in. A
/// production build can swap this for a native Blake3 binding without
/// changing any call sites.
public struct Blake3Hasher: Sendable {

    // MARK: - Hash

    /// Returns the hex-encoded SHA-256 digest of `data`.
    public static func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Returns the hex-encoded SHA-256 digest of a UTF-8 encoded string.
    public static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    // MARK: - Verification

    /// Returns `true` when `data` hashes to `expectedHex`.
    public static func verify(data: Data, expectedHex: String) -> Bool {
        hash(data) == expectedHex.lowercased()
    }
}
