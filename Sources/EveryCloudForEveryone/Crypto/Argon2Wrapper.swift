import Foundation
import CryptoSwift

/// Wraps Scrypt key derivation (memory-hard KDF similar in purpose to Argon2id).
///
/// Uses CryptoSwift's native Scrypt implementation. Parameters map from an
/// Argon2id-style API as follows:
///
/// - `memoryCostKiB` is treated as a *hint*. Scrypt's N parameter must be a
///   power of two; the nearest power of two **≤ memoryCostKiB** is used.
///   Actual memory per derivation ≈ 128 × N × r bytes (r is fixed at 8),
///   so the default `memoryCostKiB = 16_384` → N = 16 384 → ~16 MiB.
/// - `parallelism` maps directly to Scrypt's `p` parameter.
/// - `iterations` is stored in the struct for API compatibility but has no
///   direct Scrypt equivalent; Scrypt's cost is controlled through N and r.
///
/// A future build can swap in a native Argon2id binding without changing any
/// call sites.
public struct Argon2Wrapper: Sendable {

    // MARK: - Configuration

    /// Derivation parameters modelled after Argon2id tunables.
    public struct Parameters: Sendable {
        /// Memory cost hint in KiB. The nearest power-of-two ≤ this value is
        /// used as Scrypt's N, giving approx `memoryCostKiB × 1 KiB` actual usage.
        public let memoryCostKiB: Int
        /// Number of passes (stored for API compatibility; not used by Scrypt).
        public let iterations: Int
        /// Degree of parallelism mapped to Scrypt's `p` parameter.
        public let parallelism: Int
        /// Desired output key length in bytes.
        public let outputLength: Int

        /// Defaults giving ~16 MiB memory usage, 1 thread, 32-byte output.
        /// Equivalent N = 16 384, r = 8, p = 1 → memory = 128 × 16 384 × 8 ≈ 16 MiB.
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
    ///   - salt: A random salt (must not be empty; ≥16 bytes recommended).
    ///   - parameters: Tuning parameters.
    /// - Returns: Raw key bytes of length `parameters.outputLength`.
    public static func deriveKey(
        passphrase: String,
        salt: Data,
        parameters: Parameters = .default
    ) -> Data {
        precondition(!salt.isEmpty, "Argon2Wrapper: salt must not be empty.")
        precondition(parameters.outputLength > 0, "Argon2Wrapper: outputLength must be > 0.")
        precondition(parameters.parallelism > 0, "Argon2Wrapper: parallelism must be > 0.")

        // Scrypt N must be ≥ 2 and a power of two.
        // We derive it from memoryCostKiB so callers can reason in KiB terms.
        // Memory = 128 × N × r bytes  (r fixed at 8 below).
        let n = nearestPowerOfTwo(lessThanOrEqualTo: max(2, parameters.memoryCostKiB))

        let scrypt: Scrypt
        do {
            // r = 8 is the standard recommendation and is used throughout
            // the Scrypt literature; it keeps the memory formula simple.
            scrypt = try Scrypt(
                password: Array(passphrase.utf8),
                salt: Array(salt),
                dkLen: parameters.outputLength,
                N: n,
                r: 8,
                p: parameters.parallelism
            )
        } catch {
            preconditionFailure("Argon2Wrapper: Scrypt initialisation failed – \(error).")
        }

        do {
            return Data(try scrypt.calculate())
        } catch {
            preconditionFailure("Argon2Wrapper: Scrypt calculation failed – \(error).")
        }
    }

    // MARK: - Private helpers

    /// Returns the largest power of two that is ≤ `value`.
    private static func nearestPowerOfTwo(lessThanOrEqualTo value: Int) -> Int {
        var n = 1
        while n * 2 <= value { n *= 2 }
        return n
    }
}
