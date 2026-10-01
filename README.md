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

**PGO + full native LLVM LTO** are enabled. Native C/C++ code uses full LTO; Rust is deliberately built with Thin LTO to reduce compiler memory use and CI time. The build uses LLVM `-O2`, Rust optimization level 2, Skylake tuning, cross-language PGO, and parallel LTO code generation. The goal is efficient runtime behavior on a low-RAM Skylake system rather than maximum benchmark performance.

A SQLite-specific semantic-interposition override preserves correct shared-library relocations under full LTO while keeping the faster global Clang settings elsewhere.

The runtime defaults are tuned for the target's 4 GB RAM and HDD: four shared web content processes, one preallocated content process, earlier low-memory reclamation, less aggressive session-store and cache write buffering, and no new-tab preload. PGO profiling uses a headless Wayland compositor in CI when available, with an X11 fallback for non-CI builds.

## CI & source integrity

- The package template contains a mandatory 64-character SHA-256 checksum.
- Void's `xbps-src fetch` performs the normal source download and checksum verification.
- The exact LibreWolf distfile is cached by its SHA-256, avoiding a second custom downloader.
- Source fetching has a dedicated 20-minute timeout.
- The build has separate bootstrap and package timeouts, so infrastructure failures stop early.
- GitHub Actions uses sccache for compiler caching.

## Scope

A personal, hardware-specific LibreWolf build for **Skylake + x86_64-musl**. It is not intended as a general-purpose Void Linux package.
