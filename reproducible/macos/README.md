# macOS host-to-GitHub reproduction

The `native-macos` flake output pins Rust 1.90.0, LLVM Clang/LLD/archiver,
Apple SDK 14.4, CMake, protoc, Perl, nasm and the complete Cargo vendor tree.
`flake.lock` is shared with the established Linux recipe and is unchanged.
The Rust sources and lockfile are unchanged. Build the host's native target;
the initial GitHub job covers `aarch64-apple-darwin` only.

The SDK's system libc++ is used with an explicit macOS 11.0 target. The newer
nixpkgs host-tool deployment floor does not select the payload floor. The
byte-level audit rejects higher deployment versions in both the dylib and
static archive, incorrect architecture/install name, dylib UUIDs/RPATHs,
non-system dylib dependencies, nonzero archive timestamps/owners, and embedded
host paths. Preserve the LMDB POSIX mutex/no-robust flags. LLD's deterministic
ad-hoc signature is required to load ARM64 code; no developer signing identity
or notarization is used.

## Build and package

Use Nix flakes and Flutter >=3.47 (CI uses 3.47.2). Flutter/Dart packages and
smoke-tests the output; it does not compile the native libraries. No Homebrew
or Xcode selection is used for native compilation.

```sh
./reproducible/macos/verify.sh
flutter pub get --no-example
dart --packages=.dart_tool/package_config.json tool/build_macos_prebuilt.dart
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart \
  build/macos-prebuilts/mwc_wallet-aarch64-apple-darwin-dynamic.dylib
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart \
  --artifacts build/macos-prebuilts --output build/macos-release
nix eval --json .#native-macos.pinnedInputs
```

The verifier repeats the entire native compilation with `--rebuild`. Darwin
Nix allocates different temporary build paths; source/debug/macro paths map to
`/build`, archives use deterministic timestamps, and LLD omits UUIDs. No
compiled Cargo cache is reused for the second build. Downloaded source and
toolchain caches may be reused. Cargo builds with `--frozen` after hash-checked
vendoring. CI requires `sandbox = true` and `sandbox-fallback = false`.
Record the actual daemon sandbox policy on each host: client configuration
cannot override an untrusted daemon's policy.

The producer requires a clean committed checkout and fresh output directory,
audits both libraries again, and uses the existing manifest protocol. All new
build-policy inputs participate in its shared source fingerprint. A change to
this recipe intentionally invalidates earlier manifests, including Linux ones;
the Linux native derivation itself is preserved.

## Compare a real GitHub run

Publish `macos-reproducible-native-prebuilts` to
`cypherstack/flutter_libmwc` to start `.github/workflows/reproducible-macos.yml`.
It compiles twice, audits, smoke-tests, packages, and uploads
`reproducible-macos-aarch64-apple-darwin-attempt-N`.

Follow [HOST_TO_CI.md](../HOST_TO_CI.md) using that artifact name and
`build/macos-release`. Require a successful real run at the exact local commit,
download its artifact, and run `reproducible/ci_artifacts.py compare` with its
repository, commit, run ID and attempt. Both native files and the manifest must
match. Do not compare the ZIP container or variable `ci-evidence.json` bytes.

Intel macOS and the three iOS targets need independent execution and comparison;
an ARM64 macOS result establishes no claim for those targets or a signed app.
