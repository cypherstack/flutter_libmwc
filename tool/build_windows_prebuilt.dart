/// Build with the pinned Windows recipe, then reuse the release packager.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'build_prebuilt.dart';
import 'src/build_support.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('work', mandatory: true)
    ..addOption('cache', mandatory: true)
    ..addOption('python', defaultsTo: 'python')
    ..addOption('output', defaultsTo: 'build/windows-prebuilts');
  try {
    final args = parser.parse(arguments);
    if (!Platform.isWindows || args.rest.isNotEmpty) {
      throw StateError('Run on Windows with the documented arguments');
    }
    final status = await runCommand([
      'git',
      'status',
      '--porcelain',
      '--untracked-files=all',
    ], capture: true);
    if (status!.isNotEmpty) {
      throw StateError('Commit the source and recipe before packaging');
    }
    final commit = await runCommand([
      'git',
      'rev-parse',
      'HEAD',
    ], capture: true);
    final fingerprint = await sourceSha256();
    final work = Directory(args.option('work')!).absolute;
    await runCommand([
      'powershell.exe',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'reproducible/windows/build.ps1',
      '-Work',
      work.path,
      '-Cache',
      Directory(args.option('cache')!).absolute.path,
      '-Python',
      args.option('python')!,
    ]);
    if (await sourceSha256() != fingerprint ||
        await runCommand(['git', 'rev-parse', 'HEAD'], capture: true) !=
            commit ||
        (await runCommand([
          'git',
          'status',
          '--porcelain',
          '--untracked-files=all',
        ], capture: true))!.isNotEmpty) {
      throw StateError('Source or recipe changed during the build');
    }
    const target = 'x86_64-pc-windows-msvc';
    final evidence = jsonDecode(
      await File.fromUri(work.uri.resolve('build-evidence.json'))
          .readAsString(),
    ) as Map<String, dynamic>;
    await packageBuiltTarget(
      target,
      Directory(args.option('output')!).absolute,
      work.uri.resolve('target/$target/release/'),
      fingerprint: fingerprint,
      build: {
        'builder': 'pinned-windows-msvc',
        'target': target,
        'rust_version': await toolchainChannel(),
        'tools_lock_sha256': evidence['tools_lock_sha256'] as String,
      },
    );
  } catch (error) {
    stderr.writeln('Windows prebuilt build failed: $error');
    exitCode = 1;
  }
}
