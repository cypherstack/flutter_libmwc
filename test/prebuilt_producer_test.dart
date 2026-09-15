import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/build_prebuilt.dart';
import '../tool/prebuilt_manifest.dart';
import '../tool/src/build_support.dart';

void main() {
  late Directory temporary;
  late Directory source;
  late Directory artifacts;
  late Directory output;
  late File library;
  late File fragmentFile;
  late Map<String, Object?> fragment;

  Future<void> saveFragment() =>
      fragmentFile.writeAsString(jsonEncode(fragment));

  Future<ManifestResult> assemble({bool requireAll = false}) =>
      assemblePrebuilts(
        artifacts,
        output,
        root: source.uri,
        requireAll: requireAll,
      );

  Map<String, Object?> firstEntry() =>
      (fragment['artifacts'] as List).first as Map<String, Object?>;

  Matcher invalid(String message) => throwsA(
    isA<FormatException>().having(
      (error) => error.message,
      'message',
      contains(message),
    ),
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('mwc-producer-test-');
    source = Directory.fromUri(temporary.uri.resolve('source/'));
    artifacts = await Directory.fromUri(temporary.uri.resolve('artifacts/'))
        .create();
    output = Directory.fromUri(temporary.uri.resolve('release/'));
    for (final relative in [
      'rust/Cargo.toml',
      'rust/Cargo.lock',
      'rust/rust-toolchain.toml',
      'rust/src/lib.rs',
      'hook/build.dart',
      'lib/mwc.dart',
      'tool/build_prebuilt.dart',
      'tool/src/build_support.dart',
      'flake.nix',
      'flake.lock',
      'reproducible/audit_linux.py',
      'tool/build_nix_prebuilt.dart',
      'tool/build_macos_prebuilt.dart',
      'reproducible/macos/package.nix',
      'reproducible/macos/audit.py',
      'tool/build_windows_prebuilt.dart',
      'reproducible/windows/build.ps1',
      'reproducible/windows/build.py',
      'reproducible/windows/audit.py',
      'reproducible/windows/archive.py',
      'reproducible/windows/static-smoke.c',
      'reproducible/windows/provision.py',
      'reproducible/windows/tools.lock.json',
    ]) {
      final file = File.fromUri(source.uri.resolve(relative));
      await file.parent.create(recursive: true);
      await file.writeAsString('$relative\n');
    }
    library = File.fromUri(artifacts.uri.resolve('mwc_wallet-test.dll'));
    await library.writeAsString('native-binary-fixture');
    fragment = {
      'schema_version': 1,
      'package': 'flutter_libmwc',
      'source_sha256': await sourceSha256(source.uri),
      'artifacts': [
        <String, Object?>{
          'target': 'x86_64-pc-windows-msvc',
          'link_mode': 'dynamic',
          'file': library.uri.pathSegments.last,
          'size': await library.length(),
          'sha256': await sha256File(library),
        },
      ],
    };
    fragmentFile = File.fromUri(artifacts.uri.resolve('fragment.json'));
    await saveFragment();
  });

  tearDown(() => temporary.delete(recursive: true));

  test('source identity includes newly added nested Rust files', () async {
    final original = await sourceSha256(source.uri);
    final file = File.fromUri(source.uri.resolve('rust/src/new/module.rs'));
    await file.parent.create();
    await file.writeAsString('fn changed() {}');
    expect(await sourceSha256(source.uri), isNot(original));
  });

  test(
    'source identity ignores docs and includes release build policy',
    () async {
      final original = await sourceSha256(source.uri);
      await File.fromUri(source.uri.resolve('README.md')).writeAsString('docs');
      expect(await sourceSha256(source.uri), original);
      await File.fromUri(source.uri.resolve('tool/src/build_support.dart'))
          .writeAsString('new policy');
      expect(await sourceSha256(source.uri), isNot(original));
    },
  );

  test('Nix recipe and lock changes invalidate source identity', () async {
    for (final path in [
      'flake.nix',
      'flake.lock',
      'reproducible/audit_linux.py',
      'tool/build_nix_prebuilt.dart',
      'tool/build_macos_prebuilt.dart',
      'reproducible/macos/package.nix',
      'reproducible/macos/audit.py',
      'tool/build_windows_prebuilt.dart',
      'reproducible/windows/build.ps1',
      'reproducible/windows/build.py',
      'reproducible/windows/audit.py',
      'reproducible/windows/archive.py',
      'reproducible/windows/static-smoke.c',
      'reproducible/windows/provision.py',
      'reproducible/windows/tools.lock.json',
    ]) {
      final before = await sourceSha256(source.uri);
      await File.fromUri(source.uri.resolve(path)).writeAsString('changed');
      expect(await sourceSha256(source.uri), isNot(before), reason: path);
    }
  });

  test(
    'external producer packages both modes and preserves provenance',
    () async {
      final built = await Directory.fromUri(temporary.uri.resolve('built/'))
          .create();
      for (final name in ['mwc_wallet.dll', 'mwc_wallet.lib']) {
        await File.fromUri(built.uri.resolve(name))
            .writeAsString('fixture $name');
      }
      final fingerprint = await sourceSha256(source.uri);
      await packageBuiltTarget(
        'x86_64-pc-windows-msvc',
        output,
        built.uri,
        fingerprint: fingerprint,
        build: {'builder': 'test', 'rust_version': '1.90.0'},
      );
      final data = jsonDecode(
        await File.fromUri(output.uri.resolve('x86_64-pc-windows-msvc.json'))
            .readAsString(),
      ) as Map;
      expect((data['artifacts'] as List).length, 2);
      expect(data['source_sha256'], fingerprint);
      expect(data['build']['builder'], 'test');
      await expectLater(
        packageBuiltTarget(
          'x86_64-pc-windows-msvc',
          output,
          built.uri,
          fingerprint: fingerprint,
          build: {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'external producer rejects a missing link mode before writing',
    () async {
      final built = await Directory.fromUri(temporary.uri.resolve('built/'))
          .create();
      await File.fromUri(built.uri.resolve('mwc_wallet.dll'))
          .writeAsString('fixture');
      await expectLater(
        packageBuiltTarget(
          'x86_64-pc-windows-msvc',
          output,
          built.uri,
          fingerprint: await sourceSha256(source.uri),
          build: {},
        ),
        throwsStateError,
      );
      expect(await output.exists(), isFalse);
    },
  );

  test('assembled pin matches exact manifest', () async {
    final result = await assemble();
    expect(
      result.sha256,
      await sha256File(File.fromUri(output.uri.resolve('manifest.json'))),
    );
    expect(
      await File.fromUri(output.uri.resolve('mwc_wallet-test.dll'))
          .readAsBytes(),
      await library.readAsBytes(),
    );
    final pinFile = File.fromUri(output.uri.resolve('manifest.sha256'));
    expect(await pinFile.readAsString(), '${result.sha256}  manifest.json\n');
  });

  test(
    'same-length corrupted artifact fails before output publication',
    () async {
      final bytes = await library.readAsBytes();
      bytes[0] ^= 1;
      await library.writeAsBytes(bytes);
      await expectLater(assemble(), invalid('checksum mismatch'));
      expect(await output.exists(), isFalse);
    },
  );

  test('changed native sources reject old fragments', () async {
    await File.fromUri(source.uri.resolve('hook/build.dart'))
        .writeAsString('new source');
    await expectLater(assemble(), invalid('fingerprint mismatch'));
  });

  test('artifact filename cannot traverse out of its directory', () async {
    firstEntry()['file'] = '../outside.dll';
    await saveFragment();
    await expectLater(assemble(), invalid('Unsafe artifact filename'));
  });

  test('same target and mode cannot appear twice', () async {
    (fragment['artifacts'] as List).add(
      Map<String, Object?>.from(firstEntry()),
    );
    await saveFragment();
    await expectLater(assemble(), invalid('Duplicate artifact'));
  });

  test('full release requires every supported target and link mode', () async {
    await expectLater(
      assemble(requireAll: true),
      invalid('Missing release artifacts'),
    );
    final entries = <Map<String, Object?>>[];
    for (final target in releaseTargets.entries) {
      for (final mode in ['static', 'dynamic']) {
        final suffix = libraryNames(target.key)[mode]!.split('.').last;
        final filename = 'mwc_wallet-${target.key}-$mode.$suffix';
        final file = File.fromUri(artifacts.uri.resolve(filename));
        await file.writeAsString('${target.key}/$mode');
        entries.add({
          'target': target.key,
          'link_mode': mode,
          'file': filename,
          'size': await file.length(),
          'sha256': await sha256File(file),
          ...target.value,
        });
      }
    }
    fragment['artifacts'] = entries;
    await saveFragment();
    final result = await assemble(requireAll: true);
    expect(result.manifest['artifacts'], hasLength(releaseTargets.length * 2));
  });

  test('existing release output is never mixed with a new release', () async {
    await assemble();
    await expectLater(
      assemble(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Release output must be empty'),
        ),
      ),
    );
  });

  test('incorrect advertised deployment minimum is rejected', () async {
    firstEntry().addAll({
      'target': 'aarch64-linux-android',
      'minimum_os_version': 16,
    });
    await saveFragment();
    await expectLater(assemble(), invalid('Incorrect minimum_os_version'));
  });

  test('noninteger sizes and unsupported schemas are rejected', () async {
    firstEntry()['size'] = true;
    await saveFragment();
    await expectLater(assemble(), invalid('Artifact size mismatch'));
    firstEntry()['size'] = await library.length();
    fragment['schema_version'] = true;
    await saveFragment();
    await expectLater(assemble(), invalid('Unsupported build fragment'));
  });

  test(
    'artifact symlinks are rejected',
    () async {
      final original = File.fromUri(temporary.uri.resolve('original.dll'));
      await library.rename(original.path);
      await Link(library.path).create(original.path);
      await expectLater(assemble(), invalid('Missing or nonregular artifact'));
    },
    skip: Platform.isWindows
        ? 'Creating links requires Windows privileges'
        : false,
  );

  test(
    'build CLI dry-run preserves release policy without invoking Rust',
    () async {
      final packageConfig = packageRoot
          .resolve('.dart_tool/package_config.json')
          .toFilePath();
      final process = await Process.run(Platform.resolvedExecutable, [
        '--packages=$packageConfig',
        packageRoot.resolve('tool/build_prebuilt.dart').toFilePath(),
        '--target',
        'aarch64-linux-android',
        '--dry-run',
      ], workingDirectory: packageRoot.toFilePath());
      expect(process.exitCode, 0, reason: process.stderr.toString());
      final plan = jsonDecode(process.stdout as String) as Map<String, dynamic>;
      expect(plan['source_sha256'], await sourceSha256());
      expect(plan['target'], 'aarch64-linux-android');
      expect(
        plan['cargo_arguments'],
        containsAll(['--release', '--locked', '--lib']),
      );
      expect(plan['compatibility'], {'minimum_os_version': 21});
      expect(plan['android_ndk'], androidNdkVersion);
      expect(plan['libraries'], {
        'dynamic': 'libmwc_wallet.so',
        'static': 'libmwc_wallet.a',
      });
    },
  );

  test('manifest CLI help works without mandatory build inputs', () async {
    final process = await Process.run(Platform.resolvedExecutable, [
      '--packages=${packageRoot.resolve('.dart_tool/package_config.json').toFilePath()}',
      packageRoot.resolve('tool/prebuilt_manifest.dart').toFilePath(),
      '--help',
    ], workingDirectory: packageRoot.toFilePath());
    expect(process.exitCode, 0, reason: process.stderr.toString());
    expect(process.stdout, contains('--artifacts'));
    expect(process.stdout, contains('--require-all'));
  });

  test('Linux Rust flags locate the actual static C++ archive', () async {
    final env = await buildEnvironment('x86_64-unknown-linux-gnu');
    final searchPath = env['CARGO_ENCODED_RUSTFLAGS']!
        .split('\u001f')
        .singleWhere((flag) => flag.startsWith('-Lnative='))
        .substring('-Lnative='.length);
    final archive = File.fromUri(
      Directory(searchPath).uri.resolve('libstdc++.a'),
    );
    final header = await archive
        .openRead(0, 8)
        .expand((bytes) => bytes)
        .toList();
    expect(ascii.decode(header), '!<arch>\n');
    expect(env['CXXSTDLIB_x86_64_unknown_linux_gnu'], 'static=stdc++');
  }, skip: !Platform.isLinux);

  test('Linux metadata audit compares glibc versions numerically', () {
    auditLinuxMetadata(
      'Name: GLIBC_2.9 Name: GLIBC_2.35',
      '(NEEDED) Shared library: [libc.so.6]',
      '2.35',
    );
    expect(
      () => auditLinuxMetadata('Name: GLIBC_2.36', '', '2.35'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('above 2.35'),
        ),
      ),
    );
  });

  test('Linux metadata audit rejects a dynamic C++ runtime dependency', () {
    expect(
      () => auditLinuxMetadata(
        'Name: GLIBC_2.35',
        '(NEEDED) Shared library: [libstdc++.so.6]',
        '2.35',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unexpected shared dependencies'),
        ),
      ),
    );
  });
}
