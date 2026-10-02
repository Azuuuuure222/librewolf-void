# LibreWolf for Void Linux — personal Skylake / x86_64-musl build

This repository is a personal, hardware-specific LibreWolf package for **Void Linux x86_64-musl**.

It is not intended to be a portable LibreWolf binary for arbitrary x86_64 systems. The package is deliberately tuned for one deployment target:

- **CPU:** Intel Core i3-6100U, Skylake, 2 cores / 4 threads
- **RAM:** 4 GB DDR3
- **Storage:** HDD
- **Display/session:** Wayland
- **OS:** Void Linux x86_64-musl

## Purpose

The goal is simple: build one LibreWolf package that is tuned for the machine that will actually run it.

That changes the priorities compared with a general-purpose distribution package. Portability across unrelated CPUs, cross-version reproducibility, and broad architecture support are not priorities here. Runtime responsiveness, memory pressure, HDD activity, and useful optimization passes are.

The project is effectively a personal build profile layered on top of Void's `xbps-src` packaging system and the upstream LibreWolf source.

## Why only this target

The package is restricted to **x86_64-musl / Skylake** because those restrictions describe the actual deployment machine.

**x86_64-musl** is the target because that is the installed Void environment. Maintaining a glibc build would add another ABI and compatibility matrix without providing value for this machine.

**Skylake** is the target because the Core i3-6100U supports the Skylake ISA/features. The package therefore uses `-march=skylake` and `-mtune=skylake` instead of trying to remain compatible with older x86_64 CPUs.

That restriction is intentional. A binary built this way should be treated as a machine-specific package, not a generic x86_64 artifact.

## Build optimizations

### CPU-specific compilation

C and C++ are built with:

```text
-O2 -march=skylake -mtune=skylake
```

Rust uses:

```text
-C target-cpu=skylake
```

This lets the generated code target the actual CPU instead of preserving compatibility with much older x86_64 processors.

### Clang / LLVM

The package uses **Clang 22, LLVM 22, and LLD 22**.

The Clang/LLD path is used because the Firefox build already has strong LLVM integration and the package is deliberately using LLVM-based LTO rather than treating GCC compatibility as a goal.

### Full LTO plus Rust ThinLTO

The final browser build enables LLVM cross-language LTO.

Rust is deliberately forced to **ThinLTO** through the downstream patch rather than using the full Rust LTO mode that Firefox's build logic can request during cross-language LTO.

The reason is practical: ThinLTO keeps most of the optimization benefit while avoiding an unnecessarily expensive Rust link strategy for a 4 GB machine and a long-running PGO/LTO build.

### PGO

Profile-guided optimization is enabled by default.

The workflow performs an instrumented build, runs the browser through a headless Wayland workload using Weston when available, collects `merged.profdata` and the jarlog, then performs the final profile-use build.

There is an X11/Xvfb fallback for environments where Weston is unavailable.

### Parallel LTO

The final linker is configured to use multiple LTO threads and partitions on the build runner.

The build machine can therefore spend CPU time aggressively during CI without making the package depend on the CPU count of the eventual laptop.

### sccache

The build uses Mozilla's sccache action and places the sccache binary inside the xbps masterdir so the Firefox build can invoke it from the chroot.

The workflow also passes the GitHub Actions cache backend into Void's `/host` bind mount. This lets the chrooted build use the GitHub-backed sccache service instead of silently losing the cache boundary at the xbps chroot.

A bounded local cache directory is retained for the host-side build environment.

## Runtime tuning

The package carries a small set of runtime preferences aimed at **4 GB RAM + HDD** systems:

- limit shared web-content process fan-out to four processes
- keep one Fission content process preallocated
- enable background-tab unloading under memory pressure
- trigger memory reclamation earlier
- reduce session-store write frequency to reduce HDD churn
- disable New Tab preloading when it is not needed
- cap disk-cache memory buffers

These are not claimed to be universally optimal Firefox settings. They are deliberately biased toward avoiding memory pressure and unnecessary disk activity on this specific machine.

## musl and Void compatibility

The package carries narrow compatibility fixes that are required for the selected Void musl environment and current Firefox 157-era sources, including:

- musl/Linux `prctl` header conflicts
- `mach clobber` compatibility
- missing C++ standard-library includes
- `audio_thread_priority` musl compatibility
- LLVM 22 compatibility
- `mallinfo` compatibility
- sandbox scheduling compatibility
- Rust ThinLTO for the Firefox Rust top-level crate

Most of these patches are synchronized with the corresponding current Void Firefox patches rather than being maintained as broad LibreWolf-specific forks.

## Build and CI model

GitHub Actions builds the package on Ubuntu 24.04 using the current Void `void-packages` tree.

The workflow:

1. frees runner disk space only when necessary
2. checks out this repository and Void packaging
3. overlays the LibreWolf package into `void-packages`
4. validates the source metadata
5. prepares static XBPS tooling
6. installs the PGO compositor
7. enables the user namespaces required by `xbps-src`
8. bootstraps the xbps masterdir
9. installs the CI sccache binary into that masterdir
10. exposes the GitHub-backed sccache environment to the chroot
11. restores or fetches and verifies the LibreWolf source
12. runs the full PGO/LTO package build
13. checksums the generated package and repository metadata
14. updates the source-version release tag and publishes the successful build

The workflow uses concurrency cancellation so obsolete multi-hour builds do not continue after newer changes are pushed.

A manual workflow dispatch is also available for rebuilding the current tree without changing the package source.

## Release model

This is a personal package repository, not a general-purpose distribution repository.

The release tag is based on the **LibreWolf source version and source revision**. Rebuilding the same source revision may update the same tag deliberately. The important state is the successful compiled package, not long-term preservation of every intermediate build.

XBPS signing is not used as a shared Void trust chain.

## Source integrity

The source archive, version, source revision, and SHA-256 checksum live in:

```text
srcpkgs/librewolf/template
```

CI verifies cached source archives before using them. A cache hit is not trusted merely because the cache key matches; the archive is hashed against the template checksum again.

## Project philosophy

The package follows one rule:

> **Optimize for the machine that will run the browser.**

That means accepting deliberate non-portability where it buys something useful on the target, while keeping downstream source changes narrow enough to audit.

The project does **not** attempt to maximize every theoretical compiler setting. `-O2`, Rust ThinLTO, PGO, full LLVM LTO, Skylake tuning, and the memory/HDD runtime preferences are chosen as a combined profile for this particular hardware rather than as independent benchmark tricks.

## Upstream references

- LibreWolf: https://librewolf.dev/
- Void Firefox packaging: https://github.com/void-linux/void-packages/tree/master/srcpkgs/firefox
- Mozilla Firefox build system: https://firefox-source-docs.mozilla.org/build/buildsystem.html
