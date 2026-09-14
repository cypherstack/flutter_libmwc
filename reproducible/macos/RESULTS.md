# macOS ARM64 host-to-GitHub result

The tested code is `7f6b599e2c8827b9f9e764acd83e1f83296c02fb` in
`cypherstack/flutter_libmwc`, branch `macos-reproducible-native-prebuilts`, based
on `reproducible-native-prebuilts` at `a2c57c740151489bd83cca55495bf56a8abdee3f`.
The report/evidence commit follows the tested code and does not change build inputs.

**Verified:** this macOS host and GitHub Actions produced byte-identical ARM64
static and dynamic libraries, `manifest.json`, and `manifest.sha256`. Both hosts
also passed a forced clean native rebuild without reusing compiled Cargo output.

[GitHub run 34907776918, attempt 1](https://github.com/cypherstack/flutter_libmwc/actions/runs/34907776918)
completed successfully on `macos-15` / image `macos-15-arm64`
`20260907.0337.1`. The downloaded artifact is
`reproducible-macos-aarch64-apple-darwin-attempt-1`.
[The comparison](evidence/macos-34907776918/local-to-github.json) binds the exact
repository, commit, run ID, attempt, source fingerprint and all payload hashes.

## Matching SHA-256 values

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `mwc_wallet-aarch64-apple-darwin-static.a` | 96,121,872 | `b557e9eae847079a8d176723f11adca299b24813d2b7dbc7b3a96b77f5cca153` |
| `mwc_wallet-aarch64-apple-darwin-dynamic.dylib` | 15,569,664 | `3afad7d4a2b7fd199d0e61cc9cd94b736acae45b67f6fee57ed4c4e6297e75fe` |
| `manifest.json` | 729 | `faf99589208329a4cdd6b5698fdd61ac3b69cd71c0439f68b4a6e754369021a7` |

Source fingerprint:
`2548d24bb353d569b7e33faa51ec9e21faa42225178480ba4e19a2c12fbe9bbc`.
Dylib UUID: `4c4c4479-5555-3144-a14e-a6a224a6d330`.

## Verification

- Two clean local checkouts at the tested commit selected the same derivation;
  the second forced a complete rebuild. Nix reported `Clean rebuild matched`.
  GitHub independently built and forced a rebuild with the same result.
- The downloaded GitHub payload and local release comparison returned
  `"status": "match"`. ZIP metadata and run-specific evidence are excluded;
  no payload bytes, UUIDs or signatures are masked during comparison.
- Local and CI dylib smoke tests passed mnemonic generation and error/free ABI
  checks. The downloaded CI dylib also loaded and passed on the local host.
- A C consumer linked against the static archive and passed mnemonic generation,
  invalid-config response checks and 100 frees. `codesign --verify --verbose=2`
  accepted the final dylib's ad-hoc signature.
- The audit checked all 2,107 archive object members and the dylib. Eight Mach-O
  audit tests and eight artifact comparison tests passed. Dart packaging tests
  passed 39 with one Linux-only skip; targeted Dart analysis and actionlint
  passed. Flutter integration tests are outside this claim; see the exact
  [verification commands and test-runner note](evidence/macos-34907776918/verification-commands.md).

All small evidence files are retained in
[`evidence/macos-34907776918/`](evidence/macos-34907776918/).
The native payloads remain in the GitHub artifact and local ignored build directories.
See [README.md](README.md) for the build and comparison procedure.

## Inputs and host

The local host is an ARM64 Mac14,6 (Apple M2 Max, 96 GiB), macOS 26.5.2
(build 25F84), Nix 2.34.0. Installed Xcode 26.6 / SDK 26.5 / Apple Clang 21
were inventoried but are not the native compiler inputs. Local packaging uses
Flutter 3.47.1 / Dart 3.13.1; CI uses Flutter 3.47.2.

The shared unchanged `flake.lock` pins nixpkgs
`56c02bc00adcf003215cc4bd996d6efaf4cff188` and rust-overlay
`ab450d47a3f906d19de1b332915bfc6e5b29c853`. Native inputs are Rust 1.90.0,
LLVM Clang/LLD/archiver 21.1.8, the complete Apple SDK 14.4, CMake 4.3.4,
protoc 21.12, Perl 5.42.0 and nasm 3.02. Cargo vendoring is fixed by
`sha256-gcdRzH3tlgUOdPi3BCez/EqoEtyLBBwHB7RPi3ep8io=`; compilation uses
`--frozen`. Store paths, content NAR hashes and the native derivation are in the
accompanying evidence. No Rust source, Cargo lockfile, or toolchain version changed.

Native derivation:
`/nix/store/04dzwp17ypx5mh0az0i4r8qpcdd80f97-mwc-wallet-native-macos-0.1.0.drv`.
Output: `/nix/store/8s9mm5min1r2sxg2fyg38mriwm773s16-mwc-wallet-native-macos-0.1.0`.

## Why earlier builds differed

- The processed Nix SDK separates libc++ and iconv stubs. The recipe uses its
  hash-pinned complete source SDK and an explicit macOS 11.0 payload floor.
- cc-rs hashes source directories into ring assembly archive member names.
  Compiling dependencies directly from the immutable Cargo vendor store path
  removes temporary-directory variation in those names.
- LLVM's deterministic Darwin archives use zero timestamps for unique member
  names and 1, 2, ... for duplicate names. The audit checks that sequence and
  owner fields without rewriting the archive.
- LLD hashes debug object paths into the Mach-O UUID. Rust 1.90 strips those
  paths after linking, leaving a path-dependent UUID and ad-hoc signature.
  Passing `-Wl,-S` removes them inside LLD before the UUID is generated.
  Removing the UUID instead is invalid on this host: its loader rejects a
  dylib without `LC_UUID`.

The standalone `link_path_probe.py` compiles one debug object, copies it into
two differently sized paths while preserving metadata, links and performs Rust's
post-link stripping. Post-link-only outputs differ; link-time-stripped outputs
match and both load with the expected return value. Run it with the saved
`pinned-inputs.json`. This isolates the failure independently of the wallet build.
See [LLD 21.1.8 UUID generation](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/lld/MachO/Writer.cpp)
and [Rust 1.90 post-link stripping](https://github.com/rust-lang/rust/blob/1.90.0/compiler/rustc_codegen_ssa/src/back/link.rs).

## Scope and limits

| Target | Status |
| --- | --- |
| `aarch64-apple-darwin` | Matched local clean rebuilds and real GitHub Actions output, static + dynamic + manifest |
| `x86_64-apple-darwin` | Not executed; locked nixpkgs 26.11 dropped Intel macOS support, so it needs a separate compatible pin |
| `aarch64-apple-ios` | Not executed |
| `aarch64-apple-ios-sim` | Not executed |
| `x86_64-apple-ios` | Not executed |

The local Nix daemon has `sandbox = false` and `sandbox-fallback = true` and
rejects untrusted client overrides. Its global configuration was left intact.
CI requires `sandbox = true` and `sandbox-fallback = false`. A local byte match
therefore does not establish local sandbox isolation or a full-source bootstrap
of cached compilers and dependencies.

The audits check the macOS 11.0 load-command floor, architecture, install name,
UUID, system-library dependencies, archive metadata and absence of host paths.
They do not substitute for execution on macOS 11. The ABI probes generate a
mnemonic and exercise invalid-config response allocation/free; they do not
perform wallet transactions. This is a native plugin result, with LLD's ad-hoc
signature retained, not a notarized or developer-signed application result.

The Linux native derivation remains exactly
`/nix/store/b1aqara6idic44d94gkz4z0qi70bvdkx-mwc-wallet-native-0.1.0.drv`.
The shared manifest fingerprint intentionally includes the new macOS build
policy, so old Linux manifests must not be reused for this source identity.
