import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'src/build_support.dart';

typedef ManifestResult = ({Map<String, Object?> manifest, String sha256});
Map<String, Object?> _object(Object? value, String description) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Expected an object: $description');
  }
  return Map<String, Object?>.from(value);
}

bool _matches(String pattern, String value) =>
    RegExp(pattern).firstMatch(value)?.group(0) == value;

/// Verify all producer fragments before writing any release files.
Future<ManifestResult> assemblePrebuilts(
  Directory artifactsDirectory,
  Directory outputDirectory, {
  Uri? root,
  bool requireAll = false,
}) async {
  if (await outputDirectory.exists() && !await outputDirectory.list().isEmpty) {
    throw StateError('Release output must be empty; refusing to mix releases');
  }
  final expectedSource = await sourceSha256(root);
  final fragments = <File>[];
  await for (final entity in artifactsDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && entity.path.endsWith('.json')) fragments.add(entity);
  }
  fragments.sort((first, second) => first.path.compareTo(second.path));
  if (fragments.isEmpty) {
    throw const FormatException('No build fragments found');
  }
  final artifacts = <({Map<String, Object?> entry, File source})>[];
  final seenPairs = <(String, String)>{};
  final seenNames = <String>{};
  for (final path in fragments) {
    final fragment = _object(jsonDecode(await path.readAsString()), path.path);
    if (fragment['schema_version'] != 1 ||
        fragment['package'] != 'flutter_libmwc') {
      throw FormatException('Unsupported build fragment: ${path.path}');
    }
    if (fragment['source_sha256'] != expectedSource) {
      throw FormatException('Source fingerprint mismatch: ${path.path}');
    }
    final entries = fragment['artifacts'];
    if (entries is! List || entries.isEmpty) {
      throw FormatException('Missing artifact entries: ${path.path}');
    }
    for (final value in entries) {
      final entry = _object(value, '${path.path} artifact');
      final target = entry['target'];
      final mode = entry['link_mode'];
      final name = entry['file'];
      if (target is! String ||
          !releaseTargets.containsKey(target) ||
          mode is! String ||
          !['static', 'dynamic'].contains(mode)) {
        throw FormatException('Unknown target or link mode in ${path.path}');
      }
      if (name is! String ||
          !_matches(
            r'[A-Za-z0-9_-][A-Za-z0-9_.-]*\.(so|dylib|dll|a|lib)',
            name,
          )) {
        throw FormatException('Unsafe artifact filename in ${path.path}');
      }
      if (seenPairs.contains((target, mode)) || seenNames.contains(name)) {
        throw FormatException('Duplicate artifact: $target/$mode/$name');
      }
      for (final compatibility in releaseTargets[target]!.entries) {
        if (entry[compatibility.key] != compatibility.value) {
          throw FormatException('Incorrect ${compatibility.key} for $target');
        }
      }
      final source = File.fromUri(path.parent.uri.resolve(name));
      if (await FileSystemEntity.type(source.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw FormatException('Missing or nonregular artifact: ${source.path}');
      }
      final size = entry['size'];
      if (size is! int ||
          size <= 0 ||
          size > 2 * 1024 * 1024 * 1024 ||
          await source.length() != size) {
        throw FormatException('Artifact size mismatch: ${source.path}');
      }
      if (await sha256File(source) != entry['sha256']) {
        throw FormatException('Artifact checksum mismatch: ${source.path}');
      }
      seenPairs.add((target, mode));
      seenNames.add(name);
      artifacts.add((entry: entry, source: source));
    }
  }
  final expectedPairs = {
    for (final target in releaseTargets.keys)
      for (final mode in ['static', 'dynamic']) (target, mode),
  };
  if (requireAll && !seenPairs.containsAll(expectedPairs)) {
    final missing =
        expectedPairs.difference(seenPairs).map((p) => '$p').toList()..sort();
    throw FormatException('Missing release artifacts: $missing');
  }
  artifacts.sort((first, second) {
    final target = (first.entry['target'] as String).compareTo(
      second.entry['target'] as String,
    );
    return target != 0
        ? target
        : (first.entry['link_mode'] as String).compareTo(
            second.entry['link_mode'] as String,
          );
  });
  final manifest = <String, Object?>{
    'schema_version': 1,
    'package': 'flutter_libmwc',
    'source_sha256': expectedSource,
    'artifacts': artifacts.map((artifact) => artifact.entry).toList(),
  };
  await outputDirectory.create(recursive: true);
  for (final artifact in artifacts) {
    final destination = File.fromUri(
      outputDirectory.uri.resolve(artifact.entry['file'] as String),
    );
    await artifact.source.copy(destination.path);
  }
  final manifestFile = File.fromUri(
    outputDirectory.uri.resolve('manifest.json'),
  );
  await manifestFile.writeAsString('${indentedJson.convert(manifest)}\n');
  final pin = await sha256File(manifestFile);
  await File.fromUri(outputDirectory.uri.resolve('manifest.sha256'))
      .writeAsString('$pin  manifest.json\n');
  stdout.writeln('Manifest SHA-256: $pin');
  return (manifest: manifest, sha256: pin);
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('artifacts')
    ..addOption(
      'output',
      defaultsTo: packageRoot.resolve('build/native-release/').toFilePath(),
    )
    ..addFlag('require-all', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln(
        'Verify native artifacts and assemble a release.\n${parser.usage}',
      );
      return;
    }
    if (args.rest.isNotEmpty)
      throw const FormatException('Unexpected arguments');
    final artifactsPath = args.option('artifacts');
    if (artifactsPath == null) {
      throw const FormatException('--artifacts is required');
    }
    final output = Directory(args['output'] as String).absolute;
    final result = await assemblePrebuilts(
      Directory(artifactsPath).absolute,
      output,
      requireAll: args['require-all'] as bool,
    );
    final summaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (summaryPath != null) {
      await File(summaryPath).writeAsString(
        'Manifest SHA-256: `${result.sha256}`\n\n'
        'Native source SHA-256: `${result.manifest['source_sha256']}`\n',
        mode: FileMode.append,
      );
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
