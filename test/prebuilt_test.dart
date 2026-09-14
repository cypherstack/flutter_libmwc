import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

import '../hook/src/prebuilt.dart';
import '../hook/src/source_fingerprint.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('libmwc-prebuilt-test-');
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  Future<_LoopbackClient> serve(
    Future<void> Function(HttpRequest) respond,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = _LoopbackClient(server.port);
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    server.listen(respond);
    return client;
  }

  BuildInput input({
    Map<String, Object?> defines = const {},
    OS os = OS.macOS,
    Architecture architecture = Architecture.arm64,
    LinkModePreference linkMode = LinkModePreference.dynamic,
    IOSSdk sdk = IOSSdk.iPhoneOS,
    int minimumVersion = 13,
    Uri? packageRoot,
    Sanitizer? sanitizer,
  }) {
    final builder = BuildInputBuilder()
      ..setupShared(
        packageRoot: packageRoot ?? Directory.current.uri,
        packageName: 'flutter_libmwc',
        outputDirectoryShared: temporary.uri.resolve('build/native-assets/'),
        outputFile: temporary.uri.resolve('build/output.json'),
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            defines: defines,
            basePath: temporary.uri,
          ),
        ),
      )
      ..setupBuildInput();
    builder.config.setupBuild(linkingEnabled: false);
    builder.addExtension(
      CodeAssetExtension(
        targetArchitecture: architecture,
        targetOS: os,
        linkModePreference: linkMode,
        sanitizer: sanitizer,
        macOS: os == OS.macOS
            ? MacOSCodeConfig(targetVersion: minimumVersion)
            : null,
        iOS: os == OS.iOS
            ? IOSCodeConfig(targetSdk: sdk, targetVersion: minimumVersion)
            : null,
        android: os == OS.android
            ? AndroidCodeConfig(targetNdkApi: minimumVersion)
            : null,
      ),
    );
    return builder.build();
  }

  Map<String, Object?> settings([Map<String, Object?> changes = const {}]) => {
    'native_build': 'prebuilt',
    'prebuilt_manifest_url': 'https://example.invalid/release/manifest.json',
    'prebuilt_manifest_sha256': 'a' * 64,
    ...changes,
  };

  group('consumer settings', () {
    test('defaults to source without requiring a manifest', () async {
      final buildInput = input();
      expect(PrebuiltOptions.fromInput(buildInput).nativeBuild, 'source');
      expect(await usePrebuilt(buildInput, BuildOutputBuilder()), isFalse);
    });

    test('rejects malformed or unsafe settings', () {
      for (final change in <Map<String, Object?>>[
        {'native_build': 'prefer'},
        {'native_build': true},
        {'prebuilt_manifest_url': 'http://example.invalid/manifest.json'},
        {'prebuilt_manifest_url': 'https://user:secret@example.invalid/m.json'},
        {'prebuilt_manifest_sha256': 'a' * 63},
        {'prebuilt_manifest_sha256': 'g' * 64},
      ]) {
        expect(
          () => PrebuiltOptions.fromInput(input(defines: settings(change))),
          throwsA(anything),
          reason: 'Invalid setting must fail: $change',
        );
      }
    });

    test('requires an explicit manifest digest in prebuilt mode', () {
      final defines = settings()..remove('prebuilt_manifest_sha256');
      expect(
        () => PrebuiltOptions.fromInput(input(defines: defines)),
        throwsA(anything),
      );
    });
  });

  Map<String, dynamic> artifact({
    String target = 'aarch64-apple-darwin',
    String linkMode = 'dynamic',
    String file = 'mwc_wallet-aarch64-apple-darwin-dynamic.dylib',
    int minimumVersion = 11,
  }) => {
    'target': target,
    'link_mode': linkMode,
    'file': file,
    'sha256': 'b' * 64,
    'size': 10,
    'minimum_os_version': minimumVersion,
  };

  Map<String, dynamic> manifest(List<Map<String, dynamic>> artifacts) => {
    'schema_version': 1,
    'package': 'flutter_libmwc',
    'source_sha256': 'c' * 64,
    'artifacts': artifacts,
  };

  group('artifact compatibility', () {
    test('rejects sanitizers and unsupported target combinations', () {
      expect(
        () => PrebuiltTarget.fromConfig(
          input(sanitizer: Sanitizer.asan).config.code,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => PrebuiltTarget.fromConfig(
          input(os: OS.iOS, architecture: Architecture.x64).config.code,
        ),
        throwsUnsupportedError,
      );
    });

    test('distinguishes iOS device and simulator on the same architecture', () {
      final device = PrebuiltTarget.fromConfig(input(os: OS.iOS).config.code);
      final simulator = PrebuiltTarget.fromConfig(
        input(os: OS.iOS, sdk: IOSSdk.iPhoneSimulator).config.code,
      );
      expect(device.triple, 'aarch64-apple-ios');
      expect(simulator.triple, 'aarch64-apple-ios-sim');
      expect(
        () => PrebuiltArtifact.select(
          manifest([artifact(target: device.triple)]),
          simulator,
          sourceSha256: 'c' * 64,
        ),
        throwsA(anything),
      );
    });

    test('keeps canonical library filenames across Apple targets', () {
      final arm = PrebuiltTarget.fromConfig(input().config.code);
      final x64 = PrebuiltTarget.fromConfig(
        input(architecture: Architecture.x64).config.code,
      );
      expect(arm.libraryFileName, 'libmwc_wallet.dylib');
      expect(x64.libraryFileName, arm.libraryFileName);
    });

    test('honors both static and preferred static linking', () {
      for (final preference in [
        LinkModePreference.static,
        LinkModePreference.preferStatic,
      ]) {
        final target = PrebuiltTarget.fromConfig(
          input(linkMode: preference).config.code,
        );
        expect(target.linkMode, 'static');
        expect(target.libraryFileName, 'libmwc_wallet.a');
        expect(
          () => PrebuiltArtifact.select(
            manifest([artifact()]),
            target,
            sourceSha256: 'c' * 64,
          ),
          throwsA(anything),
        );
      }
    });

    test('requires matching source and compatible deployment target', () {
      final target = PrebuiltTarget.fromConfig(input().config.code);
      expect(
        PrebuiltArtifact.select(
          manifest([artifact()]),
          target,
          sourceSha256: 'c' * 64,
        ).file,
        'mwc_wallet-aarch64-apple-darwin-dynamic.dylib',
      );
      expect(
        () => PrebuiltArtifact.select(
          manifest([artifact()]),
          target,
          sourceSha256: 'd' * 64,
        ),
        throwsA(anything),
      );
      expect(
        () => PrebuiltArtifact.select(
          manifest([artifact(minimumVersion: 14)]),
          target,
          sourceSha256: 'c' * 64,
        ),
        throwsA(anything),
      );
    });

    test('rejects Android API levels newer than the consumer minimum', () {
      final target = PrebuiltTarget.fromConfig(
        input(os: OS.android, minimumVersion: 24).config.code,
      );
      expect(
        () => PrebuiltArtifact.select(
          manifest([artifact(target: target.triple, minimumVersion: 35)]),
          target,
          sourceSha256: 'c' * 64,
        ),
        throwsUnsupportedError,
      );
    });

    test('requires a declared glibc baseline for Linux artifacts', () {
      final target = PrebuiltTarget.fromConfig(input(os: OS.linux).config.code);
      final library = artifact(target: target.triple, file: 'mwc_wallet.so');
      expect(
        () => PrebuiltArtifact.select(
          manifest([library]),
          target,
          sourceSha256: 'c' * 64,
        ),
        throwsFormatException,
      );
      library['minimum_glibc_version'] = '2.35';
      expect(
        PrebuiltArtifact.select(
          manifest([library]),
          target,
          sourceSha256: 'c' * 64,
        ).file,
        'mwc_wallet.so',
      );
    });

    test('rejects traversal, missing deployment metadata, and ambiguity', () {
      final target = PrebuiltTarget.fromConfig(input().config.code);
      for (final artifacts in [
        [artifact(file: '../outside.dylib')],
        [artifact(file: 'https://elsewhere.invalid/library.dylib')],
        [artifact()..remove('minimum_os_version')],
        [artifact(), artifact()],
      ]) {
        expect(
          () => PrebuiltArtifact.select(
            manifest(artifacts),
            target,
            sourceSha256: 'c' * 64,
          ),
          throwsA(anything),
        );
      }
    });
  });

  test(
    'source fingerprints detect edits, additions, renames, and symlinks',
    () async {
      final root = Directory.fromUri(temporary.uri.resolve('source/'));
      final paths = [
        'rust/Cargo.toml',
        'rust/Cargo.lock',
        'rust/rust-toolchain.toml',
        'rust/src/lib.rs',
        'rust/src/space % λ.rs',
        'lib/mwc.dart',
        'hook/build.dart',
        'tool/build_prebuilt.dart',
        'tool/src/build_support.dart',
        'flake.nix',
        'flake.lock',
        'reproducible/audit_linux.py',
        'tool/build_nix_prebuilt.dart',
      ]..sort();
      final expectedFraming = StringBuffer();
      for (final path in paths) {
        final file = File.fromUri(root.uri.resolveUri(Uri(path: path)));
        await file.parent.create(recursive: true);
        final content = 'fixture: $path';
        await file.writeAsString(content);
        expectedFraming.write(
          '$path\u0000${sha256.convert(utf8.encode(content))}\n',
        );
      }
      final initial = await sourceFingerprint(root.uri);
      expect(
        initial.sha256,
        sha256.convert(utf8.encode(expectedFraming.toString())).toString(),
        reason: 'The manifest protocol hashes decoded relative filenames.',
      );
      expect((await sourceFingerprint(root.uri)).sha256, initial.sha256);
      expect(initial.dependencies, contains(root.uri.resolve('rust/src/')));
      expect(initial.dependencies, contains(root.uri.resolve('hook/')));

      final binding = File.fromUri(root.uri.resolve('lib/mwc.dart'));
      await binding.writeAsString('changed FFI signature');
      final edited = await sourceFingerprint(root.uri);
      expect(edited.sha256, isNot(initial.sha256));

      final added = File.fromUri(root.uri.resolve('rust/src/added.rs'));
      await added.writeAsString('new native module');
      final addedFingerprint = await sourceFingerprint(root.uri);
      expect(addedFingerprint.sha256, isNot(edited.sha256));
      await added.rename(root.uri.resolve('rust/src/renamed.rs').toFilePath());
      expect(
        (await sourceFingerprint(root.uri)).sha256,
        isNot(addedFingerprint.sha256),
      );

      if (!Platform.isWindows) {
        await Link.fromUri(root.uri.resolve('rust/src/link.rs'))
            .create(binding.path);
        await expectLater(sourceFingerprint(root.uri), throwsStateError);
      }
    },
  );

  group('verified downloads', () {
    test(
      'downloads afresh even when valid or corrupt bytes already exist',
      () async {
        final bytes = utf8.encode('downloaded binary');
        final digest = sha256.convert(bytes).toString();
        var requests = 0;
        String? acceptEncoding;
        final client = await serve((request) async {
          requests++;
          acceptEncoding = request.headers.value(
            HttpHeaders.acceptEncodingHeader,
          );
          request.response.add(bytes);
          await request.response.close();
        });
        final downloader = VerifiedDownloader(temporary, client: client);
        final uri = Uri.parse('https://example.invalid/library');
        final destination = File.fromUri(temporary.uri.resolve(digest));
        for (final previous in [bytes, utf8.encode('corrupt'), bytes]) {
          await destination.writeAsBytes(previous);
          final result = await downloader.get(uri, digest, size: bytes.length);
          expect(result.path, destination.path);
          expect(await result.readAsBytes(), bytes);
        }
        expect(requests, 3);
        expect(acceptEncoding, 'identity');
        expect(temporary.listSync().map((entry) => entry.path), [
          destination.path,
        ]);
      },
    );

    test('rejects an HTTPS redirect that downgrades to HTTP', () async {
      var requests = 0;
      final client = await serve((request) async {
        requests++;
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://example.invalid/insecure-library',
        );
        await request.response.close();
      });
      await expectLater(
        VerifiedDownloader(
          temporary,
          client: client,
        ).get(Uri.parse('https://example.invalid/library'), 'a' * 64),
        throwsFormatException,
      );
      expect(requests, 1);
      expect(
        File.fromUri(temporary.uri.resolve('a' * 64)).existsSync(),
        isFalse,
      );
    });

    test(
      'rejects HTTP failures without publishing their response body',
      () async {
        final bytes = utf8.encode('not found');
        final digest = sha256.convert(bytes).toString();
        final client = await serve((request) async {
          request.response.statusCode = HttpStatus.notFound;
          request.response.add(bytes);
          await request.response.close();
        });
        await expectLater(
          VerifiedDownloader(
            temporary,
            client: client,
          ).get(Uri.parse('https://example.invalid/library'), digest),
          throwsA(isA<HttpException>()),
        );
        expect(
          File.fromUri(temporary.uri.resolve(digest)).existsSync(),
          isFalse,
        );
      },
    );

    test('never publishes an unverified network response', () async {
      final expected = utf8.encode('expected binary');
      final digest = sha256.convert(expected).toString();
      final client = await serve((request) async {
        request.response.write('replaced binary');
        await request.response.close();
      });
      await expectLater(
        VerifiedDownloader(
          temporary,
          client: client,
        ).get(Uri.parse('https://example.invalid/library'), digest),
        throwsA(anything),
      );
      expect(File.fromUri(temporary.uri.resolve(digest)).existsSync(), isFalse);
    });

    test('does not reuse prior bytes after a failed fresh download', () async {
      final bytes = utf8.encode('previous verified binary');
      final digest = sha256.convert(bytes).toString();
      final previous = File.fromUri(temporary.uri.resolve(digest));
      await previous.writeAsBytes(bytes);
      var requests = 0;
      final client = await serve((request) async {
        requests++;
        request.response.write('replacement with a different digest');
        await request.response.close();
      });
      await expectLater(
        VerifiedDownloader(
          temporary,
          client: client,
        ).get(Uri.parse('https://example.invalid/library'), digest),
        throwsStateError,
      );
      expect(requests, 1);
      expect(await previous.readAsBytes(), bytes);
      expect(temporary.listSync().map((entry) => entry.path), [previous.path]);
    });

    test(
      'cancels a timed-out download before removing temporary files',
      () async {
        final digest = 'a' * 64;
        var requested = false;
        var totalTimeoutScheduled = false;
        final client = await serve((request) async {
          requested = true;
          request.response.bufferOutput = false;
          request.response.add([1, 2, 3]);
          // Deliberately leave the stream open after sending its first bytes.
          // The production timeout must abort this response and close the sink.
          unawaited(request.response.done.catchError((_) {}));
        });
        await runZoned(
          () => expectLater(
            VerifiedDownloader(
              temporary,
              client: client,
            ).get(Uri.parse('https://example.invalid/library'), digest),
            throwsA(isA<TimeoutException>()),
          ),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              if (duration == const Duration(minutes: 10)) {
                totalTimeoutScheduled = true;
                duration = const Duration(milliseconds: 100);
              }
              return parent.createTimer(zone, duration, callback);
            },
          ),
        );
        expect(requested, isTrue);
        expect(totalTimeoutScheduled, isTrue);
        expect(client.forceClosed, isTrue);
        expect(
          File.fromUri(temporary.uri.resolve(digest)).existsSync(),
          isFalse,
        );
        expect(temporary.listSync().whereType<Directory>(), isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('rejects oversized responses before committing an artifact', () async {
      final bytes = List<int>.filled(128, 42);
      final digest = sha256.convert(bytes).toString();
      final client = await serve((request) async {
        request.response.add(bytes);
        await request.response.close();
      });
      await expectLater(
        VerifiedDownloader(temporary, client: client).get(
          Uri.parse('https://example.invalid/library'),
          digest,
          maxBytes: 64,
        ),
        throwsA(anything),
      );
      expect(File.fromUri(temporary.uri.resolve(digest)).existsSync(), isFalse);
    });
  });

  test('resolver downloads into build output and fetches again after build cleanup', () async {
    final fingerprint = await sourceFingerprint(Directory.current.uri);
    final bytes = utf8.encode(
      'test library bytes; no native loading in this test',
    );
    final binaryDigest = sha256.convert(bytes).toString();
    final document = manifest([
      artifact()
        ..['sha256'] = binaryDigest
        ..['size'] = bytes.length,
    ])..['source_sha256'] = fingerprint.sha256;
    final manifestBytes = utf8.encode(jsonEncode(document));
    final manifestDigest = sha256.convert(manifestBytes).toString();
    final paths = <String>[];
    final client = await serve((request) async {
      paths.add(request.uri.path);
      switch (request.uri.path) {
        case '/release/manifest.json':
          request.response.add(manifestBytes);
        case '/release/mwc_wallet-aarch64-apple-darwin-dynamic.dylib':
          request.response.add(bytes);
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final buildInput = input(
      defines: settings({'prebuilt_manifest_sha256': manifestDigest}),
    );
    final outputDirectory = buildInput.outputDirectory;
    for (var build = 0; build < 3; build++) {
      if (build == 2) {
        await Directory.fromUri(temporary.uri.resolve('build/'))
            .delete(recursive: true);
        expect(temporary.listSync(), isEmpty);
      }
      final output = BuildOutputBuilder();
      expect(await usePrebuilt(buildInput, output, client: client), isTrue);
      final asset = output.build().assets.code.single;
      expect(asset.id, 'package:flutter_libmwc/mwc.dart');
      expect(asset.linkMode, isA<DynamicLoadingBundled>());
      expect(asset.file, outputDirectory.resolve('libmwc_wallet.dylib'));
      expect(await File.fromUri(asset.file!).readAsBytes(), bytes);
      expect(
        output.build().dependencies,
        containsAll(fingerprint.dependencies),
      );
      expect(
        temporary
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.uri),
        [asset.file],
        reason:
            'Only the canonical binary should survive in the build directory.',
      );
      expect(paths.length, (build + 1) * 2);
    }
    expect(paths, [
      for (var build = 0; build < 3; build++) ...[
        '/release/manifest.json',
        '/release/mwc_wallet-aarch64-apple-darwin-dynamic.dylib',
      ],
    ]);
  });
}

/// Keep production HTTPS validation in place while routing test requests to a
/// local HTTP server. No external hosts or certificate exceptions are used.
final class _LoopbackClient implements HttpClient {
  final int port;
  final HttpClient delegate = HttpClient();
  bool forceClosed = false;

  _LoopbackClient(this.port);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => delegate.getUrl(
    url.replace(scheme: 'http', host: '127.0.0.1', port: port),
  );

  @override
  set connectionTimeout(Duration? value) => delegate.connectionTimeout = value;

  @override
  set autoUncompress(bool value) => delegate.autoUncompress = value;

  @override
  set findProxy(String Function(Uri)? value) => delegate.findProxy = value;

  @override
  void close({bool force = false}) {
    forceClosed = forceClosed || force;
    delegate.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
