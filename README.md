# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal, hardware-specific LibreWolf packaging for one real deployment target:

- **OS:** Void Linux x86_64-musl
- **CPU:** Intel Core i3-6100U / Skylake, 2 cores / 4 threads
- **RAM:** 4 GB DDR3
- **Storage:** HDD
- **Session:** Wayland
- **Architecture:** x86_64-musl
- **CPU baseline:** Skylake
- **Package:** LibreWolf
- **Current source configured here:** LibreWolf 157.0, source revision 1
- **Void package revision:** 6

This repository is intentionally **not** a generic x86_64 LibreWolf package. The binary is tuned for the machine that will actually run it. Portability to older CPUs and unrelated x86_64 systems is not a project goal.

The main priorities are:

1. **Fast runtime on the target Skylake laptop.**
2. **Low memory pressure on a 4 GB system.**
3. **Low unnecessary HDD activity.**
4. **Fast GitHub Actions builds.**
5. **Aggressive use of CI CPU/RAM for compilation, PGO, LTO, and linking.**
6. **Reuse of expensive build products across repeated builds.**
7. **Small, auditable downstream changes.**

Project security hardening is not the primary optimization target; the project mainly inherits the security model and packaging conventions of LibreWolf, Mozilla Firefox, and Void Linux where practical.

---

## Target hardware and why it is hard-coded

The package is deliberately restricted to `x86_64-musl`:

```text
x86_64-musl
```

The compiler profile is deliberately restricted to Skylake:

```text
-march=skylake -mtune=skylake
```

Rust is targeted at the same CPU:

```text
-C target-cpu=skylake
```

That means the resulting package should be treated as a **machine-specific build**. This is intentional.

The target has only two physical CPU cores, four hardware threads, 4 GB RAM, and an HDD. The build machine is therefore deliberately different from the runtime target: GitHub Actions is used to spend much more CPU and memory on compilation than the laptop can afford.

---

# Runtime optimization profile

The runtime profile is designed around the actual constraints of the deployment system rather than generic Firefox defaults.

`srcpkgs/librewolf/files/vendor.js` currently contains:

```text
browser.tabs.unloadOnLowMemory = true
browser.low_commit_space_threshold_mb = 384
browser.low_commit_space_threshold_percent = 10

browser.sessionstore.interval = 30000

browser.newtab.preload = false

browser.cache.disk.max_chunks_memory_usage = 16384
browser.cache.disk.max_priority_chunks_memory_usage = 16384

dom.ipc.processCount = 4
dom.ipc.processPrelaunch.fission.number = 1
```

## What these are trying to accomplish

### 4 GB RAM

The browser is encouraged to unload background tabs and start memory-pressure handling earlier rather than waiting until the machine is already close to an OOM condition.

The shared content-process pool is limited to four processes, matching the four logical CPUs while avoiding unnecessary process fan-out on a 4 GB machine.

Only one Fission content process is prelaunched. The goal is to avoid maintaining more idle browser state than the hardware can comfortably support.

### HDD

Session-store writes are moved to a 30-second interval to reduce needless write activity while retaining session recovery.

New-tab preload is disabled so opening or creating a new tab does not automatically cause an extra preload workload when it is not useful.

Disk-cache memory buffers are bounded so disk caching does not consume an excessive amount of RAM merely to accelerate an HDD.

These settings are intentionally biased toward **memory stability, HDD behavior, and perceived responsiveness** on this particular machine.

They are not claimed to be optimal for every Firefox installation.

---

# Compiler and linker optimization

## C/C++

The target build uses:

```text
-O2 -march=skylake -mtune=skylake
```

`-march=skylake` permits code generation for the actual CPU ISA rather than maintaining compatibility with much older x86_64 processors.

`-mtune=skylake` adds the corresponding instruction-scheduling and microarchitectural tuning.

`-O2` is intentional. The project does not blindly switch to `-O3` because maximum optimization level is not automatically equivalent to maximum real-world performance. Larger code, greater instruction-cache pressure, build time, memory use, and workload-dependent tradeoffs matter on a 4 GB machine.

## Rust

Rust uses:

```text
-C target-cpu=skylake
RUSTC_OPT_LEVEL=2
```

The Rust compiler therefore targets the same microarchitecture as the C/C++ side.

## Clang / LLVM / LLD

The package currently uses:

- **Clang 22**
- **LLVM 22**
- **LLD 22**

The package deliberately prefers the LLVM toolchain because the build also relies on LLVM-based PGO and LTO.

---

# LTO

The final build enables cross-language/full LLVM LTO when the `lto` build option is enabled, and that option is enabled by default.

The intended optimization chain is:

```text
C/C++
       -> LLVM/LLD -> whole-program optimization
   /
Rust
```

Rust is additionally forced through the downstream `lto-thin.patch` to use Rust ThinLTO rather than Rust fat/full LTO for the top-level Rust integration.

The reasoning is practical:

- retain cross-language optimization
- reduce the cost and fragility of Rust fat-LTO
- avoid an unnecessarily expensive link strategy
- let LLD perform the final global optimization work

The final LLD stage also uses parallel threads and partitions:

```text
-Wl,--threads=<runner CPUs>
-Wl,--lto-O2
-Wl,--lto-partitions=<runner CPUs>
```

The number of LTO workers is taken from the **CI runner**, not from the target laptop. Compilation and linking therefore exploit the larger build environment instead of being constrained by the i3-6100U.

---

# PGO

PGO is enabled by default.

The project intentionally uses PGO because this is a real target-specific build and the goal is runtime performance rather than minimizing build complexity.

## PGO sequence

On a profile-cache miss, CI:

1. starts a headless Weston compositor on the GitHub runner
2. exposes the compositor socket through xbps-src's `/host` bind mount
3. performs the instrumented LibreWolf build
4. runs the Firefox/LibreWolf PGO workload against **Wayland**
5. collects `merged.profdata`
6. collects the PGO jarlog
7. clobbers the instrumented object directory
8. performs the final profile-use build

The CI path explicitly marks Wayland PGO as required.

The relevant runtime path is:

```text
GitHub runner
    |
    +-- Weston headless compositor
    |
    +-- void-packages/hostdir/pgo-runtime
                 |
                 +-- /host/pgo-runtime
                          |
                          +-- Wayland socket
                                   |
                                   v
                           LibreWolf PGO workload
```

This matters because the package itself is built inside the xbps chroot while Weston is installed and run by the outer GitHub Actions environment.

## Manual PGO fallback

When building manually outside CI, the package retains an X11/Xvfb fallback so PGO can still be generated when no Wayland compositor is available.

CI does not silently fall back to X11 when its Wayland compositor is expected.

---

# PGO cache

PGO generation is one of the most expensive phases of the build, so its outputs are cached.

The cached files are:

```text
merged.profdata
jarlog
```

The cache key includes:

- LibreWolf source SHA-256
- the configured PGO cache version
- the package template contents
- all downstream patch contents

The intent is:

```text
same source + same recipe + same patches
        |
        +--> reuse PGO profile
        |
        +--> skip instrumented build
        +--> skip profile-generation workload
        +--> go directly to final profile-use/LTO build
```

`LIBREWOLF_PGO_CACHE_VERSION` exists so the workload can be invalidated deliberately when the PGO strategy changes.

---

# Build acceleration and caching

Build speed is a first-class goal.

## sccache

The package uses Void's packaged:

```text
rust-sccache
```

It is declared as a real `hostmakedepends`, rather than copying an unmanaged binary into the xbps masterdir.

That distinction matters because xbps-src can clean and reconstruct the masterdir while resolving/building dependencies.

The cache hierarchy is:

```text
fast local disk cache
        |
        v
GitHub Actions cache
```

Current relevant settings are:

```text
SCCACHE_CLIENT_SIDE=false
SCCACHE_DIR=/host/sccache
SCCACHE_CACHE_SIZE=16G
SCCACHE_CACHE_ZSTD_LEVEL=1
SCCACHE_IDLE_TIMEOUT=0

SCCACHE_MULTILEVEL_CHAIN=disk,gha
SCCACHE_MULTILEVEL_WRITE_ERROR_POLICY=ignore
```

### Why server mode is explicit

Firefox can choose sccache client-side mode through its own configure/build defaults.

This repository explicitly forces server mode because the project depends on reliable multi-level cache behavior, especially reliable use of the local L1 disk cache.

### Why the daemon never idles out

A normal sccache daemon can shut down after an idle interval.

This build has a long PGO/profile-generation gap between compiler-heavy phases, so:

```text
SCCACHE_IDLE_TIMEOUT=0
```

keeps the same sccache server alive through the whole build.

### Why compression is level 1

The build spends a large amount of CPU time compiling Firefox. The local cache is intentionally compressed with zstd level 1 so cache operations consume less CPU.

The goal is to make cache hits cheap rather than maximizing compression ratio.

### Cache write failures

Remote cache write failures are treated as non-fatal.

The build should remain a successful compiler/package build even if GitHub's cache service is temporarily unavailable.

The local cache remains the fast first level.

---

# Source cache

The LibreWolf source archive is cached using its SHA-256 checksum.

The workflow does not blindly trust a cache hit.

Even on a cache hit, the archive is hashed again against the checksum recorded in:

```text
srcpkgs/librewolf/template
```

The source path is therefore:

```text
restore
  -> verify SHA-256
  -> build
```

rather than:

```text
restore
  -> assume cache is correct
```

---

# Void binary-package cache

The workflow also caches the target architecture's xbps binary repository cache.

This primarily reduces repeated:

- bootstrap package downloads
- dependency repository traffic
- dependency installation/setup work

The cache is keyed from the xbps-src/bootstrap inputs rather than tied to the LibreWolf source archive.

The intended result for repeated builds is:

```text
fresh runner
   |
   +-- restore source
   +-- restore PGO profile
   +-- restore Void binary packages
   +-- bootstrap mostly from cache
   +-- compile from sccache
```

---

# GitHub Actions build architecture

The repository deliberately uses GitHub Actions as the heavy build machine.

The target laptop does **not** perform the LibreWolf compilation.

The runner is used for:

- CPU-intensive C/C++ compilation
- Rust compilation
- PGO
- LLVM LTO
- LLD linking
- source/archive caching
- sccache
- packaging

The workflow defaults to:

```text
ubuntu-24.04
```

but supports a repository variable override:

```text
LIBREWOLF_RUNNER
```

The job has a large time budget because LibreWolf + PGO + LTO is intentionally expensive.

The concurrency policy cancels obsolete builds on the same branch. This prevents an old multi-hour build from continuing after a newer source or recipe change has already superseded it.

---

# CI workflow

The current workflow is approximately:

```text
push/manual dispatch
        |
        v
free runner disk space when necessary
        |
        v
checkout this repository
        |
        v
checkout current Void void-packages
        |
        v
overlay LibreWolf package
        |
        v
validate template
        |
        +--> restore PGO cache
        |
        +--> restore Void binary-package cache
        |
        v
prepare static xbps
        |
        +--> install Weston only on PGO-cache miss
        |
        v
bootstrap xbps-src
        |
        +--> save Void package cache
        |
        v
prepare sccache runtime
        |
        v
restore/fetch/verify source
        |
        v
build package
        |
        +--> PGO profile generation on cache miss
        +--> final PGO + LTO + Skylake build
        |
        v
save PGO profile if newly generated
        |
        v
checksum packages/repository metadata
        |
        v
publish release tag
        |
        v
create/update release
        |
        v
upload XBPS artifacts
```

---

# Template validation

`.github/scripts/validate-template.sh` exists to catch cheap mistakes before the expensive build begins.

It currently checks:

- template syntax with `bash -n`
- expected package name
- LibreWolf version syntax
- positive Void package revision
- source revision format
- SHA-256 format
- exactly one source archive
- HTTPS source URL
- expected LibreWolf source archive filename

It also exports normalized metadata to GitHub Actions:

```text
sha256
distfile
version
rev
release_tag
```

This replaces several earlier inline shell validation attempts and avoids repeating fragile metadata parsing inside the workflow.

---

# Package build configuration

Default build options are:

```text
alsa
dbus
pulseaudio
wayland
lto
pgo
clang
wasi
```

The template also exposes:

```text
jack
xscreensaver
sndio
debug
```

The package is intentionally optimized around Wayland and the actual target system.

The configured package uses system libraries where supported by the Void/Firefox build integration, including:

- NSS
- NSPR
- pixman
- libjpeg-turbo
- libevent
- libwebp
- zlib
- system FFI

The package also keeps several upstream/runtime choices deliberately disabled or constrained, including:

- updater
- crash reporting
- telemetry/data-reporting components
- cargo incremental compilation
- tests during this package build
- jemalloc on this target
- elf-hack where required by the target configuration

The package also disables installation stripping through Firefox's build configuration. This follows the current packaging assumptions used around the Firefox build and is not currently changed merely to save disk space.

---

# musl and Void compatibility

The package is built against Void Linux's musl environment.

The downstream patch set is deliberately narrow.

Current patches are:

### `firefox-146-musl-linux-sys-prctl-conflict.patch`

Avoids the musl conflict caused by combining Linux and musl `prctl` definitions in WebRTC.

### `firefox-148-mach-clobber.patch`

Keeps Firefox's `mach clobber` environment helper working with the source layout used by this LibreWolf packaging.

### `fix-fortify-system-wrappers.patch`

Adjusts generated system-header handling for the musl/system-wrapper environment.

### `librewolf-157-audio_thread_priority-musl.patch`

Adapts `pthread_t` serialization in `audio_thread_priority`.

glibc and musl do not represent `pthread_t` identically, so the patch serializes through `usize` to retain a stable-width representation.

### `llvm22.patch`

Updates the WASI triplet expected by LLVM 22 from the older `wasm32-wasi` naming to the current `wasm32-wasip1` target.

### `lto-thin.patch`

Forces Rust ThinLTO in the cross-language LTO path instead of Rust fat-LTO.

### `mallinfo.patch`

Avoids glibc-specific memory-reporting code where it does not apply to musl.

### `parakeet-missing-cstdint.patch`

Adds the missing C++ standard header needed by the Parakeet code.

### `sandbox-sched_setscheduler.patch`

Adjusts the Linux sandbox syscall handling for musl, following the relevant upstream bug/workaround.

Most of these patches are synchronized with corresponding current Void Firefox patches where possible rather than being broad LibreWolf forks.

---

# Removed/obsolete fixes

The repository previously carried a Firefox 152-era missing-`cstdint` patch.

That patch was removed after the needed include appeared upstream in the Firefox/LibreWolf source:

```text
firefox-152-missing-cstdint-include.patch
```

Keeping obsolete patches would increase maintenance cost and make future source updates more fragile.

The same principle is used for the rest of the patch set: a patch should remain only while it is required by the selected source/toolchain/target.

---

# musl-specific build adjustments

The package also removes the musl-incompatible `sys/single_threaded.h` entry from Firefox's generated system-header set:

```text
config/system-headers.mozbuild
```

The Breakpad `stab.h` compatibility file is installed for musl builds.

The package writes the Mozilla API key expected by the Void/Firefox packaging flow into the source tree during extraction.

---

# Target-specific packaging

The package intentionally rejects non-`x86_64-musl` targets:

```text
case "$XBPS_TARGET_MACHINE" in
    x86_64-musl) ;;
    *) broken="only supported on x86_64-musl" ;;
esac
```

This prevents accidentally publishing a package that was optimized for Skylake while being presented as a portable x86_64 binary.

---

# Why the build has both PGO and LTO

The optimization stack is deliberate rather than a pile of unrelated compiler flags.

The intended chain is:

```text
Skylake ISA tuning
        +
PGO workload
        +
cross-language LTO
        +
Rust ThinLTO
        +
LLD
        =
target-specific optimized binary
```

PGO tells the compiler which paths matter for the representative workload.

LTO allows optimization across translation-unit and language boundaries.

Skylake tuning lets the compiler generate code for the actual target CPU.

These optimizations complement one another, which is why they are kept together.

---

# Why the build is not tuned to the target CPU count

The final binary is tuned to the target CPU.

The **build process** is not.

The target has 2 cores / 4 threads, but GitHub Actions is expected to provide considerably more resources.

Therefore:

- compilation uses CI parallelism
- Rust compilation uses CI resources
- PGO generation uses CI CPU
- LLD uses CI LTO threads/partitions
- sccache uses CI storage
- caches are designed for repeated CI execution

The laptop does not need to pay the cost of its own package compilation.

---

# Release and artifact model

The workflow publishes:

- XBPS packages
- repository metadata
- SHA-256 checksums
- SHA-512 checksums

The release tag is derived from:

```text
<LibreWolf version>-<source revision>
```

For the current recipe that is:

```text
157.0-1
```

The Void package revision is tracked separately in the template.

Rebuilding the same LibreWolf source revision may deliberately update the same release tag. This is acceptable for a personal package repository.

The project is not trying to preserve every intermediate build as an immutable release artifact.

XBPS package signing is not configured as a shared Void trust chain.

---

# Source integrity

The source version, source revision, archive URL, and SHA-256 checksum are kept in:

```text
srcpkgs/librewolf/template
```

CI verifies the actual downloaded/cached archive against that checksum before building.

The source cache therefore remains an optimization only; it is not treated as an authority over the template's checksum.

---

# Repository layout

```text
.github/
├── scripts/
│   └── validate-template.sh
└── workflows/
    └── main.yml

srcpkgs/
└── librewolf/
    ├── template
    ├── files/
    │   ├── librewolf.desktop
    │   ├── stab.h
    │   └── vendor.js
    └── patches/
        ├── firefox-146-musl-linux-sys-prctl-conflict.patch
        ├── firefox-148-mach-clobber.patch
        ├── fix-fortify-system-wrappers.patch
        ├── librewolf-157-audio_thread_priority-musl.patch
        ├── llvm22.patch
        ├── lto-thin.patch
        ├── mallinfo.patch
        ├── parakeet-missing-cstdint.patch
        └── sandbox-sched_setscheduler.patch
```

---

# Build history and lessons learned

The CI history drove several of the current design decisions.

## sccache binary disappeared during xbps-src cleanup

An early build copied an unmanaged sccache binary into the xbps masterdir.

`xbps-src` later cleaned/reconstructed the masterdir and removed that binary.

### Lesson

sccache must be a real Void package dependency:

```text
rust-sccache
```

not a manually injected file.

---

## Firefox configure could not find sccache

An earlier configuration passed:

```text
--with-ccache=sccache
```

Firefox's configure logic attempted to resolve that program and failed.

### Fix

The current build passes the concrete path:

```text
--with-ccache=/usr/bin/sccache
```

and also sets:

```text
RUSTC_WRAPPER=/usr/bin/sccache
```

---

## Obsolete Firefox patch failed

A Firefox 152-era missing-`cstdint` patch was still applied after upstream had already added the include.

The patch was removed.

### Lesson

Source-version-specific patches must be audited against every LibreWolf/Firefox source update.

---

## Metadata validator failures

Several early CI attempts contained fragile inline shell metadata validation:

- validation before derived values were assigned
- stray shell braces
- URL-basename checking against the wrong value

### Fix

The validation logic was extracted into:

```text
.github/scripts/validate-template.sh
```

and now runs syntax/metadata validation before the expensive build.

---

## GitHub runtime cache credentials were not visible to Bash

Build #73 failed after xbps bootstrap because:

```text
ACTIONS_RESULTS_URL
ACTIONS_RUNTIME_TOKEN
```

were not available as normal exported Bash variables in the step that attempted to write the sccache environment.

### Fix

The workflow now uses `actions/github-script` to retrieve the runtime values and writes them into the xbps `/host` environment file.

---

## PGO/Wayland needed to cross the xbps boundary

The runner's Weston process was outside the package build chroot.

### Fix

Weston writes its runtime socket into the xbps hostdir bind mount:

```text
hostdir/pgo-runtime
```

which becomes:

```text
/host/pgo-runtime
```

inside the build.

This makes the Wayland PGO path deterministic in CI.

---

## Rebuilding identical PGO profiles was wasteful

PGO generation is expensive.

### Fix

PGO artifacts are cached and reused when the source and recipe are unchanged.

---

# Performance priorities

The project deliberately optimizes in this order:

## 1. Runtime speed on the actual target

The final package should execute efficiently on Skylake.

## 2. Memory behavior

The 4 GB RAM constraint is important enough to influence browser process and tab behavior.

## 3. HDD behavior

The system has an HDD, so unnecessary disk writes and memory consumption are considered performance problems.

## 4. Build throughput

GitHub Actions is used aggressively so the target machine never needs to compile Firefox itself.

## 5. Repeat-build reuse

PGO, sccache, source archives, and Void packages are cached.

## 6. Maintenance simplicity

Optimization should not come from an unreviewable pile of custom patches and shell hacks.

---

# Things this project deliberately does not do

The project does **not** try to:

- support arbitrary x86_64 CPUs
- maintain glibc and musl variants
- preserve generic distribution portability
- maximize every theoretical compiler flag
- replace PGO with unverified microbenchmarks
- keep stale downstream patches merely for historical reasons
- run the full Firefox test suite as part of every personal package build
- make GitHub Actions security hardening the main project goal
- treat every benchmark result as proof that a flag improves real-world browser performance

---

# Current tradeoffs

This package intentionally accepts several tradeoffs:

### Portability

The package is less portable because it targets Skylake.

### Build time

PGO + LTO is expensive.

That cost is paid in GitHub Actions rather than on the laptop, and caching reduces the cost of subsequent builds.

### Binary size

Full optimization and disabled stripping choices can increase artifact size compared with a generic distribution package.

### Patch maintenance

musl/LLVM/source-version compatibility requires a small downstream patch set.

The repository intentionally keeps the patch surface narrow to make these updates manageable.

### PGO representativeness

The PGO workload is a scripted Firefox profile-server workload, not the complete behavior of one human using the browser.

It is therefore a useful representative profile, not a perfect model of every browsing workload.

---

# Updating LibreWolf

When changing the LibreWolf source:

1. Update `version`.
2. Update `_rev` when the source revision changes.
3. Update `checksum`.
4. Bump `revision` for package-only recipe changes.
5. Audit every downstream patch.
6. Remove patches that are now upstream.
7. Add only the narrow compatibility patches required for the new source/toolchain.
8. Run the CI build.
9. Inspect PGO and sccache behavior, not only the final compiler result.

The source checksum is authoritative for the configured archive.

If the PGO workload or PGO assumptions change substantially, bump:

```text
LIBREWOLF_PGO_CACHE_VERSION
```

If the sccache namespace becomes incompatible, bump:

```text
SCCACHE_GHA_VERSION
```

Those version variables are deliberate cache invalidation controls.

---

# Working philosophy

The project follows one rule:

> **Optimize the package for the machine that will run it, and optimize the build for the machine that builds it.**

That means:

```text
TARGET MACHINE
    -> Skylake code generation
    -> 4 GB memory profile
    -> HDD-aware runtime settings
    -> Wayland
    -> low unnecessary process/disk overhead

CI BUILDER
    -> high parallelism
    -> Clang/LLVM/LLD
    -> PGO
    -> full LTO
    -> Rust ThinLTO
    -> sccache
    -> source cache
    -> PGO cache
    -> Void binary-package cache
```

The two environments have different jobs.

The laptop is the runtime target.

GitHub Actions is the compilation machine.

---

# Upstream references

- LibreWolf: https://librewolf.dev/
- LibreWolf source releases: https://librewolf.dev/librewolf/source/releases
- Void Linux: https://voidlinux.org/
- Void packages: https://github.com/void-linux/void-packages
- Void Firefox package: https://github.com/void-linux/void-packages/tree/master/srcpkgs/firefox
- Mozilla Firefox build system: https://firefox-source-docs.mozilla.org/build/buildsystem.html
- Mozilla sccache: https://github.com/mozilla/sccache
- Firefox build configuration: https://firefox-source-docs.mozilla.org/setup/configuring_build_options.html

---

# Repository intent

This is a personal LibreWolf build profile, not an attempt to become a universal Void package.

The important result is a package built from the configured LibreWolf source with:

- Skylake-specific code generation
- LLVM/Clang/LLD
- full cross-language LTO
- Rust ThinLTO
- PGO
- Wayland-targeted PGO in CI
- sccache
- reusable source, PGO, and Void package caches
- 4 GB/HDD runtime tuning
- musl-specific compatibility fixes
- a small, auditable downstream patch set

The project is intentionally specialized.
