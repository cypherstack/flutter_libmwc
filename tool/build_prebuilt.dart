/// Build one native release target and write its libraries and manifest fragment.
///
/// Run with `dart --packages=.dart_tool/package_config.json
/// tool/build_prebuilt.dart` after `flutter pub get` to bypass native build hooks.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'src/build_support.dart';

Future<Map<String, String>> buildEnvironment(
  String target, {
  String? ndk,
}) async {
  if (!releaseTargets.containsKey(target)) {
    throw ArgumentError.value(target, 'target', 'Unsupported release target');
  }
  final env = Map<String, String>.of(Platform.environment)
    // Local shell optimization flags must not silently change release ABI.
    ..remove('RUSTFLAGS')
    ..remove('CARGO_ENCODED_RUSTFLAGS')
    ..['CARGO_INCREMENTAL'] = '0'
    ..['CARGO_PROFILE_RELEASE_DEBUG'] = 'false';
  final key = target.replaceAll('-', '_');
  final rustflags = <String>[];

  if (target.contains('apple')) {
    if (!Platform.isMacOS) {
      throw StateError('Apple targets require macOS and Xcode');
    }
    env['PATH'] = (env['PATH'] ?? '')
        .split(':')
        .where((part) => !part.contains('Contents/Developer/'))
        .join(':');
    rustflags.addAll([
      '-C',
      'link-arg=-Wl,-install_name,@rpath/libmwc_wallet.dylib',
    ]);
    if (target.contains('darwin')) {
      env['MACOSX_DEPLOYMENT_TARGET'] = '11.0';
      // Match the source hook's LMDB sandbox fix.
      env['CFLAGS_$key'] = '-DMDB_USE_POSIX_MUTEX=1 -DMDB_USE_ROBUST=0';
    } else {
      env['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0';
      final sdk = target == 'aarch64-apple-ios'
          ? 'iphoneos'
          : 'iphonesimulator';
      env['SDKROOT'] = (await runCommand([
        'xcrun',
        '--sdk',
        sdk,
        '--show-sdk-path',
      ], capture: true))!;
    }
  } else if (target.contains('android')) {
    if (Platform.isWindows) {
      throw StateError(
        'Android releases require Linux or macOS (OpenSSL needs Unix Perl)',
      );
    }
    ndk ??= env['ANDROID_NDK_HOME'] ?? env['ANDROID_NDK_ROOT'];
    if (ndk == null || ndk.isEmpty) {
      throw StateError('Pass --ndk or set ANDROID_NDK_HOME');
    }
    final ndkDirectory = Directory(ndk).absolute;
    final properties = await File.fromUri(
      ndkDirectory.uri.resolve('source.properties'),
    ).readAsString();
    if (!RegExp(
      '^Pkg.Revision\\s*=\\s*${RegExp.escape(androidNdkVersion)}\\s*\$',
      multiLine: true,
    ).hasMatch(properties)) {
      throw StateError('Release builds require Android NDK $androidNdkVersion');
    }
    final host = Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64';
    final toolchain = ndkDirectory.uri.resolve(
      'toolchains/llvm/prebuilt/$host/',
    );
    final binary = toolchain.resolve('bin/');
    final clangTarget = target.startsWith('armv7-')
        ? 'armv7a-linux-androideabi'
        : target;
    final ndkTarget = '${clangTarget}21';
    final cc = File.fromUri(binary.resolve('$ndkTarget-clang'));
    if (!await cc.exists()) {
      throw StateError('Missing NDK compiler: ${cc.path}');
    }
    final sysrootTarget = target.startsWith('armv7-')
        ? 'arm-linux-androideabi'
        : target;
    final sysroot = toolchain.resolve('sysroot').toFilePath();
    env.addAll({
      'CC_$key': cc.path,
      'CXX_$key': binary.resolve('$ndkTarget-clang++').toFilePath(),
      'AR_$key': binary.resolve('llvm-ar').toFilePath(),
      'RANLIB_$key': binary.resolve('llvm-ranlib').toFilePath(),
      'CFLAGS_$key': '--target=$ndkTarget',
      'CXXFLAGS_$key': '--target=$ndkTarget',
      'CXXSTDLIB_$key': 'static:-bundle=c++',
      'CARGO_TARGET_${key.toUpperCase()}_LINKER': cc.path,
      'BINDGEN_EXTRA_CLANG_ARGS_$key':
          '--sysroot=$sysroot -I$sysroot/usr/include/$sysrootTarget',
    });
    // Required for Android devices using 16 KiB pages, even at API 21.
    rustflags.addAll(['-C', 'link-arg=-Wl,-z,max-page-size=16384']);
  } else if (target.contains('linux')) {
    if (!Platform.isLinux) {
      throw StateError('Linux releases require a Linux host');
    }
    env['CXXSTDLIB_$key'] = 'static=stdc++';
  } else if (target.contains('windows') && !Platform.isWindows) {
    throw StateError('Windows MSVC releases require Windows and Visual Studio');
  }

  env['CARGO_TARGET_${key.toUpperCase()}_RUSTFLAGS'] = rustflags.join(' ');
  return env;
}

/// Reject a host ABI or shared dependency newer than the advertised floor.
Future<void> auditLinuxLibrary(File library, String minimum) async {
  final symbols = (await runCommand([
    'readelf',
    '--version-info',
    library.path,
  ], capture: true))!;
  final dependencies = (await runCommand([
    'readelf',
    '--dynamic',
    library.path,
  ], capture: true))!;
  auditLinuxMetadata(symbols, dependencies, minimum, name: library.path);
}

void auditLinuxMetadata(
  String symbols,
  String dependencies,
  String minimum, {
  String name = 'Native library',
}) {
  final floor = minimum.split('.').map(int.parse).toList();
  for (final match in RegExp(r'GLIBC_(\d+)\.(\d+)').allMatches(symbols)) {
    final major = int.parse(match[1]!);
    final minor = int.parse(match[2]!);
    if (major > floor[0] || (major == floor[0] && minor > floor[1])) {
      throw StateError('$name requires glibc $major.$minor, above $minimum');
    }
  }
  const allowed = {
    'libc.so.6',
    'libm.so.6',
    'libdl.so.2',
    'libpthread.so.0',
    'librt.so.1',
    'libgcc_s.so.1',
    'ld-linux-x86-64.so.2',
  };
  final unexpected =
      RegExp(r'\(NEEDED\).*\[([^\]]+)\]')
          .allMatches(dependencies)
          .map((match) => match[1]!)
          .toSet()
          .difference(allowed)
          .toList()
        ..sort();
  if (unexpected.isNotEmpty) {
    throw StateError('Unexpected shared dependencies: $unexpected');
  }
}

Future<void> buildTarget(
  String target,
  Directory output,
  Directory targetDirectory, {
  String? ndk,
  Uri? root,
}) async {
  root ??= packageRoot;
  output = output.absolute;
  targetDirectory = targetDirectory.absolute;
  final names = libraryNames(target);
  final fingerprint = await sourceSha256(root);
  final channel = await toolchainChannel(root);
  final env = await buildEnvironment(target, ndk: ndk);
  await runCommand([
    'rustup',
    'toolchain',
    'install',
    channel,
    '--profile',
    'minimal',
    '--no-self-update',
  ], workingDirectory: root);
  await runCommand([
    'rustup',
    'target',
    'add',
    '--toolchain',
    channel,
    target,
  ], workingDirectory: root);
  await runCommand(
    [
      'rustup',
      'run',
      channel,
      'cargo',
      'build',
      '--release',
      '--locked',
      '--lib',
      '--manifest-path',
      root.resolve('rust/Cargo.toml').toFilePath(),
      '--target',
      target,
      '--target-dir',
      targetDirectory.path,
    ],
    workingDirectory: root,
    environment: env,
  );
  if (await sourceSha256(root) != fingerprint) {
    throw StateError(
      'Native sources changed during the build; refusing to package',
    );
  }
  final release = targetDirectory.uri.resolve('$target/release/');
  final minimumGlibc = releaseTargets[target]!['minimum_glibc_version'];
  if (minimumGlibc is String) {
    await auditLinuxLibrary(
      File.fromUri(release.resolve(names['dynamic']!)),
      minimumGlibc,
    );
  }
  final entries = <({String mode, File source, File destination})>[];
  final fragmentFile = File.fromUri(output.uri.resolve('$target.json'));
  for (final entry in names.entries) {
    final source = File.fromUri(release.resolve(entry.value));
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Missing or nonregular built library: ${source.path}');
    }
    final extension = entry.value.substring(entry.value.lastIndexOf('.'));
    final destination = File.fromUri(
      output.uri.resolve('mwc_wallet-$target-${entry.key}$extension'),
    );
    entries.add((mode: entry.key, source: source, destination: destination));
  }
  for (final file in [
    fragmentFile,
    ...entries.map((entry) => entry.destination),
  ]) {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Refusing to overwrite an artifact: ${file.path}');
    }
  }
  await output.create(recursive: true);
  final artifacts = <Map<String, Object>>[];
  for (final entry in entries) {
    final destination = await entry.source.copy(entry.destination.path);
    artifacts.add({
      'target': target,
      'link_mode': entry.mode,
      'file': destination.uri.pathSegments.last,
      'sha256': await sha256File(destination),
      'size': await destination.length(),
      ...releaseTargets[target]!,
    });
  }
  await fragmentFile.writeAsString(
    '${indentedJson.convert({
      'schema_version': 1,
      'package': 'flutter_libmwc',
      'source_sha256': fingerprint,
      'artifacts': artifacts,
      'build': {'rust_version': channel, 'target': target},
    })}\n',
  );
  stdout.writeln('Packaged $target; source_sha256=$fingerprint');
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('target', allowed: releaseTargets.keys.toList())
    ..addOption(
      'output',
      defaultsTo: packageRoot.resolve('build/prebuilts').toFilePath(),
    )
    ..addOption(
      'target-dir',
      defaultsTo: packageRoot.resolve('build/prebuilt-target').toFilePath(),
    )
    ..addOption('ndk')
    ..addFlag(
      'source-hash',
      negatable: false,
      help: 'Print the native source fingerprint without building.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Print the release plan without installing or compiling anything.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln('Build one native release target.\n${parser.usage}');
      return;
    }
    if (args.rest.isNotEmpty)
      throw FormatException('Unexpected arguments: ${args.rest.join(' ')}');
    final target = args.option('target');
    if (args.flag('source-hash')) {
      stdout.writeln(await sourceSha256());
    } else if (args.flag('dry-run') && target != null) {
      stdout.writeln(
        indentedJson.convert({
          'source_sha256': await sourceSha256(),
          'rust_version': await toolchainChannel(),
          'target': target,
          'cargo_arguments': [
            'build',
            '--release',
            '--locked',
            '--lib',
            '--target',
            target,
          ],
          'libraries': libraryNames(target),
          'compatibility': releaseTargets[target],
          'android_ndk': target.contains('android') ? androidNdkVersion : null,
        }),
      );
    } else if (target != null) {
      await buildTarget(
        target,
        Directory(args.option('output')!),
        Directory(args.option('target-dir')!),
        ndk: args.option('ndk'),
      );
    } else {
      throw const FormatException('--target or --source-hash is required');
    }
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n${parser.usage}');
    exitCode = 64;
  } catch (error) {
    stderr.writeln('Native release build failed: $error');
    exitCode = 1;
  }
}
