# Ubuntu workstation reproduces GitHub Actions — 2026-09-14

**Verified:** this Ubuntu 24.04.5 x86_64 workstation reproduced the static library,
shared library, manifest, and manifest checksum from both GitHub Ubuntu runners.
Both local comparisons exited 0 with `"status": "match"`.

## Reference build

- Repository: `cypherstack/flutter_libmwc`.
- Tested commit: `4b3862f6312125b0eb1d9213ad2b341c9b157a72`.
- Workflow: `.github/workflows/reproducible-native.yml`.
- [GitHub run 34900351768, attempt 1](https://github.com/cypherstack/flutter_libmwc/actions/runs/34900351768): **success**.
- Both `nix-linux` jobs and `compare-linux` succeeded. Each native build was
  followed by a forced clean rebuild; the comparison job then matched the
  independently produced release files across Ubuntu 22.04 and 24.04.
- This report is a subsequent documentation/evidence commit. The tested commit
  above, rather than the report commit, is the reference checkout to reproduce.

## Workstation result

The host used Determinate Nix 3.17.0 / Nix 2.33.3 with the committed flake and
sandbox. `./reproducible/nix/verify.sh` forced another clean native build and
reported `Clean rebuild matched`. This is native compilation from source with
cached pinned dependencies, not a rebuild of the entire Nix bootstrap chain.

The [host procedure](HOST_TO_CI.md) packaged the output into the fresh directory
`build/host-ci-34900351768-attempt-1/`. The pinned Ubuntu 22.04 container test and
the Dart mnemonic/error/free ABI smoke test passed. The comparison commands were:

```sh
for runner in 22.04 24.04; do
  python3 reproducible/ci_artifacts.py compare \
    "build/host-ci-34900351768-attempt-1/reproducible-linux-ubuntu-$runner-attempt-1" \
    build/host-ci-34900351768-attempt-1/release \
    --commit 4b3862f6312125b0eb1d9213ad2b341c9b157a72 \
    --repository cypherstack/flutter_libmwc \
    --run-id 34900351768 --run-attempt 1
done
```

Both commands ran from the clean tested checkout. They validated the actual
downloaded payloads, both link modes, source fingerprint, manifest pin, commit,
repository, run ID, and attempt. They produced the committed reports:

- [Local → GitHub Ubuntu 22.04](evidence/linux-34900351768/local-to-github-22.04.json).
- [Local → GitHub Ubuntu 24.04](evidence/linux-34900351768/local-to-github-24.04.json).
- [GitHub Ubuntu 22.04 → 24.04](evidence/linux-34900351768/github-to-github.json).
- [Run and local environment](evidence/linux-34900351768/run.json).
- CI provenance: [Ubuntu 22.04](evidence/linux-34900351768/github-ubuntu-22.04.json),
  [Ubuntu 24.04](evidence/linux-34900351768/github-ubuntu-24.04.json).

## Matching payload SHA-256

| File | Workstation and both GitHub runners |
| --- | --- |
| Dynamic `.so` | `32e5f329d5aa9b288660ba7f418ad6c4b3f9353f441447c3aba65d0095676b7b` |
| Static `.a` | `5b0fea362e1d7ef39dd6d61cf439a088d4108f7a179a271d8048bcd35134123a` |
| `manifest.json` | `4f366dfb616f4798aba515b260f61649f935af808139a2a37edc3a28515a7bfb` |
| `manifest.sha256` | `a2eb59dc473441d3f8d38b1c3d43df850ab63c6842aca5535d9910f2bc055864` |

Source fingerprint:
`341abcc1821405924296b5a6865f5d05ca05d301a3517260b8e957608a7beb72`.

Nix output on the workstation and GitHub:
`/nix/store/0zq1p7wziqahlj5zz0d8wbfa4qczfrq8-mwc-wallet-native-0.1.0`.

## Download integrity

The public GitHub API supplied the successful run metadata, artifact IDs, and
archive SHA-256 digests. There was no authenticated GitHub CLI session, so the
artifacts were retrieved through [nightly.link](https://github.com/oprypin/nightly.link),
which redirected to GitHub's artifact storage. Every archive's SHA-256 was
checked against the digest obtained directly from GitHub **before extraction**.
All three matched; the IDs, URLs, and digests are preserved in
[download-verification.json](evidence/linux-34900351768/download-verification.json).
No locally generated CI provenance was substituted for downloaded evidence.

The archives, extracted libraries, and full local/CI logs remain in the ignored
build directory. The compact evidence is committed. GitHub artifacts expire;
after expiry, start a new reference run and repeat the complete comparison.

## Scope and other hosts

This establishes workstation-to-GitHub reproducibility for the pinned Nix
`x86_64-unknown-linux-gnu` recipe. The coworker's Ubuntu 24.04 machine should use
[HOST_TO_CI.md](HOST_TO_CI.md) at the tested commit and obtain its own matching
report. It has not yet been tested here.

The old tag-release workflow still uses its previous build recipe; this report
does not claim to reproduce its older unpinned binaries. StageX remains a
locally repeatable **musl experiment**, without a GitHub reproduction result.
macOS and Windows agents should use their committed handoffs and apply the same
real-run comparison criterion to their respective targets.
