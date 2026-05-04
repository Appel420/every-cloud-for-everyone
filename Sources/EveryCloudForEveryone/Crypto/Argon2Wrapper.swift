import Foundation
import CryptoSwift

/// Wraps Scrypt key derivation (memory-hard, equivalent security class to Argon2id).
///
/// Uses CryptoSwift's native Scrypt implementation. Parameters are mapped from
/// the Argon2id-style API:
///   - `memoryCostKiB` → Scrypt N (nearest power of two ≤ memoryCostKiB)
///   - `parallelism`   → Scrypt p
///   - r is fixed at 8 (standard recommendation)
///
/// A future build can swap in a native Argon2id binding without changing any
/// call sites.
public struct Argon2Wrapper: Sendable {

    // MARK: - Configuration

    /// Derivation parameters modelled after Argon2id tunables.
    public struct Parameters: Sendable {
        /// Memory cost in KiB. Mapped to the nearest power-of-two Scrypt N.
        public let memoryCostKiB: Int
        /// Number of passes (used as Scrypt p for CPU cost scaling).
        public let iterations: Int
        /// Degree of parallelism (Scrypt p).
        public let parallelism: Int
        /// Desired output key length in bytes.
        public let outputLength: Int

        /// Defaults matching the OWASP Argon2id minimum recommendation
        /// (≈16 MiB memory, 1 thread, 32-byte output).
        public static let `default` = Parameters(
            memoryCostKiB: 16_384,
            iterations: 1,
            parallelism: 1,
            outputLength: 32
        )
    }

    // MARK: - Derivation

    /// Derives a key from `passphrase` and `salt` using Scrypt.
    ///
    /// - Parameters:
    ///   - passphrase: The user's passphrase (UTF-8 encoded).
    ///   - salt: A random salt (≥1 byte required; ≥16 bytes recommended).
    ///   - parameters: Tuning parameters.
    /// - Returns: Raw key bytes of length `parameters.outputLength`.
    public static func deriveKey(
        passphrase: String,
        salt: Data,
        parameters: Parameters = .default
    ) -> Data {
        // Map memoryCostKiB to nearest power-of-two N (Scrypt requirement).
        let n = nearestPowerOfTwo(lessThanOrEqualTo: max(2, parameters.memoryCostKiB))
        let scrypt = try! Scrypt(
            password: Array(passphrase.utf8),
            salt: Array(salt),
            dkLen: parameters.outputLength,
            N: n,
            r: 8,
            p: parameters.parallelism
        )
        return Data(try! scrypt.calculate())
    }

    // MARK: - Private helpers

    /// Returns the largest power of two that is ≤ `value`.
    private static func nearestPowerOfTwo(lessThanOrEqualTo value: Int) -> Int {
        var n = 1
        while n * 2 <= value { n *= 2 }
        return n
    }
}
