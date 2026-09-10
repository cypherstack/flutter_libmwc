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
Desktop development with C++ workload for Windows (MSVC).

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
