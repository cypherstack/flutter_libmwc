# Windows reproduction results

**Host-to-CI unverified.** A matching real GitHub Actions run is required before
claiming Windows host-to-CI reproducibility. See [README.md](README.md) for the
shared recipe and [HOST_TO_CI.md](../HOST_TO_CI.md) for the comparison protocol.

The investigation host runs Microsoft Windows 11 Pro, build 26200, x64, on an
Intel Core i7-11800H. Its installed VS 2022/2026 toolchains are not build inputs.
The recipe downloads the pinned compiler, CRT, SDK, Rust and generator archives
in `tools.lock.json`. Orchestration uses Python 3.13.7, Flutter 3.47.3 / Dart
3.13.3 and Git 2.50.1.windows.1.

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
