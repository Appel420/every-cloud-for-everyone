import Foundation
import Crypto

/// Wraps key-derivation logic modelled after Argon2id.
///
/// The current implementation uses HKDF-SHA256 as a portable stand-in. A
/// production build can swap this for a native Argon2 binding (e.g. via a C
/// interop shim) without changing any call sites.
public struct Argon2Wrapper: Sendable {

    // MARK: - Configuration

    /// Derivation parameters that mirror Argon2id tunables.
    public struct Parameters: Sendable {
        /// Memory cost hint in KiB (informational; not enforced by HKDF).
        public let memoryCostKiB: Int
        /// Number of passes (informational; not enforced by HKDF).
        public let iterations: Int
        /// Degree of parallelism (informational; not enforced by HKDF).
        public let parallelism: Int
        /// Desired output key length in bytes.
        public let outputLength: Int

        /// Defaults matching the OWASP Argon2id minimum recommendation.
        public static let `default` = Parameters(
            memoryCostKiB: 19_456,
            iterations: 2,
            parallelism: 1,
            outputLength: 32
        )
    }

    // MARK: - Derivation

    /// Derives a key from `passphrase` and `salt` using the supplied parameters.
    ///
    /// - Parameters:
    ///   - passphrase: The user's passphrase (UTF-8 encoded).
    ///   - salt: A random salt (≥16 bytes recommended).
    ///   - parameters: Argon2id tuning parameters.
    /// - Returns: Raw key bytes of length `parameters.outputLength`.
    public static func deriveKey(
        passphrase: String,
        salt: Data,
        parameters: Parameters = .default
    ) -> Data {
        let inputKey = SymmetricKey(data: Data(passphrase.utf8))
        // Encode parameters into the info field so different configs produce
        // distinct keys even with the same passphrase and salt.
        let info = "argon2id-v1;m=\(parameters.memoryCostKiB);t=\(parameters.iterations);p=\(parameters.parallelism)"
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data(info.utf8),
            outputByteCount: parameters.outputLength
        )
        return derived.withUnsafeBytes { Data($0) }
    }
}
