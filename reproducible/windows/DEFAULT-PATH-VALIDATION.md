# Default Windows builder validation (in progress)

This tracks the revised recipe. The successful historical fixed-drive CI
comparison in `RESULTS.md` remains unchanged. This document does not yet claim
host-to-CI reproduction for the revised recipe.

## Archive feasibility

Two existing builds in `C:\src\mwc-w1` and `C:\src\mwc-w2` contained 3,893
identical ordered object payloads, but different full archive bytes because of
absolute member paths. Rebuilding with ordinal member names produced identical
libraries; a real MSVC-linked executable then crashed with access violation
3221225477. Linking the same consumer against the original library passed.

A second experiment preserved both original symbol indexes while assigning
ordinal names. It produced exactly the same bytes and the same runtime failure,
ruling out changed symbol bindings as the explanation for that experiment.

Preserving member basenames, removing only directories, and relocating the
original index offsets produced identical libraries that passed the static C
consumer for both inputs. Duplicate members and payload order are retained.
The precise MSVC mechanism behind the ordinal-name failure is not established;
the production transformation preserves the names whose removal caused it.

Both transformed archives have SHA-256:
`fdbb264e9b7d874218013c7a6b00dc2e77d5a0dc78f5c4dcd168d25e73b65f76`.

## Full native build without a drive mapping

An exploratory build completed under `C:\src\mwc space build 1` on Windows 11
build 26200 using pinned Python 3.13.7 and the checked-in native tools lock.
The build used its physical paths, quoted MSVC flags through `CL`, and the
basename-preserving archive transformation. It passed the existing PE/COFF
audit, the DLL mnemonic/error/free smoke test, and the real static C consumer.

- DLL: `af02ec6d3885250735184de2df45bdf30b95eef9e48a9b4807d5aa3702efdb1f`
- LIB: `fdbb264e9b7d874218013c7a6b00dc2e77d5a0dc78f5c4dcd168d25e73b65f76`
- Ordered object payload aggregate:
  `6d5b1c19c777a611e8f4f8444696029f6a67d4f4833f74a727c63e4bae7594dc`

This was an uncommitted feasibility build. It is not the final exact-commit
verification, and no new GitHub comparison has been recorded yet.

## Remaining gates

The automatic builder completed under `%LOCALAPPDATA%\flutter_libmwc`, including
verified Python provisioning and the built-in static consumer. Its DLL and LIB
match the exploratory hashes above. The repository example's ordinary
`flutter build windows --release` passed while that builder ran concurrently;
the bundled DLL has the same SHA-256.

A separate generated app at `C:\src\mwc default consumer` also passed an
ordinary release build against `C:\src\mwc package source`, a copy without
`.git`. Its verbose hook output confirmed reuse of the verified native cache.
This checks package consumption/cache reuse, not yet a fresh compilation from
that different source path.

Still required:

- Fresh compilation from a different source path, without `.git`.
- Cache reuse, corruption/interruption handling, source invalidation, and
  concurrent callers.
- Ordinary Windows release job dispatch without publishing.
- Two clean local builds and actual CI artifacts at one exact commit, with
  official download digest/provenance validation and complete file comparison.
- Final documentation/evidence and pushes to both applicable remotes.
