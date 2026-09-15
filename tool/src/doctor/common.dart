import 'dart:convert';
import 'dart:io';

/// Shared CLI contract. Platform implementations consume these options and add
/// named checks to [DoctorReport]; they do not print or set the process exit code.
class DoctorOptions {
  String? cache, work, flutter, target;
  bool release = false, network = false, desktop = false, json = false;
  bool help = false;

  static DoctorOptions parse(List<String> arguments) {
    final result = DoctorOptions();
    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      switch (arg) {
        case '--cache':
        case '--work':
        case '--flutter':
        case '--target':
          if (++i >= arguments.length || arguments[i].startsWith('--')) {
            throw FormatException('Missing value for $arg');
          }
          final value = arguments[i];
          switch (arg) {
            case '--cache':
              result.cache = value;
            case '--work':
              result.work = value;
            case '--flutter':
              result.flutter = value;
            case '--target':
              result.target = value;
          }
        case '--release':
          result.release = true;
        case '--network':
          result.network = true;
        case '--desktop':
          result.desktop = true;
        case '--json':
          result.json = true;
        case '--help':
          result.help = true;
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }
    return result;
  }
}

class DoctorReport {
  DoctorReport(this.root, this.target);
  final Uri root;
  final String target;
  final checks = <Map<String, String>>[];
  void add(String name, String status, String detail) {
    if (!['pass', 'warn', 'fail'].contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    checks.add({'name': name, 'status': status, 'detail': detail});
  }

  Future<void> check(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      add(name, 'fail', error.toString());
    }
  }

  bool get blocked => checks.any((check) => check['status'] == 'fail');
  String get status => blocked
      ? 'blocked'
      : checks.any((check) => check['status'] == 'warn')
      ? 'ready-with-warnings'
      : 'ready';
  static const scope =
      'Host preflight only. Proof requires a clean build and '
      'artifact comparison with a successful CI run of the same revision.';
  Map<String, Object> toJson() => {
    'schema': 1,
    'status': status,
    'root': root.toFilePath(),
    'host': Platform.operatingSystem,
    'target': target,
    'checks': checks,
    'scope': scope,
  };
  String render(bool json) => json
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : '${checks.map((c) => '[${c['status']!.toUpperCase()}] '
            '${c['name']}: ${c['detail']}').join('\n')}\nResult: $status. $scope';
}

/// Bound probes, capture output so --json stays machine-readable, and use an
/// argument list (never interpolate user paths into shell command source).
Future<String> probe(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
  );
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 90),
    onTimeout: () {
      process.kill();
      throw StateError('$executable timed out after 90 seconds');
    },
  );
  final text = await output;
  final errorText = await errors;
  if (code != 0) throw StateError('$executable exited $code: $text$errorText');
  return text.trim();
}

List<int> versionParts(String value) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(value);
  if (match == null) throw FormatException('Unrecognized version: $value');
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

bool versionAtLeast(String actual, String minimum) {
  final a = versionParts(actual), b = versionParts(minimum);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return true;
}
