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

## Commit history — condensed

The history below covers the changes that produced the current design; repeated documentation/cache iterations are grouped where their purpose was the same.

### LibreWolf 157 and target restriction

- `8e34e357` — update to LibreWolf 157.0-1.
- `05987cf1` — restrict the package to x86_64-musl/Skylake.
- `3ec84e83` — enable SIMD and preserve build flags.
- `2825153c` — preserve inherited linker flags.
- `7facc09c` — reduce default build cost for the low-memory target.
- `7bc6c772`, `dab3da3c` — add/tune the Skylake low-memory optimization profile.

### musl and build fixes

- `7a574d6b`, `950c662e` — fix `audio_thread_priority` on musl and trim cross-build logic.
- `9ecd4f07` — add musl Rust target detection.
- `8b12ceb7` — remove the duplicate musl audio patch.
- `baa08990` — remove an unused ARM-musl workaround.
- `9549b31d`, `9f9f06cd` — fix Parakeet's missing `cstdint` include and bump the revision.
- `1791ac61`, `31725e67`, `80aa4fab`, `b1cf842f`, `11bd6997` — remove unused cross-architecture patches.

### PGO / LTO / compiler optimization

- `3d58344d` — introduce ThinLTO for lighter PGO builds.
- `1e6c09ff` — skip LTO during PGO instrumentation.
- `c24c5651`, `be7b17e4`, `97559b39` — parallelize and normalize ThinLTO/sccache behavior.
- `44eda074` — enable full PGO + LTO by default.
- `a7230c27` — parallelize full-LTO code generation.
- `4ad30da0` — enable full cross-language LTO and optimized Rust.
- `3314273d` — tune LTO/Rust for resource efficiency.
- `f2cd68a5` — preserve SQLite semantic interposition under full LTO.
- `82a139bd` — preflight the SQLite full-LTO link before the expensive PGO cycle.
- `94776350` — fix the SQLite LTO patch application.

### CI reliability and security

- `f7fe5afd`, `fcb37e12` — add and integrate sccache.
- `69450061` — build only x86_64-musl with full runner parallelism.
- `17923eaa` — move the runner to Ubuntu 24.04.
- `edb7e7cc`, `3a1fb041` — handle Ubuntu AppArmor user-namespace restrictions and restore the original setting afterward.
- `302e18ff` — tighten cache, credentials, fetch and build parallelism.
- `85eade5e`, `caded680` — disable unnecessary checkout credential persistence.
- `d7752982` — bound build/source-fetch failure time.
- `443a3171` — bound PGO profile-generation time.

### Source-cache evolution

- `fd9e50c1` — add a verified segmented source-fetch helper.
- `1331fe92`, `24b8ba3f` — introduce and warm checksum-addressed persistent source caching.
- `b8295213`, `2d7da369`, `9e198460` — improve/document the cache workflow.
- `c457209b` — replace the unreliable aria2 fetch path with curl caching.
- `9006cd79`, `c9ab54ff`, `239037a4`, `1f4dd87d` — iterate on persistent cache warming and cost bounds.
- `3a6ec511`, `3781cc45` — fix source URL placeholder expansion.
- `24b8ba3f`, `f57b69f8`, `ddc4422a` — remove the custom fetch path and fold caching into native `xbps-src` handling.
- `82625b76` — document the simplified CI.
- `bf92024c` — remove the redundant standalone source-cache workflow.
- `7535004a` — remove obsolete distfile URL parsing.

The final design intentionally keeps the cache simple: `xbps-src` owns downloading and verification; GitHub Actions only avoids downloading the same verified archive repeatedly.

### Release/signing changes

- `ed6f3543` — remove XBPS signing from the release workflow.
- `c571efd9` — remove signing verification.
- `f73b7e49` — make `master` builds own the release tag.
- `11bfd009` — use authenticated Git push for tag synchronization after the REST-ref method failed.

### Documentation

- `aaea0ddc`, `3ba346c0`, `5e1c01ca`, `07fc1d1d`, `45382661`, `fe630e79`, `82625b76`, `d08cac5f` — progressively document the project's purpose, target hardware, resource-efficient optimization profile, simplified CI, and native full LTO vs Rust Thin LTO.

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
