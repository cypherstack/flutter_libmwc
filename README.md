# `flutter_libmwc`

MWC wallet bindings for Dart 3.13+ and Flutter 3.47+. APIs are in `lib/lib.dart`
and `lib/mwc.dart`; Flutter bundles the native library automatically.

## Use prebuilts

Copy the URL and SHA-256 from a published native release into your app's root
`pubspec.yaml` (workspace root for pub workspaces):

```yaml
hooks:
  user_defines:
    flutter_libmwc:
      native_build: prebuilt
      prebuilt_manifest_url: https://github.com/cypherstack/flutter_libmwc/releases/download/native-YOUR-RELEASE/manifest.json
      prebuilt_manifest_sha256: "REPLACE_WITH_RELEASE_MANIFEST_SHA256"
```

Use the package revision named in that release. The hook checks source identity,
platform compatibility, and checksums. Missing or invalid prebuilts stop the build.
Downloads require public HTTPS; Flutter's normal app build tools are still needed.

Each hook run downloads and verifies fresh files into Flutter's `.dart_tool`
output. Flutter can reuse that output for incremental builds. `flutter clean`
removes it, so the next build downloads again. In pub workspaces, run clean
from the workspace root.

Use the same root pubspec settings and normal Flutter commands in CI, such as
`flutter pub get` and `flutter test`.

## Build from source

Omit the prebuilt settings or set `native_build: source`. Install Rust 1.90.0 via
[rustup](https://rustup.rs/), a C/C++ compiler, CMake, libclang, pkg-config, Perl,
and `protoc`. Use Xcode for Apple, Android SDK/NDK r27+ for Android, and Visual
Studio's C++ workload for Windows. Run Flutter normally; the hook compiles Rust
with `--locked`.

## Build releases

Push a new `native-*` tag to build all targets and automatically publish a release
after the checks pass. Each release includes consumer YAML and a prominent
**USE AT YOUR OWN RISK** warning. Existing releases are never overwritten.

```sh
git tag native-0.1.0-1
git push origin native-0.1.0-1
```

Enable [release immutability](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes)
to prevent published assets from being replaced.

Both static and dynamic libraries are built:

| Platform | Targets | Minimum |
| --- | --- | --- |
| Linux | x64 | glibc 2.35; no musl/Alpine |
| Windows | x64 | MSVC |
| macOS | arm64, x64 | macOS 11 |
| Android | armv7, arm64, x64 | API 21 |
| iOS | arm64 device; arm64/x64 simulator | iOS 13 |

Linux deployments must meet the glibc minimum. Sanitized runtimes are unsupported.
For local builds, run from this repository's root with the native tools installed:

```sh
flutter pub get
dart --packages=.dart_tool/package_config.json tool/build_prebuilt.dart --target aarch64-apple-darwin
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart --artifacts build/prebuilts
```

Use fresh output directories; upload `build/native-release/*` together.
For Android, pass `--ndk` pointing to NDK 28.2.13676358. See `--help` for options.

To test the prebuilt tooling without compiling Rust:

```sh
flutter pub get
dart --packages=.dart_tool/package_config.json tool/test_prebuilt.dart
```
