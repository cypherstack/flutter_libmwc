# Linux validation results — 2026-09-14

This is the initial local-validation report. The subsequent
[host-to-GitHub result](LINUX_HOST_TO_CI_RESULTS.md) establishes byte-identical
workstation output against both GitHub Ubuntu runners at commit `4b3862f`.

Implementation commit: `fb2c15384ac13cfc4454ec817776e605b10fceac`. Base branch: `origin/native-prebuilts`
(`9b6f1d5`). Branch: `reproducible-native-prebuilts`.

## Observed results

- Nix: `reproducible/nix/verify.sh` exited 0 after a normal build followed by
  `--rebuild` of the same derivation. Nix reported `Clean rebuild matched`.
  Both the static archive and shared library are identical across clean builds.
- The final derivation built at `/build` with frozen Cargo dependencies; its
  sandbox-root assertion passed. This host's daemon enables sandboxing but does
  not trust the client to override daemon settings. No daemon settings changed.
- The GNU ELF audit passed: maximum versioned glibc requirement **2.34**, no
  RPATH/RUNPATH, and only libc, libm, libgcc_s, and the system loader as shared
  dependencies. The advertised floor remains **2.35**.
- A SHA-256-pinned Ubuntu 22.04 container loaded the final library with network
  disabled and no `/nix` mount. Mnemonic generation, error handling, and 100
  allocation/free cycles passed. The existing Dart smoke test also passed.
- The Nix producer packaged both link modes. The normal manifest assembler
  validated the artifacts and produced a Linux-only manifest.
- StageX: two `--no-cache` builds (`stagex-musl-a` and `stagex-musl-b`) passed the
  C ABI smoke test. `cmp` exited 0 for both libraries. Rust 1.96.0 / Clang 22.1.5
  produced musl artifacts; the GNU release audit correctly rejects them.
- Resolver/producer tests: **40 passed**. Dart analysis: **No issues found**.
  `nix flake check --no-build`, actionlint, shellcheck, and `git diff --check`
  passed. The GitHub workflow was validated locally, not executed remotely.

## Artifact hashes

| Build / artifact | SHA-256 |
| --- | --- |
| Nix / dynamic | `32e5f329d5aa9b288660ba7f418ad6c4b3f9353f441447c3aba65d0095676b7b` |
| Nix / static | `5b0fea362e1d7ef39dd6d61cf439a088d4108f7a179a271d8048bcd35134123a` |
| StageX / libmwc_wallet.a | `4e98e282f9fedcf0ca9526865c207b7ccc8c9cf548336993deec4c91ee81e61b` |
| StageX / libmwc_wallet.so | `9c0f96bc5b147656fc4ce302709404e324e55e8a0b00b496650e0587d41deeef` |

Native source fingerprint:
`341abcc1821405924296b5a6865f5d05ca05d301a3517260b8e957608a7beb72`

Linux release manifest SHA-256:
`4f366dfb616f4798aba515b260f61649f935af808139a2a37edc3a28515a7bfb`

Nix output:
`/nix/store/0zq1p7wziqahlj5zz0d8wbfa4qczfrq8-mwc-wallet-native-0.1.0`

## Local artifacts and evidence

- `build/nix-prebuilts/`: the two GNU libraries and provenance fragment.
- `build/nix-release/`: manifest, manifest pin, and release libraries.
- `build/nix-result`: Nix output symlink / garbage-collection root.
- `build/stagex-musl-a/` and `build/stagex-musl-b/`: experimental musl outputs.
- `build/reproducibility-evidence/`: complete Nix rebuild log, both StageX build
  logs, test output, and Ubuntu/Dart smoke output.

These ignored build outputs and logs are local; the recipes, tests, and this
report are committed. At the time of this initial validation, no branch or
artifacts had been pushed/published. See [HOST_TO_CI.md](HOST_TO_CI.md) for the
subsequent transport handoff and the stricter host-to-GitHub acceptance criterion.

## Limits and next steps

Both rebuild comparisons used this Linux x86_64 host. Independent builders
should reproduce and compare these hashes before release. This does not claim
all Nix dependencies or the StageX bootstrap chain were rebuilt independently,
that static consumers were linked/tested, or that wallet transaction behavior
was tested.

The tag-triggered release workflow still uses its original build path. The new
Nix workflow is opt-in through its feature-branch push/manual triggers. Promoting it to the tag release should follow
independent reproduction and the remaining platform work.

macOS and Windows work can start independently now; the platform-specific input
and verification checklist is in [REPRODUCIBLE_BUILDS.md](../REPRODUCIBLE_BUILDS.md#next-host-work).
StageX needs a GNU/glibc cross toolchain before it can replace the current
Linux artifact. The musl experiment must retain its separate target identity.
