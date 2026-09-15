/// Shared Windows source builder for native hooks and release production.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import 'source_fingerprint.dart';

const windowsTarget = 'x86_64-pc-windows-msvc';
const _pythonUrl =
    'https://www.python.org/ftp/python/3.13.7/python-3.13.7-embed-amd64.zip';
const _pythonSha =
    'f6cca216a359be84797cabb54149ce5e062afb16cc7567eb7fc51cacb2d86b65';
const _outputs = ['mwc_wallet.dll', 'mwc_wallet.lib', 'build-evidence.json'];

Future<String> _hash(File file) async =>
    (await crypto.sha256.bind(file.openRead()).first).toString();

Future<void> _run(
  List<String> command, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    environment: environment,
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final status = await process.exitCode;
  if (status != 0)
    throw ProcessException(
      command.first,
      command.skip(1).toList(),
      'Native build failed',
      status,
    );
}

Directory defaultWindowsCache() {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null || local.isEmpty) {
    throw StateError('Windows LOCALAPPDATA is unavailable.');
  }
  return Directory.fromUri(Directory(local).uri.resolve('flutter_libmwc/'));
}

Future<File> _python(Directory cache, Directory temporary) async {
  final zip = File.fromUri(cache.uri.resolve('python-$_pythonSha.zip'));
  if (!await zip.exists() || await _hash(zip) != _pythonSha) {
    final download = File.fromUri(temporary.uri.resolve('python.zip'));
    stderr.writeln('flutter_libmwc: downloading verified Python build runtime');
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(_pythonUrl)))
          .close();
      if (response.statusCode != 200) {
        throw HttpException('Python download returned ${response.statusCode}');
      }
      final sink = download.openWrite();
      try {
        var bytes = 0;
        await for (final chunk in response) {
          bytes += chunk.length;
          if (bytes > 64 * 1024 * 1024)
            throw const FormatException('Python download exceeds size limit');
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (await _hash(download) != _pythonSha)
        throw StateError('Python download digest mismatch');
      if (await zip.exists()) await zip.delete();
      await download.rename(zip.path);
    } finally {
      client.close(force: true);
    }
  }
  // Extract afresh from the verified archive. A modified extracted executable
  // must never silently become a trusted cache hit.
  final destination = Directory.fromUri(temporary.uri.resolve('python/'));
  final systemRoot = Platform.environment['SystemRoot']!;
  await _run(
    [
      '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($env:MWC_PYTHON_ZIP, $env:MWC_PYTHON_DEST)",
    ],
    environment: {
      'MWC_PYTHON_ZIP': zip.path,
      'MWC_PYTHON_DEST': destination.path,
    },
  );
  return File.fromUri(destination.uri.resolve('python.exe'));
}

Future<bool> _validOutput(Directory output, String fingerprint) async {
  try {
    final metadata = jsonDecode(
      await File.fromUri(output.uri.resolve('cache.json')).readAsString(),
    ) as Map<String, dynamic>;
    if (metadata['source_sha256'] != fingerprint ||
        metadata['target'] != windowsTarget)
      return false;
    final hashes = metadata['sha256'] as Map<String, dynamic>;
    for (final name in _outputs) {
      if (await _hash(File.fromUri(output.uri.resolve(name))) != hashes[name])
        return false;
    }
    return true;
  } on FileSystemException {
    return false;
  } on FormatException {
    return false;
  } on TypeError {
    return false;
  }
}

/// Returns a directory containing both libraries and their build evidence.
/// An explicit [work] must be fresh and is retained for clean-build inspection.
/// Default calls reuse only hash-checked outputs keyed by the complete recipe.
Future<Directory> buildWindowsNative(
  Uri packageRoot, {
  Directory? cache,
  Directory? work,
  bool clean = false,
}) async {
  if (!Platform.isWindows)
    throw UnsupportedError('The pinned MSVC builder requires Windows x64.');
  cache = (cache ?? defaultWindowsCache()).absolute;
  await cache.create(recursive: true);
  final fingerprint = (await sourceFingerprint(packageRoot)).sha256;
  final output = Directory.fromUri(cache.uri.resolve('outputs/$fingerprint/'));
  // An OS file lock is released on process termination. Serialize this cache's
  // provisioning/builds so interrupted processes cannot leave stale locks.
  final lock = await File.fromUri(cache.uri.resolve('builder.lock'))
      .open(mode: FileMode.append);
  await lock.lock(FileLock.blockingExclusive);
  Directory? temporary;
  try {
    if (!clean && work == null && await _validOutput(output, fingerprint)) {
      stderr.writeln('flutter_libmwc: reusing verified Windows native build');
      return output;
    }
    temporary = await cache.createTemp('building-');
    final python = await _python(cache, temporary);
    final build =
        work?.absolute ?? Directory.fromUri(temporary.uri.resolve('work/'));
    final downloads = Directory.fromUri(cache.uri.resolve('downloads/'));
    stderr.writeln(
      'flutter_libmwc: building Windows native libraries with pinned tools',
    );
    await _run([
      python.path,
      packageRoot.resolve('reproducible/windows/build.py').toFilePath(),
      '--root',
      packageRoot.toFilePath(),
      '--work',
      build.path,
      '--cache',
      downloads.path,
    ]);
    if ((await sourceFingerprint(packageRoot)).sha256 != fingerprint) {
      throw StateError(
        'Native source or recipe changed during the build; retry.',
      );
    }
    final staged = Directory.fromUri(temporary.uri.resolve('output/'));
    await staged.create();
    for (final name in _outputs) {
      final source = name == 'build-evidence.json'
          ? build.uri.resolve(name)
          : build.uri.resolve('target/$windowsTarget/release/$name');
      await File.fromUri(source).copy(staged.uri.resolve(name).toFilePath());
    }
    final hashes = <String, String>{};
    for (final name in _outputs) {
      hashes[name] = await _hash(File.fromUri(staged.uri.resolve(name)));
    }
    await File.fromUri(staged.uri.resolve('cache.json')).writeAsString(
      jsonEncode({
        'source_sha256': fingerprint,
        'target': windowsTarget,
        'sha256': hashes,
      }),
    );
    await output.parent.create(recursive: true);
    // Keep a valid entry immutable while other callers may be copying it.
    // A clean rebuild of the same inputs must reproduce both library hashes.
    if (await _validOutput(output, fingerprint)) {
      for (final name in _outputs.take(2)) {
        if (await _hash(File.fromUri(output.uri.resolve(name))) !=
            hashes[name]) {
          throw StateError('Clean Windows rebuild differs for $name');
        }
      }
      return output;
    }
    if (await output.exists()) await output.delete(recursive: true);
    await staged.rename(output.path);
    return output;
  } finally {
    if (temporary != null && await temporary.exists())
      await temporary.delete(recursive: true);
    await lock.unlock();
    await lock.close();
  }
}
