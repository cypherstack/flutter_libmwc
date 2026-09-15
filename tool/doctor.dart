/// SDK-only preflight: invoke `dart tool/doctor.dart`, without pub get.
import 'dart:io';

import 'src/doctor/common.dart';
import 'src/doctor/windows.dart';

Future<void> main(List<String> arguments) async {
  DoctorOptions options;
  try {
    options = DoctorOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\nUse dart tool/doctor.dart --help');
    exitCode = 2;
    return;
  }
  if (options.help) {
    stdout.writeln('''Usage: dart tool/doctor.dart [options]
  --target <triple>  Default: native host target; currently Windows x64 only
  --cache <path>    Native builder cache (default: LOCALAPPDATA/flutter_libmwc)
  --work <path>     Optional fresh native work directory
  --flutter <path>  Flutter executable to check (default: flutter on PATH)
  --release         Require a clean Git checkout
  --network         Probe pinned tool URLs and package endpoints
  --desktop         Check Flutter desktop application prerequisites
  --json            Emit schema-1 JSON; exit 0 ready/warnings, 1 blocked
  --help            Show usage; invalid arguments exit 2''');
    return;
  }
  final target =
      options.target ??
      (Platform.isWindows ? 'x86_64-pc-windows-msvc' : 'unsupported');
  final report = DoctorReport(Platform.script.resolve('../'), target);
  // Linux/macOS agents can add platform modules using the same options/report.
  if (Platform.isWindows && target == 'x86_64-pc-windows-msvc') {
    await checkWindows(options, report);
  } else {
    report.add(
      'target',
      'fail',
      'Preflight is not implemented for '
          '${Platform.operatingSystem}/$target. Currently supported: Windows x64.',
    );
  }
  stdout.writeln(report.render(options.json));
  exitCode = report.blocked ? 1 : 0;
}
