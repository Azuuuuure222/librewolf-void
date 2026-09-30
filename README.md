# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal LibreWolf packaging for **Void Linux x86_64-musl**, optimized for an **Intel Core i3-6100U (Skylake), 4 GB DDR3, and HDD**, with a Wayland focus.

## Target

- **CPU:** Skylake / x86_64
- **ABI:** musl
- **Features:** Wayland, musl compatibility fixes
- **Optimization:** `-march=skylake`, `-mtune=skylake`, Rust `target-cpu=skylake`, Clang/Rust SIMD
- **Build:** GitHub Actions → Void `xbps-src`

The package is compiled on GitHub Actions, **not on the target device**. Older CPUs are outside the intended scope.

## Build optimization

**PGO + full LTO** are enabled. The build uses LLVM `-O2`, Rust optimization level 2, Skylake tuning, cross-language PGO, and parallel LTO code generation. The goal is efficient runtime behavior on a low-RAM Skylake system rather than maximum benchmark performance.

## CI & source integrity

- LibreWolf source SHA-256 is **mandatory** and must be a valid 64-character digest.
- Archives are verified before use and again before the package build.
- Source caching is keyed by the exact SHA-256.
- A default-branch cache warmer reduces repeated large source downloads.
- Cold downloads use resumable `curl` with retries and stalled-transfer detection.
- GitHub Actions uses sccache for compiler caching.

## Scope

A personal, hardware-specific LibreWolf build for **Skylake + x86_64-musl**. It is not intended as a general-purpose Void Linux package.
