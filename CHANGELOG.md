## Unreleased

* **Breaking change:** the native library now comes from
  [dnix](https://github.com/cypherstack/dnix). By default the build hook
  downloads the library of the release `dnix.lock` names and verifies its
  SHA-256; with the `build` user define set to `source` it builds the same
  library with Nix, on Linux or an Apple Silicon Mac. The `native_build`,
  `prebuilt_manifest_url` and `prebuilt_manifest_sha256` user defines are
  no longer read: pinning this package's commit pins its libraries. There
  is no Linux arm64 library, as there was no prebuilt one before.
* Every change is built on four hosts, which must produce the bytes
  `dnix.lock` records; the default branch publishes the release it names.

## 0.0.1

* TODO: Describe initial release.
