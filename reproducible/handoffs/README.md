# Host-to-GitHub reproducibility handoffs

The completion criterion for every host is: **rebuild the exact GitHub Actions
commit using the same pinned recipe, then match the SHA-256 of every shipped
native payload byte-for-byte.** Two matching builds on one host are necessary
supporting evidence, not completion. A successful load or matching ABI is not
binary reproducibility.

- [Ubuntu 24.04 and the shared CI comparison procedure](../HOST_TO_CI.md)
- [macOS agent](MACOS.md)
- [Windows agent](WINDOWS.md)

## Retrieve the plugin through the requested transport repository

The user requested `ssh://git@git.cypherstack.com:222/sneurlax/stack_wallet.git`.
The following **namespaced branch contains flutter_libmwc history**, not the
Stack Wallet application. Clone it separately; do not merge this unrelated
history into a Stack Wallet application branch.

```sh
git clone --single-branch --branch flutter-libmwc/reproducible-native-prebuilts \
  ssh://git@git.cypherstack.com:222/sneurlax/stack_wallet.git flutter_libmwc-repro
cd flutter_libmwc-repro
git remote rename origin transport
git remote add github git@github.com:cypherstack/flutter_libmwc.git
```

In PowerShell, use the same `git clone` command on one line (no Bash backslash).
The transport branch holds both handoffs, the Nix implementation, the StageX
experiment, and CI comparison tooling. Linux workstation-to-GitHub reproduction
has now passed on both Ubuntu runners; see the
[results and evidence](../LINUX_HOST_TO_CI_RESULTS.md). The reference build is
commit `4b3862f6312125b0eb1d9213ad2b341c9b157a72`, run `34900351768`, attempt `1`.

The common branch is also pushed to GitHub as `reproducible-native-prebuilts`;
its push trigger starts the Linux comparison workflow even before the workflow
is present on the default branch. A push to the transport server does not
execute GitHub Actions. Each host agent should add an equivalent push trigger
for its own GitHub branch and run the same recipe locally and in CI.

## Shared acceptance and evidence

1. Pin the source commit, Cargo graph, Rust compiler, native compiler/linker,
   SDK/sysroot, and code-generation tools. A `runs-on` label is not a toolchain pin.
2. Run clean builds locally in separate build directories. Do not reuse compiled
   Cargo target artifacts for the independent comparison.
3. Obtain a successful **real** GitHub run for the same commit and target. Record
   its repository, URL, run ID, attempt, runner image, and source SHA.
4. Download that run's artifact; verify the manifest pin and actual library
   hashes with `reproducible/ci_artifacts.py`. Compare extracted release payloads,
   not GitHub's ZIP envelope or variable run-provenance JSON.
5. Exercise the existing C ABI smoke test locally and in CI. Both link modes must
   match. A static-consumer link test is additional evidence, not a substitute
   for matching the shipped static archive bytes.
6. Commit a platform results report containing commands, exact pins, run URL,
   commit, all library hashes, comparison output, and unresolved limitations.

If a real run is unavailable or hashes differ, report **host-to-CI unverified**.
Never substitute fabricated CI evidence or two local build results for it.

Signing/notarization must be separated explicitly from the reproducible unsigned
payload. Do not compare stripped/normalized local bytes against a different
file than the payload GitHub actually supplies. Any deterministic normalization
belongs in the shared build recipe on both sides.

## Coordination

macOS and Windows may work in parallel. Each owns its platform directory,
producer, and workflow listed in its handoff. You are not alone in the repository;
do not revert another agent's work. Put necessary edits to shared producer,
fingerprint, manifest, or test files in separate commits, describe them, and
coordinate their integration. Re-run comparisons at the final integrated commit.
