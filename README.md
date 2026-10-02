# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal, hardware-specific LibreWolf packaging for **Void Linux x86_64-musl**.

Target: **Intel Core i3-6100U / Skylake, 4 GB DDR3, HDD, Wayland**. The browser is compiled on GitHub Actions and installed as a Void XBPS package.

This repository deliberately optimizes for one known machine instead of generic x86_64 portability or benchmark portability.

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
| LibreWolf source | 157.0-1 |
| XBPS package revision | 6 |
| Use | Personal |

The package is intentionally limited to `x86_64-musl` and Skylake-class CPUs. Pre-Skylake CPUs, other architectures, and generic portable packaging are outside the project's scope.

## Build profile

The final package is built with:

- C/C++: `-O2 -march=skylake -mtune=skylake`.
- Rust: `-C target-cpu=skylake`, Rust SIMD, optimization level 2.
- Clang + LLVM 22 + LLD.
- Full native cross-language LLVM LTO for the final build.
- Rust Thin LTO instead of Rust fat LTO.
- PGO enabled by default.
- PGO instrumented build intentionally runs without LTO; LTO is restored for the profile-use build.
- PGO workload runs through a headless Wayland Weston compositor when available, with X11/Xvfb fallback.
- LTO backend work is parallelized across the CI runner.
- `sccache` is used as the compiler cache.
- Cargo incremental compilation is disabled for the release build.
- Debug symbols, crash reporting, updater, browser agent, telemetry, health reporting, and related development-only features are disabled.

### Why these choices?

PGO + full native LTO is expensive, but it is useful for a long-lived personal binary because PGO concentrates optimization on hot paths while LTO enables whole-program optimization.

`-O2` is retained instead of `-O3` because the runtime target has 4 GB RAM and the project prioritizes memory efficiency, code size, and build practicality over peak synthetic benchmark results. Rust uses Thin LTO for the same reason.

The browser is compiled with Skylake-specific code generation because the deployment CPU is known. This is an explicit portability tradeoff.

## Runtime tuning

The package carries runtime settings intended for **4 GB RAM + HDD**:

- 4 shared web-content processes instead of a larger general-purpose default.
- 1 Fission preallocated content process.
- Earlier low-memory reclamation and background-tab unloading.
- Less frequent session-store writes to reduce HDD activity.
- New-tab preload disabled.
- Smaller disk-cache memory buffers to constrain transient RAM usage.

The objective is to reduce memory pressure and unnecessary disk churn without turning the browser into an artificially restricted single-process configuration.

## musl / Void compatibility

The package carries target-specific compatibility work for the current LibreWolf/Firefox 157 source:

- musl Linux header conflict handling;
- Firefox 157 `audio_thread_priority` musl compatibility;
- `mach clobber` build compatibility;
- Parakeet missing `<cstdint>` include;
- fortify/system-wrapper compatibility;
- LLVM 22 target compatibility;
- `mallinfo` compatibility;
- sandbox `sched_setscheduler` compatibility;
- SQLite full-LTO semantic-interposition handling;
- FFvpx shared-library full-LTO semantic-interposition handling.

Unused or duplicate cross-architecture workarounds are intentionally not carried forward.

## Source and integrity

The package is built from the official LibreWolf **157.0-1** source archive.

Required source SHA-256:

`bea3cc7c57f3fb8928d583a0603b0f40130b02f662e032746345a51e0f55ffb3`

The workflow validates that a single 64-character SHA-256 digest and exactly one distfile URL are present in the template before bootstrapping the build.

Void `xbps-src fetch` performs the actual source retrieval and checksum verification on a cache miss. The verified archive is additionally cached by its SHA-256.

### Source cache layout

A previous workflow revision attempted to cache:

`void-packages/hostdir/sources/librewolf-157.0-1.source.tar.gz`

That path was wrong.

Void stores distfiles under:

`XBPS_SRCDISTDIR/$pkgname-$version/$distfile`

so this package actually uses:

`void-packages/hostdir/sources/librewolf-157.0/librewolf-157.0-1.source.tar.gz`

The GitHub Actions log explicitly reported:

`Path Validation Error: Path(s) specified in the action for caching do(es) not exist, hence no cache is being saved.`

The workflow now caches the correct path with a SHA-256-addressed `librewolf-source-v4-` key.

On a cache hit, the workflow verifies the cached archive directly with `sha256sum` and skips the separate `xbps-src fetch` step. On a miss, it fetches through `xbps-src`, verifies the archive, and then saves it to the exact Void source-cache path.

This avoids both silent cache misses and a redundant network/repository update when the source is already cached.

## CI architecture

The workflow is intentionally single-job and ordered so that cheap correctness checks happen before long compilation:

1. Remove large, irrelevant runner installations and prune Docker images to free disk space.
2. Check out this repository.
3. Check out current Void `void-packages`.
4. Overlay `srcpkgs/librewolf` into Void's package tree.
5. Parse and validate package metadata, version, revision, distfile count, and checksum.
6. Download the current static x86_64-musl `xbps` tools.
7. Ensure Weston is available for the Wayland PGO workload.
8. Enable the Ubuntu runner's unprivileged user namespaces required by `xbps-uunshare`.
9. Bootstrap `xbps-src`.
10. Restore the SHA-256-addressed LibreWolf source cache.
11. Verify the restored archive directly, or fetch and verify it through `xbps-src` on a cache miss.
12. Build LibreWolf with all available runner CPUs.
13. Generate SHA-256 and SHA-512 checksums for every resulting `.xbps` package and repository metadata file.
14. Publish the release tag only after the complete package build and checksum stage succeed.
15. Create the GitHub release and upload package artifacts.
16. Mark the release as latest.

Bootstrap, source preparation, PGO profiling, and the complete package build have explicit time limits.

The workflow has concurrency cancellation enabled so obsolete builds on `master` are cancelled when a newer `master` commit supersedes them.

### Why tags no longer trigger builds

The successful `master` build itself publishes the version/revision tag after the package and checksum stages succeed.

The workflow therefore no longer listens to tag pushes. This prevents the workflow's own tag publication from starting a second, multi-hour LibreWolf build of the exact same commit.

Release publication is now transactional in the practical CI sense: a failed compile cannot move the release tag or create/upload a release.

## Compiler cache behavior

`sccache` is enabled through `mozilla-actions/sccache-action`.

Run #28 produced the following aggregate compiler-cache statistics before failing:

- 4,333 compile requests executed.
- 4,310 compilations.
- 2 cache hits.
- 4,310 cache misses.
- 5 cache errors.
- 29,402 seconds aggregate compiler time across compilation workers.
- 185.8 seconds aggregate cache-write time.

The very low hit rate on that run is expected for a source/build configuration that had just changed and had not yet established useful reusable entries. The cache remains valuable across stable rebuilds, especially after the source and toolchain configuration settle.

## Full-LTO correctness rules

The build globally uses Clang with:

`-fno-semantic-interposition`

because that can improve code generation for ordinary code. Third-party shared libraries that expose default-visible symbols can be incompatible with that assumption under full LTO, however.

Two explicit exceptions are therefore maintained:

### SQLite

SQLite is linked as `libmozsqlite3.so`. The package injects:

`-fsemantic-interposition`

into the SQLite `moz.build` flags when Clang is used.

An earlier attempt tried to preflight SQLite with:

`./mach build config/external/sqlite/target`

That failed immediately because the partial target does not correspond to a usable generated make target in this build configuration. The preflight was removed and replaced with a cheap patch-contract check that verifies the semantic-interposition flag is actually present before the expensive PGO cycle begins.

### FFvpx

The latest analyzed build reached the final PGO-use build and failed while linking Mozilla's bundled FFvpx `libmozavutil.so`:

`R_X86_64_PC32 cannot be used against symbol 'av_buffer_default_free'; recompile with -fPIC`

The same failure repeated for several FFvpx symbols. This is the characteristic result of allowing full-LTO optimization to emit direct PC-relative references to default-visible symbols in a shared library.

A dedicated patch, `srcpkgs/librewolf/patches/ffvpx-semantic-interposition.patch`, therefore adds:

`-fsemantic-interposition`

to the Clang FFvpx compilation flags. This is narrowly scoped to Mozilla's bundled FFvpx code instead of disabling the optimization globally.

## CI failure analysis and fixes

The repository has gone through several concrete CI failures during the current LibreWolf 157 build:

### Run #23 / #24 — missing package overlay

`xbps-src` could not find:

`void-packages/srcpkgs/librewolf/template`

The workflow had lost the historical overlay step. The package tree now explicitly copies:

`srcpkgs/librewolf` → `void-packages/srcpkgs/librewolf`

before metadata validation or any `xbps-src` operation.

### Run #25 — unprivileged user namespace restriction

After the overlay was restored, the build reached source preparation but `xbps-uunshare` failed with:

`ERROR failed to write to /proc/self/uid_map (Operation not permitted)`

The Ubuntu runner's AppArmor user-namespace restriction had been disabled only inside the bootstrap step and then restored before the later fetch/build operations.

The workflow now has a dedicated `allow xbps user namespaces` step before bootstrap, fetch, and build, so the setting remains active for the complete `xbps-src` lifecycle.

### Run #26 — unsupported SQLite preflight

The user-namespace issue was resolved, source fetching succeeded, and the build reached the first `do_build` invocation.

The custom SQLite preflight then failed immediately with:

`No rule to make target '../../../third_party/sqlite3/src/sqlite3.o'`

The invalid partial `mach` target was removed and replaced by a structural validation of the SQLite semantic-interposition workaround.

### Run #28 — FFvpx full-LTO relocation failure

Run #28 is the latest completed build analyzed before the current fixes.

Important progress was achieved before the failure:

- source fetch and checksum verification succeeded;
- the source-cache save step ran, but did not save because the old cache path was wrong;
- the PGO instrumented build completed;
- the browser was packaged for the PGO workload;
- the Wayland PGO workload ran;
- profile data was generated;
- the object directory was clobbered;
- the final PGO-use build reconfigured successfully;
- the failure occurred in the final full-LTO link after roughly 2 hours 24 minutes of wall-clock build time.

The failure was isolated to FFvpx `libmozavutil.so`, not to the PGO machinery itself.

The current FFvpx semantic-interposition patch is the targeted correction.

## Repository optimization work

The repository and CI have been tightened in several areas:

- Restored the explicit Void package overlay.
- Kept the required AppArmor user-namespace relaxation active for all `xbps-src` stages.
- Corrected the LibreWolf source-cache path to match Void's actual `XBPS_SRCDISTDIR` layout.
- Added direct verification of restored cached source archives.
- Skip redundant `xbps-src fetch` work on a valid source-cache hit.
- Moved release publication after the build/checksum boundary.
- Removed the automatic tag trigger to avoid duplicate full builds.
- Reduced the disk-cleanup step to one privileged `rm` invocation.
- Avoided reinstalling Weston when the runner already has it.
- Replaced the unsupported SQLite partial-build preflight with a cheap structural validation.
- Added a narrowly scoped FFvpx full-LTO compatibility patch instead of disabling `-fno-semantic-interposition` globally.
- Kept PGO instrumentation separate from final LTO to reduce profile-generation cost.
- Kept Rust at Thin LTO rather than fat LTO.
- Kept the final optimizer at O2 rather than O3.

The project deliberately prefers targeted exceptions over globally disabling optimization when a third-party shared library has different linkage semantics.

## Release model

`master` is the working branch.

The package metadata contains:

- LibreWolf source version: `157.0`
- LibreWolf source revision: `1`
- XBPS package revision: `6`

The source version/revision produce release tag:

`157.0-1`

A successful `master` build publishes that tag to the exact commit being built, creates the release when necessary, uploads the generated `.xbps` packages and repository metadata, and marks the release as latest.

XBPS signing is intentionally not used because this is a personal package repository and is not intended to establish a shared Void package-signing trust chain.

The workflow is not currently a reproducible-build system: Void `void-packages` follows `master`, the static XBPS archive is fetched from Void's current static endpoint, and the GitHub-hosted build environment is not pinned to an immutable runner image. Hardware-specific optimization and practical personal deployment remain the priorities.

## Current verification state

The latest completed build analyzed was **run #28**. It failed in the final PGO-use FFvpx link for the reason documented above.

The source-cache correction, FFvpx LTO correction, and additional CI optimizations are committed after that run. The next build is therefore the first run that will validate the complete corrected path.

A green build should be treated as unverified until that subsequent run completes successfully.

## Project philosophy

**Optimize for the machine that will run the browser, not for generic benchmark charts.**

That means:

- exploit known Skylake CPU features;
- control memory pressure for 4 GB RAM;
- reduce unnecessary HDD activity;
- use PGO and LTO when their runtime benefit justifies the CI cost;
- avoid `-O3` and Rust fat LTO when their extra resource cost is not justified;
- keep musl compatibility changes narrow and auditable;
- make CI failures happen before expensive compilation whenever a cheap structural check can catch them;
- preserve native Void `xbps-src` behavior rather than replacing it with custom package infrastructure;
- use targeted third-party linkage exceptions instead of globally disabling useful compiler optimizations.

This is a **personal optimized LibreWolf build**, not a general-purpose Void Linux package.

## Primary upstream references

- LibreWolf: https://librewolf.dev/
- Void Linux packages: https://github.com/void-linux/void-packages
- Mozilla Firefox build system: https://firefox-source-docs.mozilla.org/build/buildsystem.html
