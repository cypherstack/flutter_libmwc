# Verification commands

Run from the clean tested commit. Native libraries are generated in ignored
`build/` directories and are not committed as evidence.

```sh
export PATH=/nix/var/nix/profiles/default/bin:/Users/user/src/stack_wallet/flutter-3.47/bin:$PATH
./reproducible/macos/verify.sh
python3 -m unittest discover -s reproducible/macos -p 'test_*.py' -v
python3 -m unittest discover -s reproducible -p 'test_ci_artifacts.py' -v
# Invoke the pure Dart test runner directly to avoid triggering a second,
# unrelated native-assets hook build with the host toolchain.
dart --packages=.dart_tool/package_config.json \
  /Users/user/.pub-cache/hosted/pub.dev/test-1.31.1/bin/test.dart \
  --reporter expanded test/prebuilt_test.dart test/prebuilt_producer_test.dart
dart analyze tool/build_macos_prebuilt.dart hook/src/source_fingerprint.dart \
  test/prebuilt_test.dart test/prebuilt_producer_test.dart
actionlint .github/workflows/reproducible-macos.yml
git diff --check
```

The Dart tooling tests pass 39 tests and skip one Linux-only compiler test.
`test/native_assets_test.dart` requires Flutter's test runtime and is not part
of this pure Dart invocation. An attempted plain Dart invocation of that file
failed to load Flutter's `dart:ui`; it is not claimed as passing. Direct static
and dynamic ABI probes exercise the built Nix libraries separately.

Packaging commands, with fresh output directories:

```sh
dart --packages=.dart_tool/package_config.json tool/build_macos_prebuilt.dart \
  --output build/final-macos-prebuilts
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart \
  build/final-macos-prebuilts/mwc_wallet-aarch64-apple-darwin-dynamic.dylib
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart \
  --artifacts build/final-macos-prebuilts --output build/final-macos-release
```

`static-smoke-command.json` records the exact C compiler argv. Its source and
output paths are relative to the original task checkout. To rerun from the
committed evidence directory, update the source path and choose a fresh output
path outside tracked files. The source runs no wallet transactions.
