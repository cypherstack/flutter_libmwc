import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:hooks/hooks.dart';

import 'source_fingerprint.dart';

const _maximumArtifactBytes = 2 * 1024 * 1024 * 1024;
final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

String _digest(Object? value, String label) {
  if (value is! String || !_sha256Pattern.hasMatch(value)) {
    throw FormatException(
      '$label must be a SHA-256 digest (64 hex characters).',
    );
  }
  return value.toLowerCase();
}

void _requireHttps(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw FormatException(
      'Prebuilt URLs must use HTTPS without credentials or fragments.',
    );
  }
}

class PrebuiltOptions {
  final String nativeBuild;
  final Uri? manifestUrl;
  final String? manifestSha256;

  PrebuiltOptions._(this.nativeBuild, this.manifestUrl, this.manifestSha256);

  factory PrebuiltOptions.fromInput(BuildInput input) {
    final defines = input.userDefines;
    final mode = defines['native_build'] ?? 'source';
    if (mode != 'source' && mode != 'prebuilt') {
      throw FormatException(
        'flutter_libmwc.native_build must be source or prebuilt.',
      );
    }
    if (mode == 'source') {
      return PrebuiltOptions._('source', null, null);
    }
    final rawUrl = defines['prebuilt_manifest_url'];
    if (rawUrl is! String || rawUrl.isEmpty) {
      throw FormatException('Prebuilt mode requires prebuilt_manifest_url.');
    }
    final url = Uri.parse(rawUrl);
    _requireHttps(url);
    final digest = _digest(
      defines['prebuilt_manifest_sha256'],
      'prebuilt_manifest_sha256',
    );
    return PrebuiltOptions._('prebuilt', url, digest);
  }
}

class PrebuiltTarget {
  final String triple;
  final String linkMode;
  final int? minimumVersion;
  final String libraryFileName;

  PrebuiltTarget._(
    this.triple,
    this.linkMode,
    this.minimumVersion,
    this.libraryFileName,
  );

  factory PrebuiltTarget.fromConfig(CodeConfig code) {
    if (code.sanitizer != null) {
      throw UnsupportedError('Prebuilt binaries do not support sanitizers.');
    }
    final triple = switch ((code.targetOS, code.targetArchitecture)) {
      (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
      (OS.android, Architecture.arm64) => 'aarch64-linux-android',
      (OS.android, Architecture.x64) => 'x86_64-linux-android',
      (OS.iOS, Architecture.arm64) when code.iOS.targetSdk == IOSSdk.iPhoneOS =>
        'aarch64-apple-ios',
      (OS.iOS, Architecture.arm64)
          when code.iOS.targetSdk == IOSSdk.iPhoneSimulator =>
        'aarch64-apple-ios-sim',
      (OS.iOS, Architecture.x64)
          when code.iOS.targetSdk == IOSSdk.iPhoneSimulator =>
        'x86_64-apple-ios',
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
      (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
      (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
      (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
      _ => throw UnsupportedError(
        'No prebuilt target for ${code.targetOS}/${code.targetArchitecture}.',
      ),
    };
    final mode = switch (code.linkModePreference) {
      LinkModePreference.dynamic ||
      LinkModePreference.preferDynamic => 'dynamic',
      LinkModePreference.static || LinkModePreference.preferStatic => 'static',
      _ => throw UnsupportedError('Unsupported native link mode.'),
    };
    final minimum = switch (code.targetOS) {
      OS.android => code.android.targetNdkApi,
      OS.iOS => code.iOS.targetVersion,
      OS.macOS => code.macOS.targetVersion,
      _ => null,
    };
    final linkMode = mode == 'static'
        ? StaticLinking()
        : DynamicLoadingBundled();
    return PrebuiltTarget._(
      triple,
      mode,
      minimum,
      code.targetOS.libraryFileName('mwc_wallet', linkMode),
    );
  }
}

class PrebuiltArtifact {
  final String file;
  final String sha256;
  final int size;

  PrebuiltArtifact._(this.file, this.sha256, this.size);

  factory PrebuiltArtifact.select(
    Map<String, dynamic> manifest,
    PrebuiltTarget target, {
    required String sourceSha256,
  }) {
    if (manifest['schema_version'] != 1 ||
        manifest['package'] != 'flutter_libmwc') {
      throw FormatException('Unsupported flutter_libmwc prebuilt manifest.');
    }
    if (_digest(manifest['source_sha256'], 'source_sha256') != sourceSha256) {
      throw StateError(
        'Prebuilt source fingerprint does not match this package. '
        'Select a release built from this source or set native_build: source.',
      );
    }
    final artifacts = manifest['artifacts'];
    if (artifacts is! List ||
        artifacts.any((entry) => entry is! Map<String, dynamic>)) {
      throw FormatException('Manifest artifacts must be a list of objects.');
    }
    final matches = artifacts
        .cast<Map<String, dynamic>>()
        .where(
          (entry) =>
              entry['target'] == target.triple &&
              entry['link_mode'] == target.linkMode,
        )
        .toList();
    if (matches.length != 1) {
      throw StateError(
        'Expected one ${target.triple}/${target.linkMode} prebuilt; '
        'found ${matches.length}. Select another release or use native_build: source.',
      );
    }
    final entry = matches.single;
    final file = entry['file'];
    if (file is! String ||
        !RegExp(r'^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*\.(so|dylib|dll|a|lib)$')
            .hasMatch(file)) {
      throw FormatException(
        'Prebuilt artifact file must be a library basename.',
      );
    }
    final digest = _digest(entry['sha256'], 'artifact sha256');
    final size = entry['size'];
    if (size is! int || size <= 0 || size > _maximumArtifactBytes) {
      throw FormatException(
        'Prebuilt artifact size must be between 1 byte and 2 GiB.',
      );
    }
    if (target.minimumVersion != null) {
      final minimum = entry['minimum_os_version'];
      if (minimum is! int || minimum <= 0) {
        throw FormatException('Artifact must declare minimum_os_version.');
      }
      if (minimum > target.minimumVersion!) {
        throw UnsupportedError(
          'Prebuilt requires OS/API $minimum, but the app targets '
          '${target.minimumVersion}. Use native_build: source or a compatible release.',
        );
      }
    }
    if (target.triple.endsWith('linux-gnu')) {
      final glibc = entry['minimum_glibc_version'];
      if (glibc is! String || !RegExp(r'^\d+\.\d+$').hasMatch(glibc)) {
        throw FormatException(
          'Linux prebuilt must declare minimum_glibc_version.',
        );
      }
    }
    return PrebuiltArtifact._(file, digest, size);
  }
}

/// Downloads fresh bytes and verifies them before making the file available.
class VerifiedDownloader {
  final Directory directory;
  final HttpClient? client;

  VerifiedDownloader(this.directory, {this.client});

  Future<File> get(
    Uri uri,
    String digest, {
    int? size,
    int maxBytes = _maximumArtifactBytes,
  }) async {
    _requireHttps(uri);
    digest = _digest(digest, 'download digest');
    await directory.create(recursive: true);
    final file = File.fromUri(directory.uri.resolve(digest));
    final temporaryDirectory = await directory.createTemp('.download-');
    final temporary = File.fromUri(temporaryDirectory.uri.resolve('asset'));
    final http = client ?? HttpClient();
    try {
      http.autoUncompress = false;
      http.connectionTimeout = const Duration(seconds: 30);
      final download = _download(http, uri, temporary, size ?? maxBytes);
      try {
        await download.timeout(const Duration(minutes: 10));
      } on TimeoutException {
        // Stop I/O before deleting the partial download, including on Windows.
        http.close(force: true);
        try {
          await download;
        } catch (_) {
          // Preserve the timeout that triggered cancellation.
        }
        rethrow;
      }
      await _verify(temporary, digest, size, maxBytes);
      return await temporary.rename(file.path);
    } finally {
      if (client == null) http.close(force: true);
      await temporaryDirectory.delete(recursive: true);
    }
  }

  Future<void> _verify(File file, String digest, int? size, int maximum) async {
    final length = await file.length();
    if (length > maximum ||
        (size != null && length != size) ||
        (await crypto.sha256.bind(file.openRead()).first).toString() !=
            digest) {
      throw StateError(
        'Prebuilt integrity check failed for ${file.path}. '
        'Never change the pin to bypass verification.',
      );
    }
  }

  Future<void> _download(
    HttpClient http,
    Uri uri,
    File file,
    int maximum,
  ) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      _requireHttps(uri);
      final request = await http
          .getUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen(null).cancel();
        if (location == null)
          throw HttpException('Prebuilt redirect has no Location.');
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.listen(null).cancel();
        throw HttpException(
          'Prebuilt download returned HTTP ${response.statusCode}. '
          'Check that the release is published and publicly accessible.',
        );
      }
      if (response.contentLength > maximum) {
        await response.listen(null).cancel();
        throw StateError('Prebuilt download exceeds the expected size.');
      }
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final bytes in response.timeout(
          const Duration(seconds: 30),
        )) {
          received += bytes.length;
          if (received > maximum)
            throw StateError('Prebuilt download exceeds the expected size.');
          sink.add(bytes);
          // Apply disk backpressure instead of buffering a large library in RAM.
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      return;
    }
    throw HttpException('Too many prebuilt download redirects.');
  }
}

Future<bool> usePrebuilt(
  BuildInput input,
  BuildOutputBuilder output, {
  HttpClient? client,
}) async {
  final options = PrebuiltOptions.fromInput(input);
  if (options.nativeBuild == 'source') return false;
  final target = PrebuiltTarget.fromConfig(input.config.code);
  final source = await sourceFingerprint(input.packageRoot);
  output.dependencies.addAll(source.dependencies);
  // Keep all downloads in Flutter's hook output so flutter clean removes them.
  final outputDirectory = Directory.fromUri(input.outputDirectory);
  await outputDirectory.create(recursive: true);
  final downloads = await outputDirectory.createTemp('.prebuilt-');
  try {
    final downloader = VerifiedDownloader(downloads, client: client);
    final manifestFile = await downloader.get(
      options.manifestUrl!,
      options.manifestSha256!,
      maxBytes: 1024 * 1024,
    );
    final json = jsonDecode(await manifestFile.readAsString());
    if (json is! Map<String, dynamic>)
      throw FormatException('Manifest must be an object.');
    final artifact = PrebuiltArtifact.select(
      json,
      target,
      sourceSha256: source.sha256,
    );
    final downloaded = await downloader.get(
      options.manifestUrl!.resolve(artifact.file),
      artifact.sha256,
      size: artifact.size,
    );
    final destination = input.outputDirectory.resolve(target.libraryFileName);
    final bundled = await downloaded.rename(destination.toFilePath());
    // The hook runner tracks CodeAsset output bytes separately from inputs.
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'mwc.dart',
        file: bundled.uri,
        linkMode: target.linkMode == 'static'
            ? StaticLinking()
            : DynamicLoadingBundled(),
      ),
    );
  } finally {
    await downloads.delete(recursive: true);
  }
  print(
    'Using verified flutter_libmwc prebuilt for ${target.triple}/${target.linkMode}.',
  );
  return true;
}
