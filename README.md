# `flutter_libmwc`

MWC wallet bindings for Dart 3.13+ and Flutter 3.47+. APIs are in `lib/lib.dart`
and `lib/mwc.dart`; Flutter bundles the native library automatically. Nothing
beyond Flutter is needed to use the package: the build hook downloads the
Rust library built for this version and checks its hash.

## Native library

The hook obtains the Rust library in one of three modes, chosen with the
`build` user define in the consuming app's root `pubspec.yaml` (the workspace
root for pub workspaces), or for this checkout with a `.dnix-build` file
holding the mode:

```yaml
hooks:
  user_defines:
    flutter_libmwc:
      build: prebuilt   # the default; or source, or dev
```

- `prebuilt` downloads the library of the release `dnix.lock` names and
  verifies it against the hash recorded there. A mismatch is an error, never
  a fallback. Downloads are cached by hash and need public HTTPS.
- `source` builds the library with Nix, the same build CI uses, and verifies
  it against the same hash. Needs Nix on Linux or an Apple Silicon Mac; the
  Apple targets need Xcode 27.0. OpenSSL is compiled from source inside that
  build.
- `dev` builds with Nix but skips the Xcode pin and the hash check, for
  working on the Rust code. The hook notices a `.dnix-build` file from its
  next run on, so touch `dnix.json` after creating it.

Only dynamic libraries are provided, without sanitizers:

| Platform | Targets | Minimum |
| --- | --- | --- |
| Linux | arm64, x64 | glibc 2.28; no musl/Alpine |
| Windows | x64 | MSVC runtime |
| macOS | arm64, x64 | macOS 11 |
| Android | armv7, arm64, x64 | API 21; C++ runtime linked statically |
| iOS | arm64 device; arm64/x64 simulator | iOS 13; arm64 simulator 14 |

The floors, the Rust and Xcode versions, the location of the Rust workspace,
and the LMDB flags for Apple targets live in `dnix.json`.

## Releases

`dnix.lock` records the hash of every library the Rust source builds to and
names the GitHub release, `native-<release>`, that holds those bytes. After
changing the Rust code, run `dart tool/update_lock.dart` on a Mac with Nix
and Xcode 27.0 and commit the lock with the change; without a Mac, push and
copy the lock CI prints once every host is green. CI
(`.github/workflows/native.yml`) builds on four hosts, fails if any host or
the lock disagrees, and publishes the release when the lock reaches the
default branch. Nothing is committed by CI, and old releases stay.

Anyone can rebuild one platform with Nix and compare:
`dart tool/verify_release.dart linux` (or android, windows, macos, ios, or a
target triple), on Windows inside WSL2 for the non-Apple platforms. The build
comes from the shared [dnix](https://github.com/cypherstack/dnix) package,
whose documentation explains how the bytes stay identical across hosts.

## Tests

`flutter test` runs the Dart tests against the bundled library. Before the
lock's release is published, or to test local Rust changes, they need the
library built from source: `echo dev > .dnix-build` with Nix installed
(`source` to also check the hash).
