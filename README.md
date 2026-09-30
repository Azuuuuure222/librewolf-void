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

PGO and LTO are kept optional because they substantially increase CI build time. The goal is to balance runtime optimization with the GitHub Actions build window.

## Scope

This is a **personal, hardware-specific build**, not a replacement for Void Linux's general-purpose LibreWolf/Firefox packaging.
