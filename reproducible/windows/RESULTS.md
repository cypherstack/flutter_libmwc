# Windows reproduction results

**Host-to-CI verified.** Two clean builds on this Windows 11 host reproduced
the DLL, static LIB, manifest and manifest pin from the successful GitHub
Windows Server 2022 run, byte-for-byte.

- Source commit: `ccd335017739cff255b578bae6a1b35159b79fab`.
- [GitHub run 34905483081, attempt 1](https://github.com/cypherstack/flutter_libmwc/actions/runs/34905483081).
- Runner: `windows-2022`, image `20260907.297.1`, Windows build `20348`.
- Workflow: `.github/workflows/reproducible-windows.yml`.
- [First local-to-CI comparison](evidence/34905483081/local-a-to-github.json),
  [second local-to-CI comparison](evidence/34905483081/local-b-to-github.json),
  and [local-to-local comparison](evidence/34905483081/local-to-local.json):
  all exited 0 with `"status": "match"`.
- [Download verification](evidence/34905483081/download-verification.json):
  both ZIP digests matched the official GitHub artifacts API before extraction;
  their run ID and commit matched the selected successful run.

See [README.md](README.md) for the shared recipe and
[HOST_TO_CI.md](../HOST_TO_CI.md) for the comparison protocol. This results-only
commit follows the tested source commit; check out the exact SHA above when
reproducing the recorded GitHub run.

The investigation host runs Microsoft Windows 11 Pro, build 26200, x64, on an
Intel Core i7-11800H. Its installed VS 2022/2026 toolchains are not build inputs.
The recipe downloads the pinned compiler, CRT, SDK, Rust and generator archives
in `tools.lock.json`. Orchestration uses Python 3.13.7, Flutter 3.47.3 / Dart
3.13.3 and Git 2.50.1.windows.1.

GitHub used Python 3.13.7 and Git 2.55.0.windows.5. Despite different host OS
and Git versions, the pinned native inputs and all release payloads matched.
The [host inventory](evidence/34905483081/local-a-build-evidence.json) and
[CI inventory](evidence/34905483081/github-build-evidence.json) record the
compiler, linker, librarian, Rust and generator hashes. The common tool lock
SHA-256 is `d8ec365fd9b7a21d579ce120ef00e61ff26d8cf60f4a7b00472823c7bd6b092b`.

## Matched release hashes

| Payload | SHA-256 |
| --- | --- |
| `mwc_wallet-x86_64-pc-windows-msvc-dynamic.dll` | `f2912a0a9ab81cd3c039e448c08330178c5ef1891d84523bef6d362bf78a6165` |
| `mwc_wallet-x86_64-pc-windows-msvc-static.lib` | `f29ac124a1f2941c895f84224974e2fa69cc4723aa574ba716a6f3fff4a986f8` |
| `manifest.json` | `cdd8d410799d32789e61748925dc8041b0b9abe9bf681ddb05e369f54fa24d53` |
| `manifest.sha256` | `10eedfa2a278267e1ebed2ef554069bab7fc4afe1c57a6384d9ae0dc4b41d682` |

Source fingerprint:
`0d61d8b22b24c6e5fb2aeb169ef8435c0e768a6d6077e65fa618d660774c5a73`.

## Final clean-build procedure and checks

Two checkouts of the tested commit were used:

| Checkout | Fresh build directory | Packaged output |
| --- | --- | --- |
| `C:\src\flutter_libmwc-repro` | `C:\src\mwc-w4` | `build/windows-release-a` |
| `C:\src\mwc-source-b` | `C:\src\mwc-w5` | `build/windows-release-b` |

Each invocation of `tool/build_windows_prebuilt.dart` extracted fresh native
tools, fetched into an independent Cargo home, and compiled with `--frozen`
into an empty target directory. Only hash-checked tool downloads were shared.
Both used the same temporary R: mapping sequentially; it was released after
each build. The packager required clean committed inputs and checked them
again after compilation.

The commands below were run from the first checkout; the second used `mwc-w5`,
`windows-final-b` and `windows-release-b` in its own checkout:

```powershell
dart --packages=.dart_tool/package_config.json tool/build_windows_prebuilt.dart --work C:\src\mwc-w4 --cache C:\src\mwc-repro-tools --python C:\src\mwc-repro-tools\python\python.exe --output build/windows-final-a
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart build/windows-final-a/mwc_wallet-x86_64-pc-windows-msvc-dynamic.dll
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart --artifacts build/windows-final-a --output build/windows-release-a
python reproducible/ci_artifacts.py compare build/github-34905483081/release build/windows-release-a --commit ccd335017739cff255b578bae6a1b35159b79fab --repository cypherstack/flutter_libmwc --run-id 34905483081 --run-attempt 1
```

The same ABI smoke test passed on both local DLLs, in the GitHub job, and on
the downloaded GitHub DLL loaded locally. Output:

```text
Native library loaded; mnemonic and error/free ABI checks passed
```

Validation also passed 38 Dart tests (2 platform-specific skips), 8 artifact
protocol tests, 4 Windows recipe/audit tests, and targeted Dart analysis.
The [dependency audit](evidence/34905483081/dependents.txt) records the expected
Windows system, UCRT and MSVC imports. Both link modes matched in full;
the static archive has not additionally been tested with a separate C consumer.

This verifies the new Windows reproducibility workflow's unsigned payloads.
It does not claim a match to the older `native-0.1.0-1` release, whose Windows
job used host-selected tools. The existing multi-platform tag-release workflow
still uses that older producer; it must adopt this recipe before a tagged
Windows release can make the same claim. No signing or release publication
was part of this comparison.

## Initial path experiment

Two independent source/Cargo/tool/output directories produced the same DLL:

`af02ec6d3885250735184de2df45bdf30b95eef9e48a9b4807d5aa3702efdb1f`

The static archives differed. Comparing all 3,893 object payloads showed that
every object matched. The archive long-name table differed in 77 absolute
member paths, including paths to ring's preassembled objects. The fixed R:
mapping in the final recipe addresses that observed cause without rewriting
the binary or excluding bytes from comparison.

The DLL passed the existing Dart ABI smoke test: mnemonic generation and 100
error-response allocation/free calls. The PE audit found the reproducible
linker marker and no CodeView PDB reference. All archive-header timestamps were
zero; 77 MSVC objects carried content-derived nonzero timestamps. The allowed
imports include Windows system DLLs, UCRT, MSVCP140 and VCRUNTIME140.

These were development builds, not release manifests or GitHub evidence.
