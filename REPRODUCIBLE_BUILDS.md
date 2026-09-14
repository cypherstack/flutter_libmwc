# Reproducible native prebuilts

This branch extends `native-prebuilts` at `9b6f1d5`. It keeps the Rust 1.90.0
source/toolchain contract and the existing release manifest protocol.

## Linux with Nix

Run from a committed checkout with Nix flakes enabled:

```sh
nix build .#native-linux
./reproducible/nix/verify.sh
./reproducible/nix/smoke-ubuntu.sh # Docker required
```

`result/lib` contains both `libmwc_wallet.a` and `libmwc_wallet.so`. The verifier
forces an uncached rebuild of the derivation and Nix compares the complete
output, including both libraries. This demonstrates repeatability on the test
host; a second independent Linux builder should compare the printed SHA-256s
before release. Cached toolchains/dependencies are reused; the native compile
is repeated from scratch. It does not rebuild the entire Nix bootstrap chain.

The implementation pins:

- nixpkgs, the Rust overlay, and the glibc baseline in `flake.lock`;
- Rust to `rust/rust-toolchain.toml` (1.90.0);
- all registry and Git sources through `Cargo.lock` plus a fixed vendor hash;
- GCC 11.3 and glibc 2.35 from the baseline input, including static libstdc++;
- CMake, Perl, protoc, nasm, and the remaining native tools through Nix inputs.

Only the fetch derivations use the network. Compilation uses `cargo --frozen`
in the Nix sandbox. The derivation requires `/build` as its build root, so a
daemon falling back to a host temporary directory fails before compilation.
Configure the daemon with `sandbox = true` (and preferably
`sandbox-fallback = false`); untrusted daemon clients cannot override those
settings on the command line. No crate manifests or lock entries are rewritten locally.
OpenSSL remains vendored as in the upstream manifest. The build normalizes
source paths and `SOURCE_DATE_EPOCH`, disables incremental compilation/debug
information, removes ELF runtime search paths, and audits the glibc ceiling,
shared dependencies, architecture, and C exports. Linking rejects unresolved
symbols. The baseline-container test loads without `/nix` or network access
and checks mnemonic generation plus 100 error-response allocation/free cycles.
It does not exercise wallet transactions or validate all static-link consumers.

A custom Cargo build phase and explicit C compiler paths are necessary here:
current nixpkgs' Cargo hook and build-tool PATH otherwise select the newer
compiler, even with a baseline `stdenv`. The ELF audit and Ubuntu test exposed
both failure modes during development.

The old baseline is a compatibility toolchain, not a recommendation to deploy
an old OS. Updating it requires rebuilding and checking the advertised ABI
floor. Rust is obtained from the hash-pinned upstream binary distribution via
rust-overlay; this is not a full-source bootstrap claim.

## Package for the existing Dart hook

```sh
flutter pub get --no-example
dart --packages=.dart_tool/package_config.json tool/build_nix_prebuilt.dart
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart \
  build/nix-prebuilts/mwc_wallet-x86_64-unknown-linux-gnu-dynamic.so
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart \
  --artifacts build/nix-prebuilts --output build/nix-release
```

The producer requires a clean committed checkout, builds the Nix derivation,
checks that inputs stayed unchanged, then uses the existing ABI audit and
packager. Both consumer and producer include the Nix recipe, lock, ABI audit,
and Nix producer in the source fingerprint. Existing manifests from before
this change therefore intentionally do not match this branch.

The target fragment records recipe/lock hashes and the Nix store path. The
assembled manifest retains the established schema and binds source and artifact
hashes; keep the fragment alongside the release for additional provenance.
Use `--output` to choose a fresh destination; existing artifacts are never
overwritten. A Linux-only manifest cannot satisfy requests for other platforms.

The `Reproduce Linux native prebuilts` workflow runs on pushes to the reproducibility
branch or by manual dispatch. It repeats the build independently on Ubuntu 22.04
and 24.04, packages and smoke-tests the results, and requires matching payloads.
It uploads workflow artifacts and does not publish a release. It must be run
from this branch (or a commit containing the recipe). Local workflow validation
is not evidence of a completed GitHub Actions run.

## StageX experiment

See [reproducible/stagex/README.md](reproducible/stagex/README.md). The StageX path
builds with pinned OCI images and an offline Cargo vendor tree, but currently
produces a **musl** library using Rust 1.96. It is not compatible with the GNU
Linux artifact identity in the release hook and must not be published as one.
Nix and StageX hashes are expected to differ: they use different compilers,
libcs, and C++ runtimes. Compare rebuilds within each recipe.

## Optional Dart command wrappers

[`nix` on pub.dev](https://pub.dev/packages/nix) is an orchestration CLI for
Flutter/Dart development shells and build commands. It does not itself pin
this crate's Rust, C/C++, Cargo graph, or ELF ABI. The derivation is the native
build authority; no additional Dart dependency is required. A project already
using `nix_dart` can invoke the commands above as a custom build step, but merely
running Cargo in a development shell is not equivalent to this sandboxed build.

The `https://pub.dev/api/packages/stagex` endpoint returned HTTP 404 during this
investigation (2026-09-14). The StageX recipe uses Docker directly and does not
depend on that package being available.

## Next host work

Linux local validation has passed. macOS and Windows can proceed independently
using the committed [host handoffs](reproducible/handoffs/README.md). The acceptance
criterion for each host is now [matching a real GitHub run](reproducible/HOST_TO_CI.md),
not only local repeatability:

| Host | First reproducibility target | Inputs and checks |
| --- | --- | --- |
| macOS ARM64 (then Intel) | unsigned macOS `.a` and `.dylib` | Pin Nix/Darwin tools or Xcode build and SDK hashes; keep macOS 11 floor, install name, and LMDB mutex flags; compare clean builds in different paths, then run the existing C ABI smoke test. |
| macOS | iOS device and simulator archives | Pin matching Xcode SDKs, preserve iOS 13 floor, compare unsigned archives separately from signing and packaging. |
| Windows x64 | MSVC `.lib` and `.dll` | Pin Visual Studio Build Tools, Windows SDK, Rust 1.90, protoc, CMake, nasm; test `/Brepro`, archive/PE timestamps, linker IDs, and path remapping; retain short build paths and run the existing smoke test. |
| Linux | Android | Hash-pin NDK 28.2.13676358 and host tools; use its target sysroot, preserve API 21 and 16 KiB page alignment; compare each ABI and link mode. |

Nix on macOS can manage Darwin builds, but Apple SDK inputs still need an
explicit policy. Nix/StageX in WSL are Linux builders; they do not reproduce
MSVC artifacts automatically. MinGW outputs must not be relabeled as MSVC.
Signing and notarization should follow comparison of the unsigned payloads.

Background: [Nix Rust packaging](https://nixos.org/manual/nixpkgs/stable/#rust),
[rust-overlay](https://github.com/oxalica/rust-overlay), and
[StageX application builds](https://docs.stagex.tools/get-started/quickstart/).
