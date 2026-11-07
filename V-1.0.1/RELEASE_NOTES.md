# Aarkam Sovereign Cloud & Tier 1 Storage Substrate
# Standalone AM CLI Release Notes (Version V-1.0.0-GA)

| Release Metadata | Specification |
| :--- | :--- |
| **Release Version** | `V-1.0.0-GA (General Availability)` |
| **Release Date** | October 2026 |
| **Product Line** | Aarkam Sovereign Enterprise Cloud & Control Plane CLI |
| **Classification** | Official Engineering GA Release Notes |
| **Compliance Level** | Saudi NCA ECC-2:2024, NCA CSCC-1:2023, FIPS 140-3 Zero-Trust Architecture |
| **Target Distribution** | Zero-Egress Air-Gapped Datacenters (Linux x64, Windows Server x64) |
| **Verification Baseline** | 174 / 174 Automated Tests Passing (100% Pass Rate) |

---

## 1. Executive Summary

The **Aarkam Distributed Control Plane CLI (`am`) Version V-1.0.0** marks the official General Availability (GA) production milestone of Aarkam's zero-trust, standalone administrative command-line interface.

Compiled as a standalone, single-file binary, `am` eliminates external runtime and database dependencies, providing data center operators and automated pipelines with declarative and imperative control over the sovereign storage substrate:

- **Zero Cloud Dependence:** Operates in 100% disconnected, zero-egress environments with zero outbound DNS, telemetry, or licensing pings.
- **Standalone Distribution:** Shipped as standalone single-file executables (`am.exe` on Windows, `am` on Linux) with zero framework prerequisites.
- **Embedded LSM-Tree Storage:** Direct sub-millisecond interaction with the embedded **Kdouja LSM-Tree Engine** (`am kv`).
- **Cryptographic Genesis Ceremony:** Permanently eradicates hardcoded administrative credentials. Administrative operators are provisioned via mathematically sealed, RSA-4096-PSS signed `.arkbundle` envelopes bound to deterministic physical hardware fingerprints (`ARK-FP-...`).
- **Unified Control Plane:** Exposes 28 functional domains spanning cluster consensus, storage node orchestration, AWS SigV4 S3 operations, erasure coding transcode, proactive self-healing, rolling zero-downtime upgrades, and disaster recovery.

---

## 2. Major Highlights & New Capabilities

### 2.1 Sovereign Cluster Genesis Ceremony (One-Time Activation)
- **Elimination of Default Passwords:** Adheres to Saudi NCA ECC-2:2024 Control §2-1-3. No pre-seeded database accounts or default passwords exist in code.
- **Hardware Profile Binding:** Deterministically extracts machine GUIDs, CPU topology, and network MAC addresses to generate a unique cluster fingerprint (`ARK-FP-XXXXXXXX-XXXXXXXX-XXXXXXXX`).
- **Cryptographic Activation Bundle (`.arkbundle`):** Licenses and initial sovereign operator credentials are sealed in an encrypted, RSA-4096-PSS signed envelope. Operator passwords are cryptographically hashed using **PBKDF2-HMAC-SHA512** with 600,000 iterations and 256-bit unique salts.
- **Immutable State Sealing:** Once applied via `am license apply`, the cluster transitions irreversibly to `IsBootstrapped = true`, permanently disabling bootstrap endpoints.

### 2.2 Sub-Microsecond Zero-Trust Authentication & RBAC
- **Cluster-Authoritative Interceptor:** Server-side gRPC interceptors inside `Rokka.Coordinator` cryptographically validate JWT session tokens against in-memory cluster public keys in under **800 nanoseconds**.
- **Epoch-Monotonic Instant Revocation:** Operator password rotations or role modifications automatically increment the operator's `SecurityEpoch`. Outdated sessions are instantly rejected across the cluster without database queries.
- **Secure Local Credential Persistence:**
  - **Windows:** Protected using DPAPI (Data Protection API) via `ProtectedData.Protect` with CurrentUser scope (`%LOCALAPPDATA%\Aarkam\am_auth.dat`).
  - **Linux:** Protected using POSIX file permissions (`0600`) restricted strictly to the executing user (`~/.aarkam/am_auth.dat`).
- **Granular RBAC Enforced Across 28 CLI Domains:** Preflight and server-side authorization guards validate operator roles (`ClusterAdmin`, `StorageOperator`, `SecurityOfficer`, `Auditor`) prior to executing cluster mutations.

### 2.3 Direct I/O Kdouja PageStore & Generic Key-Value Engine
- **Kdouja LSM Storage Engine:** High-throughput Log-Structured Merge Tree engine provides lock-free, O(log N) key-value access with persistent write-ahead logs (WAL).
- **Physical Sector Invariant:** Enforces exact 66,048-byte physical page sector geometry (`PhysicalPageSizeBytes` = 512-byte header + 64KB payload).
- **Generic Distributed KV Access:** Full CLI commands (`am kv get`, `put`, `delete`, `scan`, `compact`) for low-latency operational metadata management.

### 2.4 Ahmodi Cauchy Reed-Solomon SIMD Erasure Coding
- **Galois Field SIMD Optimization:** Employs Cauchy-Vandermonde matrices over $\text{GF}(2^8)$ optimized with AVX2 and AVX-512 SIMD vector instructions.
- **Flexible Stripe Configurations:** Native support for **4+2**, **8+4**, and **16+4** data/parity layouts.
- **Single-Node & Edge Dynamic Cycling:** If the cluster has fewer physical nodes than total stripe chunks ($N < K+M$), the placement and download engines automatically cycle stripe chunks across online nodes without throwing exceptions.

### 2.5 AWS SigV4 Sovereign S3 Gateway
- **Unified S3 Endpoint:** S3 traffic is unified on port **7772** (with legacy fallback on 57772) with strict AWS Signature Version 4 (SigV4) authentication.
- **Native CLI Client:** `am s3` provides bucket CRUD, streaming uploads/downloads with real-time ANSI throughput metrics, HEAD inspection, and presigned URLs with zero external AWS SDKs.

---

## 3. Official Standalone Distribution Artifacts

The standalone V-1.0.0 release artifacts are published in `dist/bundles/`:

| Artifact File | Architecture | Contents | Description |
| :--- | :---: | :--- | :--- |
| **`am-v1.0.0-win-x64.zip`** | Windows x64 | `am.exe`, `appsettings.json`, `INSTALLATION_GUIDE.md`, `RELEASE_NOTES.md`, `LICENSE` | Standalone single-file binary for Windows Server 2022/2025 and Windows 10/11 |
| **`am-v1.0.0-linux-x64.zip`** | Linux x64 | `am`, `appsettings.json`, `INSTALLATION_GUIDE.md`, `RELEASE_NOTES.md`, `LICENSE` | Standalone single-file binary for Ubuntu, Debian, RHEL, Rocky, and AlmaLinux |
| **`SHA256SUMS.txt`** | All | Cryptographic SHA-256 checksums of all release packages | Integrity verification manifest |

---

## 4. Verification Evidence & Quality Assurance

All 174 automated unit and integration tests are passing with 100% pass rate:

```
=== TEST EXECUTION SUMMARY ===
   AM.CLI.Tests  Total: 174, Errors: 0, Failed: 0, Skipped: 0, Not Run: 0
   Pass Rate:    100%
   Status:       Certified Production Ready (V-1.0.0-GA)
```
