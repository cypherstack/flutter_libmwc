# Native build host preflight

Entry point: `dart tool/doctor.dart`. Use SDK libraries only so the command works
before `flutter pub get`. It diagnoses prerequisites; it does not install tools
or build native libraries. Windows x64 is implemented first.

Platform agents: add `linux.dart` or `macos.dart` beside `windows.dart`, exposing
an async function taking `DoctorOptions` and `DoctorReport`, then add host/target
dispatch in `tool/doctor.dart`. Leave other platform modules intact. Unsupported
host/target combinations must fail explicitly, never report readiness.

Use `report.check(name, action)` to capture a failed probe and continue. Add
`pass`, `warn`, or `fail` records with a concrete explanation or remedy. Modules
must not print, set exit codes, or invoke another platform's tools. Keep probes
bounded and clean up only files created by the probe. Pass paths as process
arguments or environment values, never interpolated shell source.

Shared flags: `--target`, `--cache`, `--work`, `--flutter`, `--release`,
`--network`, `--desktop`, `--json`, `--help`. Path meanings follow each platform's
builder. Document unsupported options when adding a platform.

JSON schema 1 includes `status`, `root`, `host`, `target`, `checks` and `scope`.
Statuses are `ready`, `ready-with-warnings`, or `blocked`; each check has `name`,
`status`, and `detail`. Exit 0 permits warnings, 1 means blocked, and 2 means
invalid CLI arguments (diagnostic on stderr). Existing schema-1 PowerShell
fields are retained; host and target are additive. Consumers should tolerate
additional checks and fields.

Run tests with the existing `tool/test_prebuilt.dart` runner. Historical CI hash
evidence remains scoped to its recorded revision; preflight success is not a
reproducibility proof.
