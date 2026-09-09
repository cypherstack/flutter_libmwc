import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final environment = <String, String>{
      if (code.targetOS == OS.iOS)
        'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0',
      if (code.targetOS == OS.macOS)
        'MACOSX_DEPLOYMENT_TARGET': '${code.macOS.targetVersion}.0',
    };
    if (code.targetOS == OS.android) {
      // native_toolchain_rust 1.0.6 defaults to API 35. Honor Flutter's minimum.
      final (rustTarget, clangTarget) = switch (code.targetArchitecture) {
        Architecture.arm => (
            'armv7-linux-androideabi',
            'armv7a-linux-androideabi',
          ),
        Architecture.arm64 => (
            'aarch64-linux-android',
            'aarch64-linux-android',
          ),
        Architecture.x64 => ('x86_64-linux-android', 'x86_64-linux-android'),
        _ => throw UnsupportedError('Unsupported Android architecture'),
      };
      final bin = code.cCompiler!.compiler.resolve('.');
      final suffix = Platform.isWindows ? '.cmd' : '';
      final ndkTarget = '$clangTarget${code.android.targetNdkApi}';
      final compiler = '$ndkTarget-clang';
      final cc = bin.resolve('$compiler$suffix').toFilePath();
      final target = rustTarget.replaceAll('-', '_');
      environment.addAll({
        'CC_$target': cc,
        'CXX_$target': bin.resolve('$compiler++$suffix').toFilePath(),
        // cc also supplies --target; keep the API level on the final argument.
        'CFLAGS_$target': '--target=$ndkTarget',
        'CXXFLAGS_$target': '--target=$ndkTarget',
        // The NDK's libc++.a linker script includes libc++abi as well.
        // Defer it to the final link instead of bundling the script in an rlib.
        'CXXSTDLIB_$target': 'static:-bundle=c++',
        'CARGO_TARGET_${target.toUpperCase()}_LINKER': cc,
      });
    }

    await RustBuilder(
      assetName: 'mwc.dart',
      extraCargoBuildArgs: ['--lib'],
      extraCargoEnvironmentVariables: environment,
    ).run(input: input, output: output);
    output.dependencies.addAll(
      [
        'rust/Cargo.toml',
        'rust/Cargo.lock',
        'rust/rust-toolchain.toml',
      ].map(input.packageRoot.resolve),
    );
  });
}
