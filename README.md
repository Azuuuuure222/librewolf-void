# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal, hardware-specific LibreWolf packaging for **Void Linux x86_64-musl**.

**Target:** Intel Core i3-6100U / Skylake, 4 GB DDR3, HDD, Wayland.  
**Build:** GitHub Actions / Ubuntu 24.04 using Void `xbps-src`.

The package intentionally trades portability for optimization on the target machine and is limited to `x86_64-musl` / Skylake-class CPUs.

## Build profile

- C/C++: `-O2 -march=skylake -mtune=skylake`
- Rust: Skylake `target-cpu`, SIMD, optimization level 2, Thin LTO
- Clang + LLVM 22 + LLD
- Full native cross-language LLVM LTO for the final build
- PGO enabled by default; instrumentation omits LTO, final profile-use build restores it
- Headless Wayland PGO workload through Weston, with X11/Xvfb fallback
- Parallel LTO code generation
- `sccache` compiler caching
- Release/debug configuration avoids unnecessary crash reporting, updater, telemetry, debug symbols, and development features

`-O2` and Rust Thin LTO are preferred over more aggressive settings because the deployment target has 4 GB RAM and an HDD.

## Runtime tuning

The package is tuned for low-memory, HDD-heavy use:

- 4 shared web-content processes
- 1 Fission preallocated content process
- Earlier low-memory reclamation and background-tab unloading
- Less frequent session-store writes
- New-tab preload disabled
- Smaller disk-cache memory buffers

## musl / Void compatibility

The package carries target-specific fixes for:

- musl Linux header conflicts
- `audio_thread_priority` musl compatibility
- `mach clobber` compatibility
- missing `<cstdint>` includes
- fortify/system-wrapper compatibility
- LLVM 22 compatibility
- `mallinfo` compatibility
- sandbox `sched_setscheduler` compatibility
- full-LTO semantic-interposition handling for SQLite
- full-LTO semantic-interposition handling for bundled FFvpx shared libraries

Cross-architecture and obsolete workarounds are intentionally avoided.

## Source integrity

The source version, source revision, package revision, distfile URL, and SHA-256 checksum are defined in `srcpkgs/librewolf/template`.

The CI validates the metadata before building and uses Void's `xbps-src fetch` for source retrieval and checksum verification.

The verified source archive is cached by SHA-256 using Void's actual layout:

`void-packages/hostdir/sources/<pkgname>-<version>/<distfile>`

Cache hits are verified directly and skip redundant fetching.

## CI design

The workflow:

1. Frees runner disk space.
2. Checks out this repository and current Void `void-packages`.
3. Overlays `srcpkgs/librewolf` into Void's package tree.
4. Validates package metadata.
5. Prepares static XBPS tools and the PGO compositor.
6. Enables the user namespaces required by `xbps-src`.
7. Bootstraps `xbps-src`.
8. Restores or fetches and verifies the source archive.
9. Builds with all available CPUs.
10. Checksums generated packages and repository metadata.
11. Publishes the release tag only after a successful build.
12. Creates/uploads the release and marks it latest.

Build, bootstrap, fetch, and PGO stages have explicit time limits. Workflow concurrency cancels obsolete builds.

Tags are published by the successful master build; tag pushes do not trigger another full build.

## Release and packaging model

Package and release identifiers are derived from the template rather than hardcoded in CI.

The repository is a personal package repository and does not use XBPS signing as a shared Void trust chain.

The build is optimized for the target rather than designed as a reproducible or portable distribution build.

## Project philosophy

**Optimize for the machine that will run the browser.**

Priorities are:

- exploit known Skylake features
- control memory pressure on 4 GB RAM
- reduce HDD activity
- use PGO/LTO where their runtime value justifies the CI cost
- keep musl changes narrow and auditable
- fix third-party full-LTO issues with targeted exceptions instead of disabling useful optimizations globally
- prefer native Void `xbps-src` mechanisms

## Primary upstream references

- LibreWolf: https://librewolf.dev/
- Void Firefox package: https://github.com/void-linux/void-packages/tree/master/srcpkgs/firefox
- Mozilla Firefox build system: https://firefox-source-docs.mozilla.org/build/buildsystem.html
