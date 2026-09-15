import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

import 'src/prebuilt.dart';
import 'src/source_fingerprint.dart';
import 'src/windows_builder.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (await usePrebuilt(input, output)) return;

    final code = input.config.code;

    if (code.targetOS == OS.windows &&
        code.targetArchitecture == Architecture.x64) {
      final target = PrebuiltTarget.fromConfig(code);
      final artifacts = await buildWindowsNative(input.packageRoot);
      final directory = Directory.fromUri(input.outputDirectory);
      await directory.create(recursive: true);
      final library =
          await File.fromUri(
            artifacts.uri.resolve(target.libraryFileName),
          ).copy(
            input.outputDirectory.resolve(target.libraryFileName).toFilePath(),
          );
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'mwc.dart',
          file: library.uri,
          linkMode: target.linkMode == 'static'
              ? StaticLinking()
              : DynamicLoadingBundled(),
        ),
      );
      output.dependencies.addAll(
        (await sourceFingerprint(input.packageRoot)).dependencies,
      );
      return;
    }

    // OpenSSL refuses to build for a non-Windows target using Windows' perl.
    if (Platform.isWindows && code.targetOS != OS.windows) {
      throw UnsupportedError(
        'Cannot build ${code.targetOS} from Windows; use Linux, macOS, or WSL.',
      );
    }

    final environment = <String, String>{
      if (code.targetOS == .iOS)
        "IPHONEOS_DEPLOYMENT_TARGET": "${code.iOS.targetVersion}.0",
      if (code.targetOS == .macOS) ...{
        "MACOSX_DEPLOYMENT_TARGET": "${code.macOS.targetVersion}.0",
        // LMDB defaults to SysV semaphores on Apple targets, which the App
        // Sandbox denies (EPERM on mdb_env_open). Keep the lock in lock.mdb via
        // pthread mutexes instead; macOS has no robust mutexes, so disable those.
        "CFLAGS_${code.targetArchitecture == .arm64 ? "aarch64" : "x86_64"}_apple_darwin":
            "-DMDB_USE_POSIX_MUTEX=1 -DMDB_USE_ROBUST=0",
      },
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
      extraCargoBuildArgs: ['--lib', '--locked'],
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
