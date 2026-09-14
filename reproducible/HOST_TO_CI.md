# Reproduce GitHub Actions outputs on each host

## Acceptance criterion

Every host must reproduce the exact native payloads from a successful GitHub
Actions run at the **same commit**, with the **same pinned build recipe and
inputs**. Compare each target and both link modes. The comparison also validates
the manifest pin, source fingerprint, repository, run ID, and run attempt.

For Ubuntu 24.04, use the Nix derivation on both the workstation and GitHub.
The host OS does not select the Rust/C/C++ toolchain or glibc sysroot: those are
pinned in the flake. Native Ubuntu 24.04 system tools are not the release build
authority. The glibc 2.35 target baseline remains compatible with Ubuntu 22.04.

The workflow now builds independently on `ubuntu-22.04` and `ubuntu-24.04`,
forces clean rebuilds on each, and requires identical release payloads between
them. A separate local download-and-compare step establishes workstation-to-CI
reproduction. Identical local builds or a green CI build alone do not establish
that final claim.

## Verified Linux result

This **Ubuntu 24.04.5 LTS, x86_64** workstation reproduced both GitHub Ubuntu
22.04 and 24.04 outputs from successful
[run 34900351768, attempt 1](https://github.com/cypherstack/flutter_libmwc/actions/runs/34900351768),
at commit `4b3862f6312125b0eb1d9213ad2b341c9b157a72`. Both downloaded-artifact
comparisons exited 0 with `"status": "match"`. See the
[results and committed evidence](LINUX_HOST_TO_CI_RESULTS.md).

The earlier [local validation](RESULTS.md) also established runtime compatibility
with the pinned Ubuntu 22.04 container. The coworker's host should now run the
procedure below at the same tested commit and obtain its own matching report.

## Older release is a different recipe

The successful existing GitHub release run
[34892214334](https://github.com/cypherstack/flutter_libmwc/actions/runs/34892214334)
for `native-0.1.0-1` uses the old host-tool build path. Its
[published manifest](https://github.com/cypherstack/flutter_libmwc/releases/download/native-0.1.0-1/manifest.json)
records different hashes:

| Library | Existing GitHub release | Local pinned Nix recipe |
| --- | --- | --- |
| `.so` | `c5cbe571f16f1ab224e0267a3bd4eed2618856153adf977ea3f9b5d1aa142708` | `32e5f329d5aa9b288660ba7f418ad6c4b3f9353f441447c3aba65d0095676b7b` |
| `.a` | `49d6412fa82e1b7347c58d497dc1e3482c4847246b15402d8f9906f4d696e130` | `5b0fea362e1d7ef39dd6d61cf439a088d4108f7a179a271d8048bcd35134123a` |

The native Rust source is based on the same upstream revision, but the build
recipes and source fingerprints differ. These are not equivalent builds and
must not be claimed to match. The objective is to run the new pinned recipe
on GitHub and reproduce its output locally, not to promise reproduction of the
old unpinned binaries.

## Start the reference run

Publish the common branch to the intended GitHub repository under
`reproducible-native-prebuilts` (or `nix-reproducible-native-prebuilts`). The push
trigger runs `.github/workflows/reproducible-native.yml` without needing a first
manual dispatch from the default branch. It uploads:

- `reproducible-linux-ubuntu-22.04-attempt-N`
- `reproducible-linux-ubuntu-24.04-attempt-N`
- `reproducible-linux-comparison-attempt-N` (contains `match.json`)

Require the complete workflow, including `compare-linux`, to succeed. If rerunning,
rerun **all jobs** so both artifacts have the same attempt. Artifacts contain
`manifest.json`, `manifest.sha256`, both libraries, and `ci-evidence.json`.
The latter records varying run metadata and is deliberately not part of the
byte-identical release payload comparison.

## Reproduce on this Ubuntu host or the coworker's Ubuntu 24.04 host

Use a clean plugin checkout, Nix with flakes and sandboxing, Flutter satisfying
the package's SDK requirements, Python 3, and authenticated `gh` for downloading
Actions artifacts. The original Flutter pin is 3.47.2; Flutter/Dart only packages
and smoke-tests these Nix-built native outputs.

Set values from the actual successful run, not from a local fixture:

```sh
CI_REPOSITORY=cypherstack/flutter_libmwc # change if the run is in a fork
CI_RUN_ID=34900351768
CI_ATTEMPT=1
CI_COMMIT=4b3862f6312125b0eb1d9213ad2b341c9b157a72

gh run view "$CI_RUN_ID" -R "$CI_REPOSITORY" \
  --json headSha,conclusion,url,attempt
# Confirm success, headSha == CI_COMMIT, and attempt == CI_ATTEMPT.
git fetch github "$CI_COMMIT"
git switch --detach "$CI_COMMIT"

# Refuses a fallback build outside the canonical Nix sandbox.
./reproducible/nix/verify.sh
./reproducible/nix/smoke-ubuntu.sh
flutter pub get --no-example

# Use fresh destinations on every attempt; existing outputs are not overwritten.
LOCAL_ROOT="build/host-ci-$CI_RUN_ID-attempt-$CI_ATTEMPT"
dart --packages=.dart_tool/package_config.json tool/build_nix_prebuilt.dart \
  --output "$LOCAL_ROOT/prebuilts"
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart \
  --artifacts "$LOCAL_ROOT/prebuilts" --output "$LOCAL_ROOT/release"
dart --packages=.dart_tool/package_config.json tool/smoke_prebuilt.dart \
  "$LOCAL_ROOT/release/mwc_wallet-x86_64-unknown-linux-gnu-dynamic.so"

gh run download "$CI_RUN_ID" -R "$CI_REPOSITORY" \
  --name "reproducible-linux-ubuntu-24.04-attempt-$CI_ATTEMPT" \
  --dir "$LOCAL_ROOT/github-ubuntu-24.04"
python3 reproducible/ci_artifacts.py compare \
  "$LOCAL_ROOT/github-ubuntu-24.04" "$LOCAL_ROOT/release" \
  --commit "$CI_COMMIT" --repository "$CI_REPOSITORY" \
  --run-id "$CI_RUN_ID" --run-attempt "$CI_ATTEMPT" \
  > "$LOCAL_ROOT/local-to-github.json"
cat "$LOCAL_ROOT/local-to-github.json"
```

An exit code of zero plus `"status": "match"` verifies the actual files against
that downloaded run's evidence. The command rejects a dirty or wrong-commit
local checkout, incorrect source fingerprints, missing link modes, malformed
manifest pins, mismatched run identity, and differing/corrupted file bytes.
Obtain the artifact from the selected GitHub run; a locally fabricated
`ci-evidence.json` is not GitHub evidence.

The same procedure can compare the Ubuntu 22.04 artifact too. GitHub's comparison
job already establishes equality between the two runner outputs when green.
Keep the run URL, evidence JSON, and local comparison report in the host's results
commit. Do not compare the Actions ZIP's checksum: ZIP/container timestamps and
run provenance are not shipped native-library bytes.

An archive checksum can separately authenticate a download. Without `gh` login,
public artifacts can be downloaded using the URLs in the
[verified download record](evidence/linux-34900351768/download-verification.json).
These use nightly.link to redirect to GitHub storage. Before extraction, require
the ZIP SHA-256 to match the `digest` returned directly by
`https://api.github.com/repos/cypherstack/flutter_libmwc/actions/artifacts/ARTIFACT_ID`.
Also check the artifact's run ID and head SHA against the chosen successful run.
Then use the same payload comparator above. Do not treat the redirect service
or a ZIP checksum alone as proof of local native reproducibility. If artifacts
have expired, run the workflow again and use the new run's metadata and downloads.

## macOS and Windows

Use [MACOS.md](handoffs/MACOS.md) and [WINDOWS.md](handoffs/WINDOWS.md). Their agents
must implement one pinned recipe shared between local and GitHub builds and use
the same evidence protocol per target. The Python comparator is portable;
Windows can invoke it as `py -3`. Run IDs, artifact names, and targets must refer
to that platform's real workflow. StageX musl output cannot serve as evidence for
a GNU Linux, Apple, or MSVC artifact.

References: [workflow triggers](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
[Actions artifacts API](https://docs.github.com/en/rest/actions/artifacts).
