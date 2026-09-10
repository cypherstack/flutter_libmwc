# `flutter_libmwc`

Requires Dart 3.13+, Flutter 3.47+, and Rust 1.90.0 (pinned in
`rust/rust-toolchain.toml`). Install Rust with [rustup](https://rustup.rs/)
and make sure `rustup`, `cargo`, and `rustc` are on `PATH`.

The [build hook](https://dart.dev/tools/hooks) compiles `rust/` with
[native_toolchain_rust](https://pub.dev/packages/native_toolchain_rust).
Flutter bundles the resulting native asset, and `lib/mwc.dart` resolves its
symbols using `@Native`. No manual library copying or build scripts are needed.

Install the native build tools required by the Rust dependencies: a C/C++
compiler, CMake, libclang, pkg-config, Perl (for vendored OpenSSL), and `protoc`.
Use Xcode for Apple targets, Android SDK/NDK r27+ for Android, and Visual Studio's
Desktop development with C++ workload and NASM for Windows (MSVC).

```sh
flutter pub get
cd example
flutter run
```

The first build downloads Rust targets and Cargo dependencies. Later builds
reuse the build cache. `flutter test` also runs the hook and needs the native
build tools.

Wallet APIs remain in `lib/lib.dart` and `lib/mwc.dart`. The generated
`FlutterLibmwc.getPlatformVersion()` API and platform plugin scaffolding are removed.

## Migrating consumers

Update the Flutter/Dart SDK before upgrading this dependency. Remove calls into
this package's old `scripts/` directory from build, download, dependency setup,
and Rust version selection scripts. Cargo now selects the pinned toolchain.
Remove CMake installs of old `linux/bin/` and `scripts/windows/build/` artifacts,
and update any templates that generate those files. Ensure the app's Linux and
Windows CMake files install Flutter's `native_assets` directory, as in `example/`.

Remove imports of the formerly generated `git_versions.dart`. It described the
commit of a downloaded platform binary; a package version is not a replacement
for that value. Record the source revision using the consuming app's dependency
lockfile or submodule pin instead. The removed `flutter_libmwc.dart` exposed only
`FlutterLibmwc.getPlatformVersion()`; import `lib.dart` for `Libmwc` wallet APIs.

Stack Wallet consumers must migrate their build/download scripts, CMake files
and `scripts/app_config/templates/`, plus the MWC interface generator template
and its generated output, together with updating the plugin submodule pin.
Updating the plugin alone does not migrate those consumers.

Windows x64 uses MSVC. Windows ARM64 is not currently in the pinned target list
and is not claimed as a tested target. An Android APK build verifies packaging;
runtime checks on an emulator/device and real Windows validation are separate.
