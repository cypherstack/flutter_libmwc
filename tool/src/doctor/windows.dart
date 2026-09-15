import 'dart:convert';
import 'dart:io';

import 'common.dart';

Future<String> _powershell(String script, {Map<String, String>? environment}) {
  final system = Platform.environment['SystemRoot'];
  if (system == null) throw StateError('SystemRoot is unavailable');
  return probe('$system\\System32\\WindowsPowerShell\\v1.0\\powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    "\$ErrorActionPreference = 'Stop'; $script",
  ], environment: environment);
}

Future<void> checkWindows(DoctorOptions options, DoctorReport report) async {
  Future<String> read(String path) =>
      File.fromUri(report.root.resolve(path)).readAsString();
  Future<List<dynamic>> pins() async =>
      jsonDecode(await read('reproducible/windows/tools.lock.json')) as List;
  final flutter = options.flutter ?? 'flutter';
  // PowerShell invokes .bat with a literal environment-provided path, preserving
  // spaces and metacharacters without composing cmd.exe source from user input.
  Future<String> flutterProbe(bool desktop) => _powershell(
    desktop
        ? r'& $env:MWC_DOCTOR_FLUTTER doctor -v; exit $LASTEXITCODE'
        : r'& $env:MWC_DOCTOR_FLUTTER --version --machine; exit $LASTEXITCODE',
    environment: {'MWC_DOCTOR_FLUTTER': flutter},
  );

  await report.check('architecture', () async {
    final arch =
        Platform.environment['PROCESSOR_ARCHITEW6432'] ??
        Platform.environment['PROCESSOR_ARCHITECTURE'];
    if (arch != 'AMD64')
      throw StateError('Use Windows x64; ARM64/emulation is unverified.');
    report.add('architecture', 'pass', 'Windows x64');
  });
  await report.check('git', () async {
    report.add('git', 'pass', await probe('git', ['--version']));
  });
  await report.check('flutter', () async {
    final version = jsonDecode(await flutterProbe(false)) as Map;
    final requirements = await read('pubspec.yaml');
    final flutterMin = RegExp(r'flutter:.*?>=([\d.]+)')
        .firstMatch(requirements)
        ?.group(1);
    final dartMin = RegExp(r'sdk:.*?>=([\d.]+)')
        .firstMatch(requirements)
        ?.group(1);
    if (flutterMin == null || dartMin == null)
      throw StateError('Cannot read SDK minimums from pubspec.yaml');
    final fv = version['frameworkVersion'] as String;
    final dv = version['dartSdkVersion'] as String;
    if (!versionAtLeast(fv, flutterMin) ||
        !versionAtLeast(dv, dartMin) ||
        versionParts(dv)[0] >= 4) {
      throw StateError(
        'Need Flutter >= $flutterMin and Dart >= $dartMin < 4.0.0; '
        'found Flutter $fv, Dart $dv. Select --flutter with a compatible SDK.',
      );
    }
    final ci = RegExp("flutter-version: '([^']+)'")
        .firstMatch(await read('.github/workflows/reproducible-windows.yml'))
        ?.group(1);
    if (ci == null) throw StateError('Cannot read Windows CI Flutter version');
    report.add(
      'flutter',
      fv == ci ? 'pass' : 'warn',
      'Flutter $fv, Dart $dv; CI uses Flutter $ci. Use that SDK for the closest match.',
    );
    if (!versionAtLeast(Platform.version, dartMin) ||
        versionParts(Platform.version)[0] >= 4) {
      report.add(
        'dart-runtime',
        'fail',
        'This command runs with Dart ${Platform.version}; '
            'use the selected Flutter SDK\'s dart executable for builds.',
      );
    } else {
      report.add(
        'dart-runtime',
        'pass',
        'Dart ${Platform.version.split(' ').first}: ${Platform.resolvedExecutable}',
      );
    }
  });
  await report.check('powershell-extraction', () async {
    await _powershell(
      'Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile].FullName',
    );
    report.add(
      'powershell-extraction',
      'pass',
      'Windows ZIP extraction API available',
    );
  });
  Future<void> storage(
    String name,
    String path,
    bool fresh,
  ) => report.check(name, () async {
    final directory = Directory(path).absolute;
    if (fresh &&
        await FileSystemEntity.type(directory.path) !=
            FileSystemEntityType.notFound) {
      throw StateError(
        'Choose a fresh, nonexistent work path: ${directory.path}',
      );
    }
    var ancestor = directory;
    while (!await ancestor.exists()) {
      if (await FileSystemEntity.type(ancestor.path) !=
              FileSystemEntityType.notFound ||
          ancestor.parent.path == ancestor.path) {
        throw StateError('No usable directory at ${ancestor.path}');
      }
      ancestor = ancestor.parent;
    }
    final volume = jsonDecode(
      await _powershell(
        r'Get-Volume -FilePath $env:MWC_DOCTOR_PATH | Select-Object FileSystemType, SizeRemaining | ConvertTo-Json -Compress',
        environment: {'MWC_DOCTOR_PATH': await ancestor.resolveSymbolicLinks()},
      ),
    ) as Map;
    if (volume['FileSystemType'] != 'NTFS') {
      throw StateError(
        'Use NTFS for $name; ${ancestor.path} uses ${volume['FileSystemType']}.',
      );
    }
    final temporary = await ancestor.createTemp('mwc-doctor-');
    final file = File.fromUri(temporary.uri.resolve('probe'));
    try {
      final handle = await file.open(mode: FileMode.write);
      try {
        await handle.writeByte(42);
        await handle.lock(FileLock.exclusive, 0, 1);
        await handle.unlock(0, 1);
      } finally {
        await handle.close();
      }
      await file.setLastModified(DateTime.utc(1970, 1, 1, 0, 0, 1));
    } finally {
      if (await file.exists()) await file.delete();
      await temporary.delete();
    }
    // Match the builder's rejection of configuration in every work ancestor.
    for (var parent = directory; ; parent = parent.parent) {
      for (final config in ['.cargo/config', '.cargo/config.toml']) {
        if (await File.fromUri(parent.uri.resolve(config)).exists()) {
          throw StateError(
            'Ambient Cargo configuration under ${parent.path}; choose another work/cache tree.',
          );
        }
      }
      if (parent.parent.path == parent.path) break;
    }
    final free = (volume['SizeRemaining'] as num) / (1024 * 1024 * 1024);
    report.add(
      name,
      'pass',
      '${directory.path}: NTFS write/lock/old timestamp probes passed; ${free.toStringAsFixed(1)} GiB free',
    );
    if (free < 25)
      report.add(
        '$name-space',
        'warn',
        'Allow roughly 25 GiB free for a fresh build; retained builds need more.',
      );
  });
  await report.check('cache-location', () async {
    final local = Platform.environment['LOCALAPPDATA'];
    if (options.cache == null && (local == null || local.isEmpty)) {
      throw StateError('LOCALAPPDATA unavailable; provide --cache');
    }
    await storage('cache', options.cache ?? '$local\\flutter_libmwc', false);
  });
  if (options.work != null) await storage('work', options.work!, true);
  await report.check('recipe', () async {
    for (final path in [
      'rust/Cargo.lock',
      'rust/rust-toolchain.toml',
      'reproducible/windows/build.py',
      'reproducible/windows/provision.py',
      'reproducible/windows/archive.py',
      'reproducible/windows/audit.py',
      'reproducible/windows/static-smoke.c',
      'hook/src/windows_builder.dart',
    ]) {
      if (!await File.fromUri(report.root.resolve(path)).exists())
        throw StateError('Missing recipe input: $path');
    }
    final tools = await pins();
    if (tools.isEmpty) throw StateError('Empty native tool lockfile');
    for (final pin in tools) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(pin['sha256'] as String) ||
          Uri.parse(pin['url'] as String).scheme != 'https')
        throw StateError('Invalid tool pin: ${pin['id']}');
    }
    report.add(
      'recipe',
      'pass',
      '${tools.length} hash-pinned archives. Python, Rust, MSVC, SDK, CMake and protoc are provisioned automatically; no R: required.',
    );
  });
  if (options.release)
    await report.check('release-checkout', () async {
      final head = await probe('git', [
        '-C',
        report.root.toFilePath(),
        'rev-parse',
        'HEAD',
      ]);
      final dirty = await probe('git', [
        '-C',
        report.root.toFilePath(),
        'status',
        '--porcelain',
        '--untracked-files=all',
      ]);
      if (dirty.isNotEmpty)
        throw StateError(
          'Release packaging requires a committed, clean checkout. Preserve outstanding work before building.',
        );
      report.add(
        'release-checkout',
        'pass',
        'Clean commit $head; compare CI at this revision.',
      );
    });
  if (options.network) {
    await report.check('network', () async {
      final python = RegExp("https://www.python.org/[^']+")
          .firstMatch(await read('hook/src/windows_builder.dart'))
          ?.group(0);
      if (python == null) throw StateError('Cannot locate pinned Python URL');
      final urls = {
        python,
        'https://index.crates.io/config.json',
        'https://github.com',
        'https://pub.dev',
        for (final pin in await pins()) pin['url'] as String,
      };
      // One bounded client per request; failures are reported per endpoint.
      await Future.wait(
        urls.map(
          (url) => report.check('network:${Uri.parse(url).host}', () async {
            final client = HttpClient()
              ..connectionTimeout = const Duration(seconds: 20);
            try {
              final response = await (() async => (await client.headUrl(
                Uri.parse(url),
              )).close())().timeout(const Duration(seconds: 20));
              if (response.statusCode < 200 || response.statusCode >= 400)
                throw HttpException(
                  'HEAD returned ${response.statusCode}',
                  uri: Uri.parse(url),
                );
              report.add(
                'network:${Uri.parse(url).host}',
                'pass',
                'HEAD reachable: $url',
              );
            } finally {
              client.close(force: true);
            }
          }),
        ),
      );
      report.add(
        'network-scope',
        'warn',
        'HEAD probes do not verify full downloads or every Cargo Git dependency; the builder verifies downloaded archive hashes.',
      );
    });
  } else {
    report.add(
      'network',
      'warn',
      'Not probed. Use --network; builds need access to locked Cargo sources.',
    );
  }
  if (options.desktop)
    await report.check('flutter-desktop', () async {
      final text = await flutterProbe(true);
      final line = text
          .split('\n')
          .where((line) => RegExp(r'^\[.*\] Visual Studio').hasMatch(line))
          .firstOrNull;
      if (line == null || !line.startsWith('[\u2713]'))
        throw StateError(
          'Run flutter doctor -v to resolve Windows desktop prerequisites. ${line ?? ''}',
        );
      report.add('flutter-desktop', 'pass', line.trim());
    });
}
