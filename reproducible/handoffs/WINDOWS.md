# Windows agent handoff

## Objective and branch

Make this Windows x64 host reproduce the exact `.dll` and `.lib` emitted by a
real GitHub Actions run at the same commit. The target is
**`x86_64-pc-windows-msvc`**. Linux is ready; proceed independently of macOS.

Read [the common handoff](README.md) and [HOST_TO_CI.md](../HOST_TO_CI.md).
After cloning the transport branch, use:

```powershell
git switch -c windows-reproducible-native-prebuilts
```

Own `reproducible/windows/`, `tool/build_windows_prebuilt.dart`, and
`.github/workflows/reproducible-windows.yml`. Coordinate shared changes as
specified in the common handoff. Transport updates can use
`flutter-libmwc/windows-reproducible-native-prebuilts`.

## Inspect and pin

Record Windows edition/build, CPU architecture, Rust **1.90.0**, Visual Studio
Build Tools installation and component versions, Windows SDK, `cl`, `link`,
`lib`, CMake, protoc, nasm, LLVM (if actually used), Git, and Python. Use `vswhere`
to identify the installed tools and select an explicit developer environment.
A `windows-2022` GitHub runner label does not pin the installed toolchain.

The current Rust manifest intentionally excludes vendored OpenSSL on Windows;
native-tls uses SChannel. Preserve that behavior. Use checked-in Cargo.lock and
hash-verified/vendored sources, with compilation offline after fetching.

Use short task-specific Cargo/source/target paths, for example an unused
`C:\mwc-repro\` directory. Do not delete or reuse another task's directory.
Preserve long-path handling where needed. Record tool installer/archive hashes
and exact components, so both the coworker's host and CI can provision the
same inputs. Avoid mutable Chocolatey selections as the build authority.

## Implement and verify

1. Create a shared PowerShell build entry point that selects the pinned tools,
   stable environment, target, and inputs on both local Windows and CI. It must
   fail if the wrong SDK/compiler is selected.
2. Investigate `/Brepro`, PE/COFF timestamps, archive member order/timestamps,
   linker-generated IDs, CodeView/PDB references, compiler paths, and source-path
   remapping. Inspect actual differences; `/Brepro` alone is not proof.
3. Preserve the MSVC target and both `mwc_wallet.dll` / `mwc_wallet.lib` artifacts.
   Nix or StageX in WSL are Linux builders; a MinGW DLL is not an MSVC artifact.
   If using a cross toolchain, prove that it implements this exact contract.
4. Reuse `packageBuiltTarget` from `tool/build_prebuilt.dart` and the existing
   manifest assembler. Include new build-policy inputs in source fingerprints
   and test fixtures, in coordinated shared-file commits.
5. Add `.github/workflows/reproducible-windows.yml` with a push trigger for
   `windows-reproducible-native-prebuilts`. Build with the shared pinned recipe,
   test the DLL, assemble a per-target release directory, then record provenance:

   ```powershell
   py -3 reproducible/ci_artifacts.py record build/windows-release --runner windows-2022
   ```

   Upload the release directory including `ci-evidence.json`. The user will
   arrange the GitHub publication/run from the host; do not substitute a local
   run for missing GitHub evidence.
6. Build twice in independent local build directories. Download the real GitHub
   run artifact and follow HOST_TO_CI.md using `py -3` instead of `python3`.
   Compare both link modes at the same full commit SHA. PowerShell uses backticks
   rather than Bash backslashes for multiline commands; one-line commands work.
7. Run the existing Dart C ABI smoke test on the matched DLL locally and in CI.
   Use `dumpbin /headers`, `dumpbin /dependents`, `lib /list`, LLVM inspection,
   and diffoscope as needed. Fix nondeterminism in the shared recipe, not by
   ignoring differing byte ranges in the comparator.

Authenticode signatures and timestamps must be treated separately from the
unsigned reproducible payload. Any postprocessing must be identical on both
builders and applied before producing the compared release artifact.

## Required return

Commit `reproducible/windows/RESULTS.md` with exact host/tool/SDK inventory,
pinned-input hashes, workflow/run URL and attempt, source commit, DLL and LIB
hashes, local clean-build and local-to-CI comparisons, dependency audit, and ABI
smoke output. Until a real GitHub output matches, report **host-to-CI unverified**.
