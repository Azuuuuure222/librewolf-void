# LibreWolf for Void Linux — Skylake / x86_64-musl

Personal, hardware-specific LibreWolf packaging for one target system:

- **OS:** Void Linux x86_64-musl
- **CPU:** Intel Core i3-6100U / Skylake, 2 cores / 4 threads
- **RAM:** 4 GB DDR3
- **Storage:** HDD
- **Session:** Wayland
- **Target:** x86_64-musl only

This is intentionally a **non-portable, target-tuned package** rather than a generic x86_64 LibreWolf build.

## Goals

The project prioritizes:

1. Fast LibreWolf runtime on the target Skylake laptop.
2. Lower memory pressure on 4 GB RAM.
3. Less HDD activity.
4. Fast, repeatable GitHub Actions builds.
5. Heavy use of CI CPU/RAM for compilation and linking.
6. Keeping downstream patches narrow and auditable.

Security is inherited from LibreWolf/Void where practical; this repository does not optimize its workflow around project-security hardening.

## Build optimization

### CPU-specific code generation

C/C++:

```text
-O2 -march=skylake -mtune=skylake
```

Rust:

```text
-C target-cpu=skylake
RUSTC_OPT_LEVEL=2
```

The resulting package is meant for Skylake-class CPUs, not arbitrary x86_64 systems.

### LLVM toolchain

The package uses:

- Clang 22
- LLVM 22
- LLD 22

The LLVM linker is used together with full cross-language LTO.

### LTO

The final build uses:

- cross-language/full LLVM LTO
- Rust ThinLTO
- parallel LLD LTO threads and partitions

Rust ThinLTO is intentional: it keeps the cross-language optimization path while avoiding the more expensive Rust fat-LTO mode.

### PGO

PGO is enabled by default.

CI:

1. Builds an instrumented LibreWolf.
2. Runs the PGO workload against a headless Weston Wayland compositor.
3. Collects `merged.profdata` and the PGO jarlog.
4. Rebuilds with profile-use + LTO.

The compositor runs on the GitHub runner and its Wayland socket is exposed through xbps-src's `/host` bind mount, so the browser's PGO workload actually exercises Wayland.

Manual/non-CI builds retain an Xvfb/X11 fallback.

## Build acceleration

### sccache

The build uses Void's packaged `rust-sccache` rather than copying an unmanaged binary into the xbps masterdir.

The cache hierarchy is:

```text
local disk cache -> GitHub Actions cache
```

Current settings include:

- 16 GiB local cache
- zstd compression level 1 to reduce compression CPU cost
- persistent sccache daemon across long PGO/LTO phases
- server mode explicitly forced
- remote cache write failures are non-fatal

The GitHub Actions runtime credentials are passed into the xbps chroot through `/host`.

### Source cache

The LibreWolf source archive is cached by its SHA-256 checksum and re-verified before use.

### PGO cache

Generated PGO data is cached using:

- LibreWolf source checksum
- package template contents
- downstream patch contents
- a PGO cache version

A matching PGO profile skips the expensive instrumented build/profile-generation phase.

### Void binary-package cache

The xbps repository cache for the target is persisted between workflows so repeated builds can reuse previously downloaded Void binary packages and reduce bootstrap/dependency setup time.

### CI concurrency

GitHub Actions cancels obsolete builds on the same branch, preventing old multi-hour builds from consuming runner resources after a newer commit arrives.

## CI build flow

The workflow roughly does:

```text
checkout
  -> overlay package
  -> validate template metadata
  -> restore PGO/source/Void caches
  -> prepare xbps-static
  -> install Weston only when PGO is needed
  -> bootstrap xbps-src
  -> configure sccache
  -> fetch/verify source
  -> PGO/LTO/Skylake build
  -> package/checksum
  -> update release tag
  -> upload packages
```

The validator checks template syntax, package metadata, revision values, SHA-256 format, HTTPS source URLs, and the expected LibreWolf source filename before the expensive build stages.

## Runtime tuning

`vendor.js` contains target-specific preferences for **4 GB RAM + HDD** systems:

- background-tab unloading under memory pressure
- earlier low-commit-space pressure
- 30-second session-store writes instead of more frequent HDD writes
- disabled New Tab preloading
- bounded disk-cache memory buffers
- four shared web-content processes
- one prelaunched Fission content process

These settings are intentionally biased toward memory pressure, disk activity, and responsiveness on this machine rather than universal Firefox defaults.

## musl / Void compatibility

The package carries narrow downstream fixes for the selected Void musl environment and the current Firefox/LibreWolf source:

- musl/Linux `prctl` header conflict
- `mach clobber` compatibility
- musl `pthread_t` serialization in `audio_thread_priority`
- LLVM 22 WASI target rename
- Rust ThinLTO handling
- musl `mallinfo` compatibility
- Parakeet C++ header compatibility
- musl sandbox scheduling compatibility
- musl fortify/system-wrapper compatibility

The patch set is kept small and follows current Void Firefox patches where applicable.

## Package configuration

Default build options keep:

```text
alsa dbus pulseaudio wayland lto pgo clang wasi
```

Other options remain available in the template for the package build system:

```text
jack xscreensaver sndio debug
```

The package intentionally disables or avoids features not useful for this personal build, including the updater, crash reporting, telemetry/reporting components, jemalloc, and elf-hack where required by the target build configuration.

System libraries are used where the Void packaging supports them, including NSS, NSPR, pixman, libevent, JPEG, WebP, zlib, and other configured dependencies.

## Packaging

The package is built through Void's `xbps-src` using the current Void `void-packages` tree.

The workflow:

- builds only for `x86_64-musl`
- uses the current LibreWolf source revision recorded in `srcpkgs/librewolf/template`
- verifies the source checksum
- produces XBPS packages and repository metadata
- checksums generated artifacts
- publishes them to a release based on `version-_rev`

The release tag can be deliberately overwritten for rebuilt copies of the same LibreWolf source revision.

## Repository layout

```text
.github/
  scripts/validate-template.sh
  workflows/main.yml

srcpkgs/librewolf/
  template
  files/
    vendor.js
    librewolf.desktop
    stab.h
  patches/
```

## Design principles

The project deliberately favors:

- target-specific optimization over portability
- PGO/LTO over arbitrary compiler flags
- CI resources over the target machine's CPU/RAM
- cache reuse over repeatedly regenerating identical build products
- small downstream patches over large forks
- simple shell/package logic where it is reliable

The build does **not** blindly enable every theoretical compiler optimization. The current profile is intended as a combined configuration for Skylake + 4 GB RAM + HDD + Wayland.

## Upstream

- LibreWolf: https://librewolf.dev/
- Void Linux packages: https://github.com/void-linux/void-packages
- Mozilla Firefox build system: https://firefox-source-docs.mozilla.org/build/buildsystem.html
- sccache: https://github.com/mozilla/sccache
