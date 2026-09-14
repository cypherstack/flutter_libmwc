# StageX musl experiment

This is an experimental `x86_64-unknown-linux-musl` build. Do not feed its output
to the GNU Linux release manifest: Flutter's current Linux hook uses glibc, and
this library needs musl, libc++, libc++abi, and libunwind.

```sh
./reproducible/stagex/build.sh build/stagex-a
./reproducible/stagex/build.sh build/stagex-b
cmp build/stagex-a/libmwc_wallet.a build/stagex-b/libmwc_wallet.a
cmp build/stagex-a/libmwc_wallet.so build/stagex-b/libmwc_wallet.so
cat build/stagex-a/SHA256SUMS
```

Requirements: x86_64 Linux, Nix with flakes, Docker with BuildKit/buildx, and
space for the vendor tree and native compilation. Output directories must be
fresh. The script cleans up its own temporary context, including read-only
vendor directories copied from Nix.

The Containerfile directly enforces all OCI digests (no mutable tags), taken
from the existing StageX work at revision
`9bdf430d09ce2ba53932df0182faef00d4feecd1`. Its pallet contains Rust 1.96.0 and
Clang 22.1.5 with a musl target. It therefore does **not** implement the release
Rust 1.90.0 contract. The source is otherwise the same Rust tree and lockfile.

Nix is used only to prepare the hash-verified Cargo vendor tree. It is not part
of the StageX compiler environment. The recipe replaces only the vendor path
placeholder in Cargo configuration; it does not rewrite the dependency graph.
All RUN instructions disable network access, Cargo uses `--frozen`, every
invocation uses `--no-cache`, and the compiler uses a fixed source path and
epoch. Before exporting, a C program loads the library and exercises the same
mnemonic/error/free operations as the Dart smoke test. SHA256SUMS and TOOLCHAIN
are exported with the two libraries. OCI image timestamps are outside this
comparison: compare the exported payloads, not incidental image metadata.

For a StageX-based replacement of the current prebuilts, the next independent
work item is a glibc cross toolchain: build/hash-pin the glibc 2.35 sysroot,
matching C++ runtime, and Rust GNU target standard library; preserve the chosen
Rust version; statically bundle non-system dependencies; then run
`reproducible/audit_linux.py` and the pinned Ubuntu baseline test. Alternatively,
introduce an explicit musl target in the Dart resolver and a musl-compatible
runtime. Neither is implemented here.

Pinning images is not the same as independently rebuilding and verifying the
StageX bootstrap chain or verifying its multi-party signatures. That is a
separate trust-validation step described in the
[StageX documentation](https://docs.stagex.tools/).
