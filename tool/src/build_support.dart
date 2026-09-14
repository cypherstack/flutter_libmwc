import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../../hook/src/source_fingerprint.dart';

const releaseTargets = <String, Map<String, Object>>{
  'x86_64-unknown-linux-gnu': {'minimum_glibc_version': '2.35'},
  'x86_64-pc-windows-msvc': {},
  'x86_64-apple-darwin': {'minimum_os_version': 11},
  'aarch64-apple-darwin': {'minimum_os_version': 11},
  'armv7-linux-androideabi': {'minimum_os_version': 21},
  'aarch64-linux-android': {'minimum_os_version': 21},
  'x86_64-linux-android': {'minimum_os_version': 21},
  'aarch64-apple-ios': {'minimum_os_version': 13},
  'aarch64-apple-ios-sim': {'minimum_os_version': 13},
  'x86_64-apple-ios': {'minimum_os_version': 13},
};

const androidNdkVersion = '28.2.13676358';
const indentedJson = JsonEncoder.withIndent('  ');

/// Run maintainer tools from the repository root.
final Uri packageRoot = Directory.current.uri;

Future<String> sha256File(File file) async =>
    (await crypto.sha256.bind(file.openRead()).first).toString();

/// Producer and consumer use the same source fingerprint implementation.
Future<String> sourceSha256([Uri? root]) async =>
    (await sourceFingerprint(root ?? packageRoot)).sha256;

Future<String> toolchainChannel([Uri? root]) async {
  final source = await File.fromUri(
    (root ?? packageRoot).resolve('rust/rust-toolchain.toml'),
  ).readAsString();
  final match = RegExp(
    r'^channel\s*=\s*"(\d+\.\d+\.\d+)"\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    throw StateError('rust/rust-toolchain.toml must pin an exact Rust version');
  }
  return match[1]!;
}

Map<String, String> libraryNames(String target) {
  if (!releaseTargets.containsKey(target)) {
    throw ArgumentError.value(target, 'target', 'Unsupported release target');
  }
  if (target.contains('windows')) {
    return {'dynamic': 'mwc_wallet.dll', 'static': 'mwc_wallet.lib'};
  }
  return {
    'dynamic': 'libmwc_wallet${target.contains('apple') ? '.dylib' : '.so'}',
    'static': 'libmwc_wallet.a',
  };
}

/// Run argument vectors without involving a shell. When an explicit environment
/// is supplied, omitted variables stay removed from the child process.
Future<String?> runCommand(
  List<String> command, {
  Uri? workingDirectory,
  Map<String, String>? environment,
  bool capture = false,
}) async {
  stdout.writeln('+ ${command.join(' ')}');
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    workingDirectory: (workingDirectory ?? packageRoot).toFilePath(),
    environment: environment,
    includeParentEnvironment: environment == null,
  );
  final (status, output, _, _) = await (
    process.exitCode,
    capture
        ? process.stdout.transform(systemEncoding.decoder).join()
        : stdout.addStream(process.stdout).then((_) => ''),
    stderr.addStream(process.stderr),
    process.stdin.close(),
  ).wait;
  if (status != 0) {
    throw ProcessException(
      command.first,
      command.skip(1).toList(),
      'Command failed',
      status,
    );
  }
  return capture ? output.trim() : null;
}
