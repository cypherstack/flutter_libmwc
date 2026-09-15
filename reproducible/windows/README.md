# Windows MSVC reproducible prebuilts

The recipe builds `x86_64-pc-windows-msvc` with hash-pinned downloads. It does
not use the host's Visual Studio installation or SDK. Compilation uses Cargo's
checked-in lockfile and `--frozen` after fetching dependencies. OpenSSL remains
excluded on Windows; native TLS uses SChannel.

## Check a Windows host first

From the repository root, run the standalone preflight (no Python or Dart
packages required):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File reproducible/windows/doctor.ps1 -Network -Release
```

It checks Windows x64, Git, Flutter/Dart versions against this checkout and CI,
Windows PowerShell extraction support, recipe inputs, writable NTFS storage,
file locking, old file timestamps, available space, and ambient Cargo config.
Pinned Python and native compilers are automatically provisioned by the builder;
they do not need to be installed beforehand. No `R:` drive is required.

Options:

- `-Flutter C:\path\to\flutter\bin\flutter.bat` selects the SDK to check.
  Use that same SDK for subsequent builds.
- `-Cache C:\cache` and `-Work C:\fresh-work` check paths you intend to pass to
  the producer. The work path must not already exist.
- `-Release` additionally requires a clean Git checkout for release packaging;
  omit it for source-hook development.
- `-Network` checks pinned download URLs and package endpoints. Without it,
  network readiness is explicitly untested. HEAD requests do not verify full
  downloads or every Cargo dependency; the builder checks archive hashes.
- `-Desktop` also checks Visual Studio through `flutter doctor -v` for building
  a Flutter application. Visual Studio is unnecessary for native-only production.
- `-Json` emits a structured report. Exit 1 means blocked; exit 0 means no
  blocking checks failed, but inspect warnings (including low disk space).

The check installs nothing and uses only a temporary storage probe, which it
removes. Flutter commands may initialize their own SDK cache. A passing preflight
establishes host readiness, not matching hashes: build and compare against a
successful CI run at the same revision using the procedure below.

## Build a Flutter application

On Windows x64 with Flutter's normal Windows desktop prerequisites, applications
consuming this package use the pinned native builder automatically:

```powershell
flutter pub get
flutter build windows --release
```

The hook provisions its own verified Python runtime and native toolchain. It
requires no reserved drive letter, manual native-tool installation, or chosen
work path. Flutter still needs its own supported Visual Studio desktop tools to
build the application. Git is needed to fetch the locked Rust dependencies.

The normal source hook supports edited sources and packages without `.git`.
Release packaging additionally requires committed, clean inputs and checks them
again after building. Both DLL and static LIB use the same release recipe.
The existing explicit prebuilt-download mode retains its integrity checks.

## Package or verify a clean build

```powershell
flutter pub get --no-example
dart --packages=.dart_tool/package_config.json tool/build_windows_prebuilt.dart --clean --output build/windows-a
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart build/windows-a/mwc_wallet-x86_64-pc-windows-msvc-dynamic.dll
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart --artifacts build/windows-a --output build/windows-release-a
```

The default cache is `%LOCALAPPDATA%\flutter_libmwc`. Use an NTFS work/cache
volume; Cargo cannot extract some locked crates correctly on exFAT. Cached libraries are keyed
by the shared source/recipe fingerprint and verified by full SHA-256 before
reuse. An operating-system file lock serializes builders sharing that cache and
is released if a process terminates. Incomplete staging directories are never
reused as completed outputs. Each fresh build extracts verified native tools
and fetches its own Cargo sources. Cargo checksums and Git revisions are bound
by `rust/Cargo.lock`. Source changes invalidate cached output.

Temporary-file cleanup retries Windows access/sharing failures. If Windows
still refuses removal, the build reports the retained directory and keeps the
verified result usable. Retained staging is never accepted as cached output.

`--clean` forces an independent native build. Optional `--work C:\some-path`
retains a fresh work directory, including compiler inspection reports; optional
`--cache C:\some-cache` selects a cache. Neither option is needed normally.
Python is provisioned automatically by the shared Dart entry point.

The generic `tool/build_prebuilt.dart --target x86_64-pc-windows-msvc` command
uses the same Windows producer, including its clean-source checks and verified
cache. Its `--target-dir` also receives the two canonical library files for
callers that consume the usual Cargo release-directory layout.

The lower-level PowerShell/Python entry points remain available for recipe
development; these intentionally accept explicit work/cache paths and a Python
interpreter. They are not the ordinary Flutter interface.

## Pinned inputs

- Rust compiler, Cargo and x64 MSVC standard library: **1.90.0**, archive hashes
  from `static.rust-lang.org`.
- MSVC x64 compiler/linker/librarian: **19.44.35214 / 14.44.35214**; CRT headers
  and libraries **14.44.35211**. The package directory is `14.44.35207`.
  Exact VSIX URLs and hashes came from the Microsoft Visual Studio 17.14.11
  package catalog installed on the investigation host.
- Windows SDK **10.0.22621.0**, NuGet packages
  `Microsoft.Windows.SDK.CPP` and `.x64` **10.0.22621.3233**.
- CMake **3.31.8**, protoc **21.12**.

All download URLs and SHA-256 pins are committed in `tools.lock.json`. SDK
headers/tools and libraries are extracted from Microsoft's NuGet packages;
MSVC binaries and CRT files are extracted from Microsoft's VSIX packages.
This downloads the tools directly for building; it does not redistribute them
inside the native release. Rust's precompiled standard library is a pinned
input, not a claim of bootstrapping Rust from source.

LLVM, nasm and Perl are not invoked by this Windows dependency graph: ring
ships its assembly objects and no OpenSSL build is selected. CMake is pinned
for native build tooling even though this locked Windows graph does not invoke it.

## Controls and evidence

The recipe uses a restricted environment, explicit compiler/linker paths,
fixed release settings, disabled incremental/debug output, `/Brepro`,
`/INCREMENTAL:NO`, Rust path remapping, and MSVC `/pathmap` with
`/experimental:deterministic`. It fixes the epoch, timezone and tool language.
Archive production removes directories from COFF member names before packaging,
while preserving basenames, object payloads, member order, duplicate members,
and both linker symbol-to-member mappings. Offset relocation is verified by
restoring and comparing the original index bytes. Full output files are hashed
and compared without masking bytes. The build also links and runs a real C
consumer of the resulting static library.

Basenames are significant: an experiment replacing them with ordinals produced
matching archives but a crashing MSVC consumer. Retaining basenames passed the
same consumer. The old fixed-drive evidence in [RESULTS.md](RESULTS.md) remains
historical evidence; the revised default path needs its own host-to-CI baseline.

`build-evidence.json` records hashes and audits. `headers.txt`, `dependents.txt`
and `exports.txt` retain the linker inspection reports. The audit checks x64
PE/DLL identity, the reproducible linker marker, absence of a CodeView PDB
reference, required C exports, allowed Windows/MSVC imports, and x64 COFF
archive members with zero archive-header timestamps. MSVC's object timestamps
can be content-derived nonzero values; whole-file comparison checks them too.
The DLL requires the MSVC runtime, as the existing MSVC target does.

## GitHub comparison

Publish the tested commit to `cypherstack/flutter_libmwc` under
`windows-reproducible-native-prebuilts`. The push trigger in
`.github/workflows/reproducible-windows.yml` builds with the same recipe,
smoke-tests the DLL, assembles both link modes and uploads a release directory
with `ci-evidence.json`. It does not publish a binary release.

After a successful run, follow [HOST_TO_CI.md](../HOST_TO_CI.md) with the Windows
artifact name `reproducible-windows-attempt-N`. Check out that exact full commit
locally and rebuild. For example, after downloading its artifact:

```powershell
python reproducible/ci_artifacts.py compare build/github-windows build/windows-release-a --commit FULL_COMMIT --repository cypherstack/flutter_libmwc --run-id RUN_ID --run-attempt 1
```

Require exit 0 and `"status": "match"`. Keep the actual GitHub URL, attempt,
artifact download verification, and comparison report. Two local matching
builds do not establish host-to-CI reproduction. See [RESULTS.md](RESULTS.md)
for the historical fixed-drive result. The [default-path validation](DEFAULT-PATH-VALIDATION.md)
records the current verified recipe and its host-to-CI comparisons.
