# Verified default Windows builds

The default Windows native builder is reproducible without a reserved drive
letter. Two independent clean local builds matched the actual GitHub Actions
Windows artifact, and the ordinary Windows release job produced the same files.
The earlier fixed-drive result in [RESULTS.md](RESULTS.md) remains unchanged.

## Tested revision and CI

- Exact implementation commit: `5e14cd56264a776c9bbc55eaff05cc8786bc8b7c`.
- Native source/recipe fingerprint:
  `e447fd4849f91108e0bde71d9b40f0b600086b6212f9e8068ff6405f07cfde72`.
- [Reproducibility run 34913543299](https://github.com/cypherstack/flutter_libmwc/actions/runs/34913543299), attempt 1: success.
- [Ordinary release-route run 34913594040](https://github.com/cypherstack/flutter_libmwc/actions/runs/34913594040), attempt 1: success.
- CI: Windows Server 2022, runner image `20260907.297.1`.
- Local: Windows 11 build 26200, Intel Core i7-11800H.
- Flutter 3.47.3 / Dart 3.13.3; native tools remain pinned by `tools.lock.json`.

The ordinary release workflow was dispatched on the development branch. Its
actual Windows release job ran, while tag-only jobs and publishing were skipped.
No release tag or binary release was created.

## Full-file SHA-256 matches

| File | SHA-256 |
| --- | --- |
| DLL | `af02ec6d3885250735184de2df45bdf30b95eef9e48a9b4807d5aa3702efdb1f` |
| Static LIB | `fdbb264e9b7d874218013c7a6b00dc2e77d5a0dc78f5c4dcd168d25e73b65f76` |
| manifest.json | `8faf1dc955227f2cce271d13dde20745b06376383b1786b6de4b8ded506fe701` |
| manifest.sha256 | `3821f1d60bb53dd5d713e2de094ff80481c09151f7269b58767360fe56a03dc7` |

[Download verification](evidence/34913543299/download-verification.json) records
both official GitHub artifact IDs/digests and the hashes of the downloaded ZIPs.
The run ID, full commit, successful conclusion, and attempt were checked against
the GitHub API before extraction. The [ordinary job's download record](evidence/34913543299/ordinary-download-verification.json)
provides its independent run association and digest verification.

The [first local comparison](evidence/34913543299/local-a-to-ci.json),
[second local comparison](evidence/34913543299/local-b-to-ci.json), and
[ordinary-to-reproducibility comparison](evidence/34913543299/ordinary-to-repro.json)
all report matching complete payloads. The ordinary job ships manifest fragments;
its verified fragment was assembled locally using the same manifest tool before
comparison. Its provenance comes from the GitHub API record, not a fabricated
`ci-evidence.json`.

## Default behavior exercised

1. A Git-free package snapshot with the exact tested native fingerprint lived
   at `D:\mwc package final`. A separate Flutter app used it as a path dependency.
   Ordinary `flutter pub get` and `flutter build windows --release` triggered a
   fresh native build in automatically selected NTFS work/cache directories.
   Python and the pinned native tools were provisioned automatically. This was
   clean local build A; the generic prebuilt CLI then packaged its verified cache.
2. Clean local build B used the committed checkout and a fresh NTFS work path,
   `C:\src\mwc ntfs verified B`, through the Windows producer's `--clean` option.
   Deliberately invalid ambient `CL`, `RUSTFLAGS`, and `CC` values were excluded
   from the native environment. The raw independently rebuilt DLL and LIB were
   also compared byte for byte with CI, separately from packaged copies.
3. Another app resolved the actual SSH Git dependency at the exact commit.
   Its native fingerprint matched the checkout, and its ordinary release build
   reused the verified cache. Both apps ran and successfully called the native
   mnemonic function; their bundled DLLs have the hash above.
4. The static hook registered `package:flutter_libmwc/mwc.dart` with static
   linking and the verified LIB. Both local builds and both CI jobs linked and
   ran the real C static consumer. The downloaded CI LIB was independently
   linked and run on this host. Both local DLLs and the downloaded CI DLL passed
   the mnemonic/error/free ABI smoke test; CI also ran its DLL smoke test.

The [validation record](evidence/34913543299/validation.json),
[local A build audit](evidence/34913543299/local-a-build-evidence.json),
[local B build audit](evidence/34913543299/local-b-build-evidence.json), and
[CI build audit](evidence/34913543299/ci-build-evidence.json) retain the results.
A pub package dry run included the hook and all required recipe files. It found
existing package metadata/lint warnings; source publication was not attempted.

## Cache and failure handling

Concurrent builder and Flutter invocations shared the per-cache OS lock without
using a global drive mapping. Verified outputs are immutable for a fingerprint;
a forced clean build checks that its new DLL/LIB hashes match any existing valid
entry. Source changes select a new key. Invalid cached downloads are replaced
only after a new download passes its pinned digest check.

A real same-length cached-DLL corruption triggered a rebuild. That rebuild was
intentionally terminated after startup; a subsequent process acquired the lock
and ignored incomplete staging. Original verified bytes were restored for the
separate cache-hit/lock-recovery check. A Rust source edit in a Git-free package
selected a different key and started a new build; restoring the source reused
its prior verified output. These targeted tests cover invalidation/startup and
recovery, and deliberately do not claim a completed edited-source compilation.
See [cache recovery](evidence/34913543299/cache-recovery.json) and
[source invalidation](evidence/34913543299/source-invalidation.json).

Validation also passed 39 Dart tests (two platform skips), eight Windows recipe/
archive tests, and eight provenance tests. A Windows test holds a file open to
check that staging cleanup can fail harmlessly, then succeeds after releasing
the handle. Provisioning tests cover corrupt-cache repair and interrupted or
incorrect downloads without publication of partial bytes.

## Why the archive transformation is needed

Two initial physical-path builds had all 3,893 object payloads identical, but
77 absolute member paths made their static libraries differ. Replacing every
member name with an ordinal yielded matching libraries that crashed when linked
into the C consumer. Preserving the original symbol bindings while using those
ordinal names produced the same failure.

The accepted transformation removes directories while preserving basenames,
object bytes, ordering, duplicate members, and both original linker symbol
bindings. Relocated indexes must round-trip to the original index bytes. The
resulting libraries match and pass the static consumer. The precise MSVC
mechanism behind the ordinal-name failure remains unproven; preserving the
names whose removal caused it avoids relying on that behavior.

The ordered object-payload aggregate is
`6d5b1c19c777a611e8f4f8444696029f6a67d4f4833f74a727c63e4bae7594dc`.
This transformation runs during production before hashing or packaging. The
comparators do not mask or rewrite downloaded artifacts.

## Scope and prerequisites

Use Windows x64, normal Flutter Windows desktop prerequisites, Git, network
access for uncached inputs, and an NTFS work/cache volume. No administrator
rights, separate Python installation, or matching manually installed native
Rust/MSVC/SDK tools are required by this library. Flutter still needs its own
Visual Studio tools to build the app, and the DLL requires the MSVC runtime.

An explicit exFAT work-directory experiment failed during Cargo extraction:
setting a crate file's mtime returned Windows error 87. The default user cache
on this Windows host is NTFS. Source files on exFAT worked when the work/cache
volume was NTFS. Arbitrary filesystems are not claimed to be supported.

Windows can temporarily prevent deletion of build staging. Cleanup retries;
if access still fails, it reports the retained directory and preserves the
verified output. Such staging is never reused as a completed build. Ambient
Cargo configuration in a work-directory ancestor is rejected rather than
silently changing the recipe.

Another supported Windows machine should reproduce these native hashes with
this exact source, recipe, target, and release configuration. A toolchain or
recipe change establishes a new fingerprint/baseline. The Flutter application's
own executable is outside this native-library reproducibility claim.
