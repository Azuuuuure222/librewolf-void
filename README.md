# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal, hardware-specific LibreWolf packaging for **Void Linux x86_64-musl**.

Target: **Intel Core i3-6100U (Skylake), 4 GB DDR3, HDD, Wayland**. The browser is **compiled on GitHub Actions**, not on the target machine.

## Target

| Item | Value |
|---|---|
| CPU | Intel Core i3-6100U / Skylake |
| Architecture | x86_64 |
| libc | musl |
| RAM | 4 GB DDR3 |
| Storage | HDD |
| Display | Wayland-focused |
| Build host | GitHub Actions / Ubuntu 24.04 |
| Build system | Void `xbps-src` |
| LibreWolf | 157.0-1 |
| Use | Personal |

The package intentionally gives up portability and generic benchmark optimization in favor of behavior suited to this machine. Pre-Skylake CPUs and other architectures are outside the scope.

## Build profile

- C/C++: `-O2 -march=skylake -mtune=skylake`.
- Rust: `target-cpu=skylake`, Rust SIMD, optimization level 2.
- Clang + LLVM 22 + LLD.
- **Full native cross-language LLVM LTO** for the final build.
- Rust uses **Thin LTO** to keep compiler memory use and build time reasonable.
- **PGO** is enabled by default; the instrumented build skips LTO to reduce profile-generation cost.
- PGO uses a headless Wayland compositor in CI when available, with X11 fallback.
- LTO code generation is parallelized across the CI runner.
- `sccache` provides compiler caching.

### Why these choices?

PGO + full native LTO is expensive, but it is useful for a long-lived personal binary: PGO focuses optimization on hot paths and LTO enables whole-program optimization. `-O2` is preferred over `-O3` because this target has only 4 GB RAM; the extra compile cost, memory pressure and possible code-size growth are not worth optimizing for benchmark peaks. Rust Thin LTO makes the same trade during the Rust portion of the build.

## Runtime tuning

Defaults are tuned for **4 GB RAM + HDD**:

- 4 shared web-content processes instead of Firefox's larger general-purpose default.
- 1 Fission preallocated content process.
- Earlier low-memory reclamation and background-tab unloading.
- Less frequent session-store writes to reduce HDD activity.
- New-tab preload disabled.
- Smaller disk-cache memory buffers to cap transient RAM usage.

The goal is lower memory pressure and disk churn without excessively restricting normal browser behavior.

## musl / Void compatibility

The package is intentionally limited to `x86_64-musl` and carries target-relevant LibreWolf/Firefox fixes, including:

- musl Linux header conflict handling;
- Firefox 157 `audio_thread_priority` musl compatibility;
- `mach clobber` build compatibility;
- Parakeet missing `<cstdint>` include;
- fortify/system-wrapper compatibility;
- LLVM 22 target compatibility;
- `mallinfo` compatibility;
- sandbox `sched_setscheduler` compatibility;
- SQLite full-LTO semantic-interposition handling.

Unused or duplicate cross-architecture/musl workarounds were removed instead of being carried indefinitely.

## Source and integrity

LibreWolf **157.0-1** is built from the official LibreWolf source archive.

Required source SHA-256:

`bea3cc7c57f3fb8928d583a0603b0f40130b02f662e032746345a51e0f55ffb3`

The workflow rejects a missing or malformed checksum before the build. Void's `xbps-src fetch` performs the actual source retrieval and checksum verification. The verified archive is additionally cached using its SHA-256 as the cache key.

## CI design

The single build workflow:

1. Frees runner disk space.
2. Checks out this repository and Void `void-packages`.
3. Validates package metadata and the mandatory SHA-256.
4. Derives and synchronizes the `157.0-1` release tag.
5. Creates the GitHub release when necessary.
6. Prepares static `xbps` and the PGO Wayland compositor.
7. Bootstraps `xbps-src` for `x86_64-musl`.
8. Restores the checksum-addressed LibreWolf source cache.
9. Fetches/verifies the source through `xbps-src` when the cache misses.
10. Builds with all available runner CPUs.
11. Generates SHA-256/SHA-512 checksums for packages.
12. Uploads `.xbps` packages and repository metadata to the release.

Failure paths are bounded: bootstrap, source fetch, PGO profiling and the complete package build have explicit time limits. Workflow concurrency cancels obsolete builds when a newer build supersedes them.

XBPS signing was removed because this is a personal package repository; it is not intended to establish a shared Void package-signing trust chain.

## Release model

`master` is the working branch. The package version and revision produce the release tag (`157.0-1`). A `master` build synchronizes that tag to the exact commit being built; the same workflow then publishes the resulting packages.

The project does **not** prioritize reproducible builds. Hardware-specific optimization and a practical personal build are the priorities.

## Project philosophy

**Optimize for the machine that will run the browser, not for generic benchmark charts.**

That means:

- exploit Skylake features because the target is known;
- control memory pressure because the target has 4 GB;
- reduce unnecessary HDD activity;
- use PGO/LTO where the runtime benefit justifies the CI cost;
- avoid `-O3` and fat Rust LTO when their extra resource cost is not justified;
- keep musl patches target-specific;
- make CI failures happen early instead of wasting hours;
- prefer Void's native build mechanisms over custom infrastructure when they are sufficient.

This is a **personal optimized LibreWolf build**, not a general-purpose Void Linux package.
