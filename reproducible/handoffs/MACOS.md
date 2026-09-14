# macOS agent handoff

## Objective and branch

Make this macOS host reproduce the exact unsigned native libraries emitted by
a real GitHub Actions run at the same commit. Start with the host's native CPU
architecture, then cover the other macOS architecture and iOS separately.
The Linux work is ready; do not wait for the Windows agent.

Read [the common handoff](README.md) and [HOST_TO_CI.md](../HOST_TO_CI.md).
After cloning the transport branch:

```sh
git switch -c macos-reproducible-native-prebuilts
```

Own `reproducible/macos/`, `tool/build_macos_prebuilt.dart`, and
`.github/workflows/reproducible-macos.yml`. Coordinate shared edits as described
in the common handoff. Preserve the existing Nix Linux and experimental StageX
paths. Transport updates can use `flutter-libmwc/macos-reproducible-native-prebuilts`.

## Inspect before selecting the recipe

Collect `sw_vers`, `uname -m`, `xcodebuild -version`, `xcode-select -p`,
`xcrun --show-sdk-version`, compiler/linker versions, and SDK path. Record the
exact SDK/build versions and content hashes of the inputs used. Inventory
available Nix and Xcode installations without replacing the user's selection.

Current release contract in `tool/build_prebuilt.dart`:

- Rust **1.90.0**, checked-in `Cargo.lock`; `.a` and `.dylib` for both
  `aarch64-apple-darwin` and `x86_64-apple-darwin`.
- macOS deployment target **11.0**.
- Install name **`@rpath/libmwc_wallet.dylib`**.
- LMDB C flags **`-DMDB_USE_POSIX_MUTEX=1 -DMDB_USE_ROBUST=0`**.
- Existing reference runners are `macos-15` and `macos-15-intel`; those labels
  alone do not freeze Xcode, the SDK, or Homebrew formulae.

Prefer a pinned Nix Darwin derivation if it can provide the required target/SDK
contract on both local and GitHub machines. Otherwise pin the complete Xcode
and native-tool inputs and use one shared build script. Do not call unpinned
`brew install` during a supposedly reproducible compile. Do not silently change
the deployment floor or SDK to match the host's defaults.

## Implement and verify

1. Vendor/hash-lock Cargo dependencies and separate fetching from offline builds.
   Pin protoc, CMake, Perl, assembler, Rust, Clang, linker, and Apple SDK inputs.
2. Build both link modes using a stable environment and source-path remapping.
   Inspect archive member timestamps/order, Mach-O UUIDs, load commands,
   install names, ad-hoc signatures, and embedded absolute paths. Keep the
   exact bytes emitted by the shared recipe as the comparison target.
3. Reuse `packageBuiltTarget` from `tool/build_prebuilt.dart` and the normal
   manifest assembler; include new build-policy inputs in the source fingerprint
   and its test fixtures. Do not label a modified toolchain as Rust 1.90.
4. Add a workflow that executes this same recipe, smoke-tests the dylib, assembles
   a per-target release directory, and runs:

   ```sh
   python3 reproducible/ci_artifacts.py record build/macos-release --runner macos-15
   ```

   Use the actual runner label and upload the whole release directory. Add a push
   trigger for `macos-reproducible-native-prebuilts` so the workflow can first run
   from a feature branch. GitHub credentials/publication may be supplied by the
   user from this host; no GitHub run existed for this work at handoff time.
5. Follow the download/comparison procedure in HOST_TO_CI.md, substituting the
   macOS workflow's artifact name and local output directory. Both `.a` and
   `.dylib` must match a real run at the exact same commit.
6. Run `tool/smoke_prebuilt.dart` against the matched dylib locally and in CI;
   investigate every mismatch with hashes, `otool`, `dwarfdump`, and archive
   inspection (or diffoscope). Do not mask differences only in the comparator.

## iOS follow-up

After macOS host-to-CI passes, cover `aarch64-apple-ios`,
`aarch64-apple-ios-sim`, and `x86_64-apple-ios`, preserving iOS **13.0** and the
correct device/simulator SDK selection. Compare unsigned archives first;
application signing and notarization are separate outputs. State which targets
were actually reproduced; do not extrapolate one architecture's result.

## Required return

Commit `reproducible/macos/RESULTS.md` with host inventory, exact pinned inputs,
workflow/run URL and attempt, commit, target-by-target hashes, local clean-build
comparison, local-to-CI comparison, and ABI smoke evidence. Include a precise
status for every target. "Builds locally" is not completion.
