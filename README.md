# LibreWolf for Void Linux (x86_64-musl / Skylake)

A personal Void Linux LibreWolf package tailored for one specific class of hardware:

- **Target CPU:** Intel Skylake, specifically the **Core i3-6100U**
- **Target userspace:** **Void Linux x86_64-musl**
- **Target desktop stack:** **Wayland**
- **Target hardware profile:** **4 GB DDR3 RAM + HDD**
- **Build host:** **GitHub Actions** — the package is cross-built for the target device; compilation does **not** happen on the target laptop.

## Purpose

This repository exists to produce a LibreWolf build that is tuned for my own Skylake-based machine rather than trying to be a broadly portable Void package.

The goal is practical performance on an older, memory-constrained system:

- CPU-specific optimization for **Skylake**
- Rust code compiled for **Skylake**
- Clang-based compilation
- low-memory behavior tuned for a **4 GB RAM** system
- **Wayland** as the primary display environment
- Void Linux **musl** compatibility fixes
- optional heavier optimizations kept available when their compilation cost is acceptable

## Why a dedicated build?

Generic browser packages have to support a wide range of processors and systems. This project deliberately gives up that portability so the generated binary can be specialized for the hardware it is actually meant to run on.

In other words:

> **The build machine is GitHub Actions. The optimization target is the i3-6100U laptop.**

The resulting package is intended for **x86_64-musl Skylake systems**, not arbitrary x86_64 machines.

## Optimization philosophy

The project favors useful runtime optimization without turning every expensive build feature into a mandatory CI step.

The current configuration includes:

- -O2
- -march=skylake
- -mtune=skylake
- Rust target-cpu=skylake
- Clang
- -fno-semantic-interposition
- Rust SIMD
- Wayland support
- low-memory tab unloading behavior

**PGO is not enabled by default.** Profile-Guided Optimization requires an instrumented build, a profile-generation run, and a final rebuild, which substantially increases CI build time.

**ThinLTO/LTO remains optional** for the same reason: the project has to fit within the practical GitHub Actions compilation window.

## Hardware target

This is intentionally not a generic "Skylake package".

The primary target is the **Intel Core i3-6100U** class of system:

| Component | Target |
|---|---|
| CPU | Intel Core i3-6100U |
| Microarchitecture | Skylake |
| ISA target | x86_64 / Skylake |
| RAM | 4 GB DDR3 |
| Storage | HDD |
| libc | musl |
| Display stack | Wayland |

The hardware target matters because compiler optimizations and browser behavior are selected with this machine's constraints in mind.

## Build model

GitHub Actions performs the compilation using Void's packaging tools.

The workflow explicitly targets:

**x86_64-musl**

while the compiler flags target:

**Skylake**

This means the CI runner is only the **build host**. It is not the machine being optimized for.

## Scope

This repository is intentionally personal and narrow in scope.

It is **not** intended to replace Void Linux's official LibreWolf/Firefox packaging, provide binaries for every x86_64 CPU, or maintain broad hardware portability.

The priorities are:

1. compatibility with the target Void/musl environment
2. good runtime behavior on the i3-6100U system
3. reasonable GitHub Actions build time
4. practical maintenance for a single-user setup

## Status

LibreWolf is packaged as a Void Linux xbps-src package and built through GitHub Actions.

The target configuration is deliberately specialized. Running the resulting package on a CPU older than Skylake is outside the intended scope.

## License

The LibreWolf source and the files it contains remain under their respective upstream licenses. This repository contains packaging, build configuration, and target-specific changes for the personal Void Linux build.
