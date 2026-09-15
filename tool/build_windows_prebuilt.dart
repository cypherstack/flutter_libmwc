/// Build with the pinned Windows recipe, then reuse the release packager.
import 'dart:io';

import 'package:args/args.dart';

import 'build_prebuilt.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('work')
    ..addOption('cache')
    ..addFlag('clean', negatable: false)
    ..addOption('output', defaultsTo: 'build/windows-prebuilts');
  try {
    final args = parser.parse(arguments);
    if (!Platform.isWindows || args.rest.isNotEmpty) {
      throw StateError('Run on Windows with the documented arguments');
    }
    await buildWindowsTarget(
      Directory(args.option('output')!),
      work: args.option('work') == null
          ? null
          : Directory(args.option('work')!),
      cache: args.option('cache') == null
          ? null
          : Directory(args.option('cache')!),
      clean: args.flag('clean'),
    );
  } catch (error) {
    stderr.writeln('Windows prebuilt build failed: $error');
    exitCode = 1;
  }
}
