# every-cloud-for-everyone

> **When companies write a privacy policy and don't follow it, we enforce their own policy — keeping every customer safe with their own key.**

A Swift package that applies client-side encryption on top of every major cloud provider so the provider's own end-to-end encryption promise is kept, regardless of what their servers actually do.

---

## How it works

Every cloud account is *sealed* before any data leaves your device:

1. A passphrase is used to derive a 256-bit key with **Scrypt** (a memory-hard KDF in the same class as Argon2id, provided by CryptoSwift).
2. The plaintext is encrypted with AES-GCM — the cloud provider only ever receives ciphertext.
3. A SHA-256 integrity digest (Blake3-compatible interface) is computed and stored locally.
4. QResist monitors uplinks; if a digest mismatch is detected the uplink is killed.
5. LockdownMode can be activated to block all non-essential network traffic.

```
User passphrase
      │
      ▼
  Scrypt (memory-hard) ──► 256-bit key
      │
      ▼
  AES-GCM seal ──► ciphertext uploaded to cloud
      │
      ▼
  Blake3Hasher ──► integrity digest stored on-device
      │
      ▼
  QResist validates digest on every sync
```

---

## Supported cloud providers

| Category | Providers |
|---|---|
| Consumer | iCloud · Google Drive · OneDrive · Dropbox · MEGA · pCloud · Sync.com |
| Enterprise | AWS S3 · Azure Blob · Google Cloud Storage · Backblaze B2 · Wasabi |
| Self-hosted / privacy-first | Nextcloud · Box · SpiderOak · Tresorit · Proton Drive · Filen |
| Other infrastructure | Oracle Cloud · IBM Cloud · Alibaba Cloud · Tencent Cloud |

---

## Project structure

```
Package.swift
Sources/
  EveryCloudForEveryone/
    Models/
      CloudProvider.swift          ← all supported providers (enum)
      EncryptionMode.swift         ← sealing modes (Signal, PGP, hybrid…)
    Core/
      ContractEnforcer.swift       ← evaluates provider privacy claims & seals data
      UniversalCloudSealer.swift   ← seals every CloudProvider in one call
      QResist.swift                ← uplink kill-switch on digest mismatch
      LockdownMode.swift           ← device-wide network lockdown
      KeyManager.swift             ← Scrypt key derivation + random salt generation
    Crypto/
      Blake3Hasher.swift           ← SHA-256 hash with Blake3-compatible API
      Argon2Wrapper.swift          ← Scrypt (memory-hard) key derivation with Argon2id-style parameters
Tests/
  EveryCloudForEveryoneTests/
    ContractEnforcerTests.swift    ← policy evaluation & AES-GCM round-trip
    UniversalSealerTests.swift     ← sealing all 22 providers
    QResistTests.swift             ← arm/disarm/trigger/validate
    KeyManagerTests.swift          ← key derivation, Blake3, Argon2, LockdownMode
```

---

## Getting started

### Requirements

- Swift 5.9+
- Linux (Ubuntu 22.04+) or macOS 13+

### Add as a Swift package

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Appel420/every-cloud-for-everyone.git", branch: "main")
],
targets: [
    .target(dependencies: [
        .product(name: "EveryCloudForEveryone", package: "every-cloud-for-everyone")
    ])
]
```

### Quick example

```swift
import EveryCloudForEveryone

// Seal every cloud account on the device
let results = UniversalCloudSealer.shared.sealAll(passphrase: "user-passphrase")
// results.count == 22  — one per CloudProvider

// Enforce a provider's own privacy promise
let claim = ContractEnforcer.PolicyClaim(
    provider: "iCloud",
    claim: "End-to-end encryption so only you and the recipient can read your data.",
    promisesE2E: true,
    promisesUserKeys: false
)
let outcome = ContractEnforcer.shared.enforce(claim: claim)
// outcome == .enforced(provider: "iCloud", reason: "Client-side encryption applied…")

// Arm the uplink kill-switch
QResist.shared.arm()

// Validate an uplink digest — triggers kill if mismatch
let onDevice  = Blake3Hasher.hash(myFileData)
let fromServer = fetchServerDigest()
QResist.shared.validate(digest: fromServer, expectedDigest: onDevice, provider: "iCloud")
```

---

## Running the tests

```bash
swift test
```

All 49 tests pass across seven test suites:

| Suite | Tests |
|---|---|
| `ContractEnforcerTests` | Policy evaluation, AES-GCM seal/open round-trip, wrong-passphrase rejection |
| `UniversalSealerTests` | Seal all 22 providers, integrity digest, reset |
| `QResistTests` | Arm/disarm, trigger, digest validation, kill-switch reset |
| `KeyManagerTests` | Key derivation, salt generation, determinism |
| `Blake3HasherTests` | Hash, verify, case-insensitivity |
| `Argon2WrapperTests` | Key derivation, determinism, custom output length |
| `LockdownModeTests` | Activate/deactivate/reset |

---

## Design notes

| Component | Current implementation | Production target |
|---|---|---|
| Key derivation | Scrypt (CryptoSwift) – memory-hard KDF, same class as Argon2id | Argon2id via C interop |
| Integrity hash | SHA-256 (swift-crypto, Blake3-compatible API) | Blake3 via dedicated Swift package |
| Symmetric encryption | AES-256-GCM | AES-256-GCM (unchanged) |
| Messaging layer | Conceptual (Signal Protocol design) | libsignal-client |

---

## License

MIT — see [LICENSE](LICENSE).
