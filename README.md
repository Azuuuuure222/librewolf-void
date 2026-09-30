# LibreWolf for Void Linux — Skylake / x86_64-musl

A personal LibreWolf package for **Void Linux x86_64-musl**, tuned for an **Intel Core i3-6100U (Skylake)** with **4 GB DDR3 + HDD**, and focused on **Wayland**.

## Purpose

This project prioritizes practical performance on the target laptop rather than broad hardware portability.

- `-march=skylake` / `-mtune=skylake`
- Rust `target-cpu=skylake`
- Clang + Rust SIMD
- Low-memory browser behavior
- Wayland support
- musl compatibility fixes

## Build

The package is **compiled on GitHub Actions**, not on the target device.

- Build host: GitHub Actions
- Target: **x86_64-musl / Skylake**
- Packaging: Void `xbps-src`

The resulting package is intended for Skylake-class x86_64-musl systems. CPUs older than Skylake are outside the intended scope.

## Optimization

PGO + full LTO are enabled by default. The final build uses the Skylake target, cross-language PGO, full LTO at LLVM `-O2`, Rust optimization level 2, and parallel LTO code generation. The intent is runtime efficiency on a 4 GB machine rather than maximum benchmark aggressiveness.

## Source integrity and caching

The LibreWolf source archive has a **mandatory 64-character SHA-256 checksum** in the package template. CI rejects missing or malformed checksums, verifies the archive before it enters the xbps source directory, and verifies it again immediately before the build.

Source downloads use an **immutable cache key derived from the exact SHA-256**. The cache is warmed from the `master` branch and restored by tag builds, so a new build normally avoids re-downloading the large LibreWolf archive. Cold downloads use resumable segmented `aria2c` transfers; checksum verification remains mandatory regardless of cache state.

## Scope

This is a **personal, hardware-specific build**, not a replacement for Void Linux's general-purpose LibreWolf/Firefox packaging.
