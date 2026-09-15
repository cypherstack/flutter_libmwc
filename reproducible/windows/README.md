# Windows MSVC reproducible prebuilts

The recipe builds `x86_64-pc-windows-msvc` with hash-pinned downloads. It does
not use the host's Visual Studio installation or SDK. Compilation uses Cargo's
checked-in lockfile and `--frozen` after fetching dependencies. OpenSSL remains
excluded on Windows; native TLS uses SChannel.

## Run locally

Use Windows x64, Git, Python 3.13.7, and Flutter 3.47.3. Python and Dart
orchestrate, package and test; native tools come from `tools.lock.json`.
Choose new short work/output directories each time. Drive **R:** must be free;
the recipe refuses an occupied drive and removes its temporary mapping on exit.

```powershell
flutter pub get --no-example
dart --packages=.dart_tool/package_config.json tool/build_windows_prebuilt.dart --work C:\mwc-build-a --cache C:\mwc-downloads --output build/windows-a
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart build/windows-a/mwc_wallet-x86_64-pc-windows-msvc-dynamic.dll
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart --artifacts build/windows-a --output build/windows-release-a
```

The packager requires committed, clean inputs and checks them again after the
build. `--python C:\path\python.exe` selects a particular Python installation.
Downloaded archives can be cached; every use checks their SHA-256. Each build
extracts its own native tools and fetches its own Cargo sources into a fresh
directory. It never reuses compiled Cargo output. Cargo registry checksums and
Git revisions are bound by `rust/Cargo.lock`.

The PowerShell entry point can also build and audit raw libraries during recipe
development (it does not create release manifests):

```powershell
powershell -NoProfile -File reproducible/windows/build.ps1 -Work C:\mwc-experiment -Cache C:\mwc-downloads -Python C:\path\python.exe
```

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
The build's temporary R: mapping makes Cargo/native archive member paths stable
across different physical checkout and work directories.

This mapping is necessary: the initial experiment produced identical DLLs and
identical individual COFF object payloads, but the static archive's long-name
table retained 77 absolute paths. The recipe preserves the original full
archive and its symbol tables. It does not mask bytes during comparison.

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
for the current verification status.
