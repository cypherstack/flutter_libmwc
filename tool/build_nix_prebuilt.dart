/// Build the pinned Nix derivation, then reuse the normal release packager.
import 'dart:io';

import 'package:args/args.dart';

import 'build_prebuilt.dart';
import 'src/build_support.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('output', defaultsTo: 'build/nix-prebuilts')
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln('Build Linux prebuilts using Nix.\n${parser.usage}');
      return;
    }
    if (args.rest.isNotEmpty)
      throw const FormatException('Unexpected arguments');
    // Git flakes omit untracked files. Do not attach a working-tree fingerprint
    // to a derivation built from a different set of inputs.
    final status = await runCommand([
      'git',
      'status',
      '--porcelain',
      '--untracked-files=all',
    ], capture: true);
    if (status!.isNotEmpty) {
      throw StateError(
        'Commit the source and recipes before packaging a release',
      );
    }
    const target = 'x86_64-unknown-linux-gnu';
    final fingerprint = await sourceSha256();
    final channel = await toolchainChannel();
    final recipe = await sha256File(File('flake.nix'));
    final lock = await sha256File(File('flake.lock'));
    final output = (await runCommand([
      'nix',
      'build',
      '.#native-linux',
      '--no-link',
      '--print-out-paths',
      '--no-update-lock-file',
      '--cores',
      '8',
      '--max-jobs',
      '2',
    ], capture: true))!;
    if (!output.startsWith('/nix/store/') || output.contains('\n')) {
      throw StateError('Expected one Nix store output, got $output');
    }
    if (await sourceSha256() != fingerprint ||
        await sha256File(File('flake.nix')) != recipe ||
        await sha256File(File('flake.lock')) != lock) {
      throw StateError('Inputs changed during the Nix build');
    }
    await packageBuiltTarget(
      target,
      Directory(args.option('output')!).absolute,
      Directory('$output/lib').uri,
      fingerprint: fingerprint,
      build: {
        'rust_version': channel,
        'target': target,
        'builder': 'nix',
        'flake_sha256': recipe,
        'flake_lock_sha256': lock,
        'store_path': output,
      },
    );
  } catch (error) {
    stderr.writeln('Nix prebuilt build failed: $error');
    exitCode = 1;
  }
}
