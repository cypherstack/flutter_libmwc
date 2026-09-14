import 'dart:io';
import 'dart:isolate';

/// Run with `dart --packages=.dart_tool/package_config.json
/// tool/test_prebuilt.dart` after `flutter pub get`. Invoking the VM directly
/// keeps resolver and release-tool tests independent of the native Cargo hook.
Future<void> main(List<String> args) async {
  final root = Platform.script.resolve('../');
  final packageConfig = File.fromUri(
    root.resolve('.dart_tool/package_config.json'),
  );
  if (!await packageConfig.exists()) {
    stderr.writeln('Run flutter pub get before testing the prebuilt resolver.');
    exitCode = 1;
    return;
  }
  final testLibrary = await Isolate.resolvePackageUri(
    Uri.parse('package:test/test.dart'),
  );
  if (testLibrary == null) {
    stderr.writeln('Cannot resolve package:test. Run flutter pub get first.');
    exitCode = 1;
    return;
  }
  final runner = File.fromUri(testLibrary.resolve('../bin/test.dart'));
  final process = await Process.start(
    Platform.resolvedExecutable,
    [
      '--packages=${packageConfig.path}',
      runner.path,
      if (args.isEmpty) ...[
        'test/prebuilt_test.dart',
        'test/prebuilt_producer_test.dart',
      ] else
        ...args,
    ],
    workingDirectory: root.toFilePath(),
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
