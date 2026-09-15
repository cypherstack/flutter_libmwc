import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/doctor/common.dart';

void main() {
  test('entry point runs without pubspec or package configuration', () async {
    final temporary = await Directory.systemTemp.createTemp('mwc-doctor-sdk-');
    try {
      for (final path in [
        'tool/doctor.dart',
        'tool/src/doctor/common.dart',
        'tool/src/doctor/windows.dart',
      ]) {
        final destination = File.fromUri(temporary.uri.resolve(path));
        await destination.parent.create(recursive: true);
        await File(path).copy(destination.path);
      }
      final result = await Process.run(Platform.resolvedExecutable, [
        'tool/doctor.dart',
        '--help',
      ], workingDirectory: temporary.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('Usage: dart tool/doctor.dart'));
    } finally {
      await temporary.delete(recursive: true);
    }
  });
  test('options reject typos and missing values', () {
    expect(() => DoctorOptions.parse(['--cache']), throwsFormatException);
    expect(
      () => DoctorOptions.parse(['--work', '--json']),
      throwsFormatException,
    );
    expect(() => DoctorOptions.parse(['--netwrok']), throwsFormatException);
    final options = DoctorOptions.parse([
      '--cache',
      'C:\\with spaces',
      '--json',
    ]);
    expect(options.cache, 'C:\\with spaces');
    expect(options.json, isTrue);
  });
  test('versions compare numerically and malformed versions fail', () {
    expect(versionAtLeast('3.9.0', '3.13.0'), isFalse);
    expect(versionAtLeast('3.13.3 (stable)', '3.13.0'), isTrue);
    expect(versionAtLeast('4.0.0', '3.13.0'), isTrue);
    expect(() => versionParts('unknown'), throwsFormatException);
  });
  test(
    'failed checks block readiness without stopping subsequent checks',
    () async {
      final report = DoctorReport(Directory.current.uri, 'example-target');
      report.add('disk', 'warn', 'low space');
      expect(report.status, 'ready-with-warnings');
      await report.check('probe', () async => throw StateError('unavailable'));
      await report.check('next', () async => report.add('next', 'pass', 'ok'));
      final json = jsonDecode(report.render(true)) as Map;
      expect(json['status'], 'blocked');
      expect((json['checks'] as List).last['name'], 'next');
      expect(report.blocked, isTrue);
    },
  );
  test('unsupported target emits JSON and a failure exit code', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'tool/doctor.dart',
      '--target',
      'unimplemented-target',
      '--json',
    ]);
    expect(result.exitCode, 1);
    final report = jsonDecode(result.stdout as String) as Map;
    expect(report['status'], 'blocked');
    expect((report['checks'] as List).single['name'], 'target');
  });
  test(
    'Windows preflight rejects existing work and ambient Cargo config',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'mwc-doctor-test-',
      );
      try {
        final cargo = Directory.fromUri(temporary.uri.resolve('.cargo/'));
        await cargo.create();
        await File.fromUri(cargo.uri.resolve('config.toml'))
            .writeAsString('# test');
        final flutter = File(Platform.resolvedExecutable).uri
            .resolve('../../../flutter.bat')
            .toFilePath();
        final result = await Process.run(Platform.resolvedExecutable, [
          'tool/doctor.dart',
          '--flutter',
          flutter,
          '--cache',
          temporary.path,
          '--work',
          temporary.path,
          '--json',
        ]);
        expect(result.exitCode, 1);
        final report = jsonDecode(result.stdout as String) as Map;
        final checks = report['checks'] as List;
        expect(
          checks.any((c) => c['name'] == 'work' && c['status'] == 'fail'),
          isTrue,
        );
        expect(
          checks.any(
            (c) =>
                c['name'] == 'cache' &&
                c['status'] == 'fail' &&
                (c['detail'] as String).contains('Ambient Cargo'),
          ),
          isTrue,
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows ? 'Windows storage probe' : false,
  );
}
